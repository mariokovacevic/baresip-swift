#include <string.h>
#include <ctype.h>
#include "bsk_internal.h"


static bool is_token_char(char c)
{
	return isalnum((unsigned char)c) || strchr("-.!%*_+`'~", c);
}


static bool is_param_char(char c)
{
	if (isalnum((unsigned char)c))
		return true;
	return strchr("-_.!~*'()%:&+$/[]", c) != NULL;
}


bsk_status bsk_contact_params_encode(const bsk_contact_param *params,
				     size_t count, char *buf, size_t buf_len,
				     size_t *out_len)
{
	size_t i, o = 0;

	if (out_len)
		*out_len = 0;

	if ((!params && count) || (!buf && buf_len))
		return BSK_ERR_INVALID_ARGUMENT;

	for (i = 0; i < count; i++) {
		const char *name = params[i].name;
		const char *value = params[i].value;
		size_t nlen, vlen = 0, k;

		if (!str_isset(name))
			return BSK_ERR_INVALID_ARGUMENT;
		nlen = strlen(name);
		for (k = 0; k < nlen; k++) {
			if (!is_token_char(name[k]))
				return BSK_ERR_INVALID_ARGUMENT;
		}
		if (value) {
			vlen = strlen(value);
			for (k = 0; k < vlen; k++) {
				if (!is_param_char(value[k]))
					return BSK_ERR_INVALID_ARGUMENT;
			}
		}

		if (i)
			o++;
		o += nlen;
		if (value)
			o += 1 + vlen;
	}

	if (out_len)
		*out_len = o;

	if (!buf)
		return BSK_OK;
	if (o + 1 > buf_len)
		return BSK_ERR_BUFFER_TOO_SMALL;

	o = 0;
	for (i = 0; i < count; i++) {
		size_t nlen = strlen(params[i].name);

		if (i)
			buf[o++] = ';';
		memcpy(buf + o, params[i].name, nlen);
		o += nlen;
		if (params[i].value) {
			size_t vlen = strlen(params[i].value);
			buf[o++] = '=';
			memcpy(buf + o, params[i].value, vlen);
			o += vlen;
		}
	}
	buf[o] = '\0';

	return BSK_OK;
}


struct bsk_account_ctx *bsk_account_find(bsk_engine *engine, bsk_account_id id)
{
	struct le *le;

	for (le = engine->accounts.head; le; le = le->next) {
		struct bsk_account_ctx *a = le->data;
		if (a->id == id)
			return a->removing ? NULL : a;
	}

	return NULL;
}


struct bsk_account_ctx *bsk_account_default(bsk_engine *engine)
{
	struct le *le;

	for (le = engine->accounts.head; le; le = le->next) {
		struct bsk_account_ctx *a = le->data;
		if (a->is_default && !a->removing)
			return a;
	}

	return NULL;
}


struct bsk_account_ctx *bsk_account_find_ua(bsk_engine *engine,
					    const struct ua *ua)
{
	struct le *le;

	for (le = engine->accounts.head; le; le = le->next) {
		struct bsk_account_ctx *a = le->data;
		if (a->ua == ua)
			return a;
	}

	return NULL;
}


static void account_ctx_destructor(void *arg)
{
	struct bsk_account_ctx *a = arg;

	tmr_cancel(&a->tmr_remove);
	list_unlink(&a->le);
	memset(a->pending_cparams, 0, sizeof(a->pending_cparams));
}


void bsk_accounts_flush(bsk_engine *engine)
{
	list_flush(&engine->accounts);
}


static const char *transport_name(bsk_transport tp)
{
	switch (tp) {
	case BSK_TRANSPORT_TCP: return "tcp";
	case BSK_TRANSPORT_TLS: return "tls";
	case BSK_TRANSPORT_WSS: return "wss";
	default: return "udp";
	}
}


static const char *mediaenc_name(bsk_media_encryption enc)
{
	switch (enc) {
	case BSK_MEDIA_ENC_SRTP_OPTIONAL: return "srtp";
	case BSK_MEDIA_ENC_SRTP_MANDATORY: return "srtp-mand";
	case BSK_MEDIA_ENC_DTLS_SRTP: return "dtls_srtp";
	default: return NULL;
	}
}


static const char *medianat_name(bsk_nat_traversal nat)
{
	switch (nat) {
	case BSK_NAT_STUN: return "stun";
	case BSK_NAT_ICE: return "ice";
	default: return NULL;
	}
}


static int join_codecs(char *buf, size_t len, const char *const *codecs,
		       size_t count)
{
	size_t i;
	int n = 0;

	buf[0] = '\0';
	for (i = 0; i < count; i++) {
		int r;

		if (!str_isset(codecs[i]))
			return EINVAL;
		r = re_snprintf(buf + n, len - (size_t)n, "%s%s", i ? "," : "",
				codecs[i]);
		if (r < 0)
			return EINVAL;
		n += r;
	}

	return 0;
}


static void emit_registration(bsk_engine *e, struct bsk_account_ctx *a,
			      const bsk_error *error, uint32_t expires)
{
	bsk_event ev;

	bsk_event_init(&ev, BSK_EVENT_REGISTRATION);
	ev.account = a->id;
	ev.u.registration.state = a->state;
	ev.u.registration.expires = expires;
	if (error)
		ev.u.registration.error = *error;

	bsk_emit(e, &ev);
}


static void warn_sdes(bsk_engine *e, const struct bsk_account_ctx *a,
		      const bsk_account_config *c)
{
	char msg[200];
	int n;

	if (a->tls || (c->media_encryption != BSK_MEDIA_ENC_SRTP_OPTIONAL &&
		       c->media_encryption != BSK_MEDIA_ENC_SRTP_MANDATORY))
		return;

	n = re_snprintf(msg, sizeof(msg),
			"bsk: account %llu: SDES-SRTP sends the media keys in "
			"the SDP over unencrypted SIP (%s); use TLS or WSS, "
			"or DTLS-SRTP",
			(unsigned long long)a->id,
			transport_name(c->transport));
	if (n > 0)
		bsk_log_emit(e, BSK_LOG_WARNING, BSK_LOG_DOMAIN_CORE, msg,
			     (size_t)n);
}


struct add_arg {
	const bsk_account_config *cfg;
	bsk_account_id id;
	int sys_err;
};


static bool account_text_safe(const char *s, const char *forbidden)
{
	if (!s)
		return true;

	for (; *s; s++) {
		if ((unsigned char)*s < 0x20 || *s == 0x7f ||
		    strchr(forbidden, *s))
			return false;
	}

	return true;
}


static int server_uri(char *buf, size_t len, const char *uri, bsk_transport tp)
{
	struct pl pl, param;
	struct uri parsed;

	pl_set_str(&pl, uri);
	if (uri_decode(&parsed, &pl) || pl_isset(&parsed.headers))
		return EINVAL;

	if (0 == msg_param_decode(&parsed.params, "transport", &param)) {
		if (0 != pl_strcasecmp(&param, transport_name(tp)))
			return EINVAL;
		return re_snprintf(buf, len, "%s", uri) < 0 ? EINVAL : 0;
	}

	return re_snprintf(buf, len, "%s;transport=%s", uri,
			   transport_name(tp)) < 0
		       ? EINVAL
		       : 0;
}


static int set_server(struct account *acc, const char *uri, bsk_transport tp)
{
	char buf[512];
	int err;

	err = server_uri(buf, sizeof(buf), uri, tp);
	if (err)
		return err;

	return account_set_outbound(acc, buf, 0);
}


static bool config_text_safe(const bsk_account_config *c)
{
	size_t i;

	if (!bsk_text_safe(c->registrar) || !bsk_text_safe(c->outbound_proxy) ||
	    !bsk_text_safe(c->auth_user) || !bsk_text_safe(c->auth_password) ||
	    !bsk_text_safe(c->nat.stun_uri))
		return false;

	for (i = 0; c->nat.turn_servers && i < c->nat.turn_count; i++) {
		const bsk_turn_server *t = &c->nat.turn_servers[i];

		if (!bsk_text_safe(t->uri) || !bsk_text_safe(t->username) ||
		    !bsk_text_safe(t->password))
			return false;
	}
	for (i = 0; c->audio_codecs && i < c->audio_codec_count; i++) {
		if (!bsk_name_safe(c->audio_codecs[i], "-./"))
			return false;
	}
	for (i = 0; c->video_codecs && i < c->video_codec_count; i++) {
		if (!bsk_name_safe(c->video_codecs[i], "-./"))
			return false;
	}
	for (i = 0; c->incoming_headers && i < c->incoming_header_count; i++) {
		if (!bsk_name_safe(c->incoming_headers[i], "-."))
			return false;
	}

	return true;
}


static int configure_nat(struct account *acc, const bsk_nat_config *nat)
{
	const bsk_turn_server *t;
	int err;

	if (nat->mode == BSK_NAT_NONE)
		return 0;

	if (!nat->turn_count || !nat->turn_servers)
		return str_isset(nat->stun_uri)
			       ? account_set_stun_uri(acc, nat->stun_uri)
			       : 0;

	t = &nat->turn_servers[0];
	err = account_set_stun_uri(acc, t->uri);
	if (!err && t->username)
		err = account_set_stun_user(acc, t->username);
	if (!err && t->password)
		err = account_set_stun_pass(acc, t->password);

	return err;
}


static int configure_codecs(const bsk_engine *e, struct account *acc,
			    const bsk_account_config *c, char *codecs,
			    size_t codecs_len)
{
	int err = 0;

	if (c->audio_codec_count && c->audio_codecs) {
		err = join_codecs(codecs, codecs_len, c->audio_codecs,
				  c->audio_codec_count);
		if (!err)
			err = account_set_audio_codecs(acc, codecs);
	} else if (str_isset(e->audio_codecs)) {
		err = account_set_audio_codecs(acc, e->audio_codecs);
	}
	if (err)
		return err;

	if (c->video_codec_count && c->video_codecs) {
		err = join_codecs(codecs, codecs_len, c->video_codecs,
				  c->video_codec_count);
		if (!err)
			err = account_set_video_codecs(acc, codecs);
	} else if (str_isset(e->video_codecs)) {
		err = account_set_video_codecs(acc, e->video_codecs);
	}

	return err;
}


static int configure_account(const bsk_engine *e, struct bsk_account_ctx *a,
			     struct account *acc, const bsk_account_config *c,
			     char *codecs, size_t codecs_len, char *cparams,
			     size_t cparams_len)
{
	enum dtmfmode dtmf = DTMFMODE_AUTO;
	int err = 0;
	size_t i;

	if (str_isset(c->auth_user))
		err = account_set_auth_user(acc, c->auth_user);
	if (!err && c->auth_password)
		err = account_set_auth_pass(acc, c->auth_password);
	if (!err && str_isset(c->outbound_proxy))
		err = set_server(acc, c->outbound_proxy, c->transport);
	else if (!err && str_isset(c->registrar))
		err = set_server(acc, c->registrar, c->transport);
	if (err)
		return err;

	if (c->dtmf_mode == BSK_DTMF_RTP_EVENT)
		dtmf = DTMFMODE_RTP_EVENT;
	else if (c->dtmf_mode == BSK_DTMF_SIP_INFO)
		dtmf = DTMFMODE_SIP_INFO;

	err = account_set_dtmfmode(acc, dtmf);
	err = bsk_first_error(err, configure_nat(acc, &c->nat));
	err = bsk_first_error(err,
			      configure_codecs(e, acc, c, codecs, codecs_len));
	if (err)
		return err;

	if (c->contact_param_count) {
		if (BSK_OK != bsk_contact_params_encode(
				      c->contact_params, c->contact_param_count,
				      cparams, cparams_len, NULL))
			return EINVAL;
		err = account_set_contact_params(acc, cparams);
	}

	err = bsk_first_error(err, account_set_mwi(acc, false));
	err = bsk_first_error(
		err, account_set_call_transfer(acc, !c->reject_transfers));

	for (i = 0; c->incoming_headers && i < c->incoming_header_count; i++) {
		if (!err && str_isset(c->incoming_headers[i]))
			err = ua_add_xhdr_filter(a->ua, c->incoming_headers[i]);
	}

	return err;
}


static int add_op(bsk_engine *e, void *arg)
{
	struct add_arg *aa = arg;
	bsk_account_config local;
	const bsk_account_config *c = &local;
	struct bsk_account_ctx *a;
	struct account *acc;
	char line[1024];
	char codecs[256];
	char cparams[BSK_CPARAMS_MAX];
	const char *menc;
	const char *mnat;
	uint32_t expires;
	int err;

	if (e->stop_requested)
		return EALREADY;

	{
		size_t n = aa->cfg->size ? aa->cfg->size : sizeof(local);

		if (n > sizeof(local))
			n = sizeof(local);
		memset(&local, 0, sizeof(local));
		memcpy(&local, aa->cfg, n);
		local.size = (uint32_t)sizeof(local);
	}

	if (!account_text_safe(c->aor, "\"<>;? \t") ||
	    !account_text_safe(c->display_name, "\"\\<>") ||
	    !config_text_safe(c))
		return EINVAL;

	menc = mediaenc_name(c->media_encryption);
	mnat = medianat_name(c->nat.mode);
	expires = c->register_expires ? c->register_expires : 3600;

	a = mem_zalloc(sizeof(*a), account_ctx_destructor);
	if (!a)
		return ENOMEM;

	a->id = e->next_account_id++;
	a->state = BSK_REG_NONE;
	a->expires = expires;
	a->tls = (c->transport == BSK_TRANSPORT_TLS ||
		  c->transport == BSK_TRANSPORT_WSS);

	err = re_snprintf(line, sizeof(line),
			  "%s%s%s<%s;transport=%s>;regint=0;answermode=manual"
			  ";ptime=%u%s%s%s%s%s%s%s%s",
			  str_isset(c->display_name) ? "\"" : "",
			  str_isset(c->display_name) ? c->display_name : "",
			  str_isset(c->display_name) ? "\" " : "", c->aor,
			  transport_name(c->transport), e->audio_ptime,
			  menc ? ";mediaenc=" : "", menc ? menc : "",
			  mnat ? ";medianat=" : "", mnat ? mnat : "",
			  c->sip_outbound ? ";sipnat=outbound" : "",
			  c->rtcp_mux ? ";rtcp_mux=yes" : "",
			  c->nat_pinhole ? ";natpinhole=yes" : "",
			  c->vfu_info ? ";vfu_info=yes" : "");
	if (err < 0) {
		mem_deref(a);
		return EINVAL;
	}

	err = ua_alloc(&a->ua, line);
	memset(line, 0, sizeof(line));
	if (err) {
		mem_deref(a);
		return err;
	}

	acc = ua_account(a->ua);

	cparams[0] = '\0';
	err = configure_account(e, a, acc, c, codecs, sizeof(codecs), cparams,
				sizeof(cparams));
	memset(cparams, 0, sizeof(cparams));

	if (err) {
		ua_destroy(a->ua);
		a->ua = NULL;
		mem_deref(a);
		return err;
	}

	a->is_default = !bsk_account_default(e);
	a->answer_early_media = c->answer_early_media;
	a->rtp_timeout_ms = c->nat.rtp_timeout_ms;
	a->reject_transfers = c->reject_transfers;
	list_append(&e->accounts, &a->le, a);
	aa->id = a->id;
	warn_sdes(e, a, c);

	return 0;
}


bsk_status bsk_account_add(bsk_engine *engine, const bsk_account_config *config,
			   bsk_account_id *out_id, bsk_error *err)
{
	struct add_arg aa = { config, BSK_ID_NONE, 0 };
	int ret;

	bsk_error_clear(err);

	if (!engine || !config || !out_id || !str_isset(config->aor))
		return bsk_error_set(err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0,
				     NULL, "aor is required");

	if (0 != strncmp(config->aor, "sip:", 4) &&
	    0 != strncmp(config->aor, "sips:", 5))
		return bsk_error_set(err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0,
				     NULL, "aor must be a sip: or sips: URI");

	if (!account_text_safe(config->aor, "\"<>;? \t"))
		return bsk_error_set(err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0,
				     NULL,
				     "aor must not contain quotes, angle "
				     "brackets, ';', '?' or whitespace");

	if (!account_text_safe(config->display_name, "\"\\<>"))
		return bsk_error_set(err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0,
				     NULL,
				     "display name must not contain "
				     "quotes, backslashes or angle brackets");

	ret = bsk_run(engine, add_op, &aa);
	if (ret)
		return bsk_error_set(err, bsk_status_from_errno(ret), ret, 0,
				     NULL, "account add failed: %m", ret);

	*out_id = aa.id;
	return BSK_OK;
}


struct id_arg {
	bsk_account_id id;
};


static void remove_account(bsk_engine *e, struct bsk_account_ctx *a)
{
	bool was_default = a->is_default;

	bsk_calls_hangup_account(e, a->id);
	if (a->ua) {
		ua_destroy(a->ua);
		a->ua = NULL;
	}
	mem_deref(a);

	if (was_default && e->accounts.head) {
		struct bsk_account_ctx *next = e->accounts.head->data;

		next->is_default = !next->removing;
	}
}


static void remove_timer(void *arg)
{
	struct bsk_account_ctx *a = arg;
	bsk_engine *e = bsk_global_engine();

	if (e)
		remove_account(e, a);
}


static int remove_op(bsk_engine *e, void *arg)
{
	struct id_arg *ia = arg;
	struct bsk_account_ctx *a = bsk_account_find(e, ia->id);

	if (!a)
		return ENOENT;

	if (e->emit_depth) {
		a->removing = true;
		tmr_start(&a->tmr_remove, 0, remove_timer, a);
		return 0;
	}

	remove_account(e, a);
	return 0;
}


static int set_default_op(bsk_engine *e, void *arg)
{
	struct id_arg *ia = arg;
	struct bsk_account_ctx *a = bsk_account_find(e, ia->id);
	struct le *le;

	if (!a)
		return ENOENT;

	for (le = e->accounts.head; le; le = le->next) {
		struct bsk_account_ctx *o = le->data;
		o->is_default = (o == a);
	}

	return ua_raise(a->ua);
}


static int register_op(bsk_engine *e, void *arg)
{
	struct id_arg *ia = arg;
	struct bsk_account_ctx *a = bsk_account_find(e, ia->id);
	int err;

	if (!a)
		return ENOENT;

	a->reg_started_ms = bsk_now_ms();
	a->unregistered = false;
	err = account_set_regint(ua_account(a->ua), a->expires);
	if (err)
		return err;

	return ua_register(a->ua);
}


static int unregister_op(bsk_engine *e, void *arg)
{
	struct id_arg *ia = arg;
	struct bsk_account_ctx *a = bsk_account_find(e, ia->id);

	if (!a)
		return ENOENT;

	a->unregistered = true;
	a->reg_inflight = false;
	a->registered = false;
	a->has_pending_cparams = false;
	a->state = BSK_REG_UNREGISTERING;
	emit_registration(e, a, NULL, 0);
	ua_unregister(a->ua);
	(void)account_set_regint(ua_account(a->ua), 0);
	a->state = BSK_REG_NONE;
	emit_registration(e, a, NULL, 0);

	return 0;
}


static bsk_status run_id(bsk_engine *engine, bsk_op_fn *fn, bsk_account_id id,
			 bsk_error *err, const char *what)
{
	struct id_arg ia = { id };
	int ret;

	bsk_error_clear(err);

	if (!engine || id == BSK_ID_NONE)
		return bsk_error_set(err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0,
				     NULL, NULL);

	ret = bsk_run(engine, fn, &ia);
	if (ret)
		return bsk_error_set(err, bsk_status_from_errno(ret), ret, 0,
				     NULL, "%s failed: %m", what, ret);

	return BSK_OK;
}


bsk_status bsk_account_remove(bsk_engine *engine, bsk_account_id id,
			      bsk_error *err)
{
	return run_id(engine, remove_op, id, err, "account remove");
}


bsk_status bsk_account_set_default(bsk_engine *engine, bsk_account_id id,
				   bsk_error *err)
{
	return run_id(engine, set_default_op, id, err, "set default account");
}


bsk_status bsk_account_register(bsk_engine *engine, bsk_account_id id,
				bsk_error *err)
{
	return run_id(engine, register_op, id, err, "register");
}


bsk_status bsk_account_unregister(bsk_engine *engine, bsk_account_id id,
				  bsk_error *err)
{
	return run_id(engine, unregister_op, id, err, "unregister");
}


struct cred_arg {
	bsk_account_id id;
	const char *user;
	const char *pass;
};


static int cred_op(bsk_engine *e, void *arg)
{
	struct cred_arg *ca = arg;
	struct bsk_account_ctx *a = bsk_account_find(e, ca->id);
	struct account *acc;
	int err = 0;

	if (!a)
		return ENOENT;

	acc = ua_account(a->ua);
	if (ca->user)
		err = account_set_auth_user(acc, ca->user);

	return bsk_first_error(err, account_set_auth_pass(acc, ca->pass));
}


bsk_status bsk_account_set_credentials(bsk_engine *engine, bsk_account_id id,
				       const char *auth_user,
				       const char *auth_password,
				       bsk_error *err)
{
	struct cred_arg ca = { id, auth_user, auth_password };
	int ret;

	bsk_error_clear(err);

	if (!engine || id == BSK_ID_NONE || !bsk_text_safe(auth_user) ||
	    !bsk_text_safe(auth_password))
		return bsk_error_set(err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0,
				     NULL, NULL);

	ret = bsk_run(engine, cred_op, &ca);
	if (ret)
		return bsk_error_set(err, bsk_status_from_errno(ret), ret, 0,
				     NULL, "set credentials failed: %m", ret);

	return BSK_OK;
}


struct cparams_arg {
	bsk_account_id id;
	const char *cparams;
	bool reregister_now;
};


static int apply_cparams(struct bsk_account_ctx *a, const char *cparams,
			 bool reregister_now)
{
	if (!a->registered || !reregister_now)
		return account_set_contact_params(ua_account(a->ua), cparams);

	if (a->reg_inflight) {
		str_ncpy(a->pending_cparams, cparams ? cparams : "",
			 sizeof(a->pending_cparams));
		a->has_pending_cparams = true;
		return 0;
	}

	a->reg_inflight = true;
	a->reg_started_ms = bsk_now_ms();
	return ua_set_contact_params(a->ua, cparams);
}


static int cparams_op(bsk_engine *e, void *arg)
{
	struct cparams_arg *ca = arg;
	struct bsk_account_ctx *a = bsk_account_find(e, ca->id);

	if (!a)
		return ENOENT;

	return apply_cparams(a, ca->cparams, ca->reregister_now);
}


bsk_status bsk_account_set_contact_params(bsk_engine *engine, bsk_account_id id,
					  const bsk_contact_param *params,
					  size_t count, bool reregister_now,
					  bsk_error *err)
{
	char cparams[BSK_CPARAMS_MAX];
	struct cparams_arg ca = { id, NULL, reregister_now };
	bsk_status st;
	int ret;

	bsk_error_clear(err);

	if (!engine || id == BSK_ID_NONE)
		return bsk_error_set(err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0,
				     NULL, NULL);

	st = bsk_contact_params_encode(params, count, cparams, sizeof(cparams),
				       NULL);
	if (st != BSK_OK)
		return bsk_error_set(err, st, EINVAL, 0, NULL,
				     "invalid contact parameters");

	ca.cparams = count ? cparams : NULL;

	ret = bsk_run(engine, cparams_op, &ca);
	memset(cparams, 0, sizeof(cparams));
	if (ret)
		return bsk_error_set(
			err, bsk_status_from_errno(ret), ret, 0, NULL,
			"contact parameter update failed: %m", ret);

	return BSK_OK;
}


struct state_arg {
	bsk_account_id id;
	bsk_registration_state state;
};


static int state_op(bsk_engine *e, void *arg)
{
	struct state_arg *sa = arg;
	struct bsk_account_ctx *a = bsk_account_find(e, sa->id);

	if (!a)
		return ENOENT;

	sa->state = a->state;
	return 0;
}


bsk_status bsk_account_get_registration_state(const bsk_engine *engine,
					      bsk_account_id id,
					      bsk_registration_state *out)
{
	struct state_arg sa = { id, BSK_REG_NONE };
	int ret;

	if (!engine || !out)
		return BSK_ERR_INVALID_ARGUMENT;

	ret = bsk_run((bsk_engine *)engine, state_op, &sa);
	if (ret)
		return ret == ENOENT ? BSK_ERR_NOT_FOUND
				     : bsk_status_from_errno(ret);

	*out = sa.state;
	return BSK_OK;
}


struct list_arg {
	bsk_account_id *ids;
	bsk_registration_state *states;
	size_t capacity;
	size_t count;
};


static int list_op(bsk_engine *e, void *arg)
{
	struct list_arg *la = arg;
	struct le *le;

	la->count = 0;
	for (le = e->accounts.head; le; le = le->next) {
		const struct bsk_account_ctx *a = le->data;

		if (a->removing)
			continue;
		if (la->count < la->capacity) {
			if (la->ids)
				la->ids[la->count] = a->id;
			if (la->states)
				la->states[la->count] = a->state;
		}
		la->count++;
	}

	return 0;
}


size_t bsk_account_list(const bsk_engine *engine, bsk_account_id *ids,
			bsk_registration_state *states, size_t capacity)
{
	struct list_arg la = { ids, states, capacity, 0 };

	if (!engine)
		return 0;

	(void)bsk_run((bsk_engine *)engine, list_op, &la);
	return la.count;
}


static bsk_status status_from_sip(uint16_t scode)
{
	if (scode == 401 || scode == 403 || scode == 407)
		return BSK_ERR_AUTH;
	if (scode == 408 || scode == 503 || scode == 504)
		return BSK_ERR_NETWORK;
	if (scode)
		return BSK_ERR_SIP;
	return BSK_ERR_NETWORK;
}


void bsk_account_handle_event(bsk_engine *e, enum bevent_ev ev,
			      struct bevent *event)
{
	struct ua *ua = bevent_get_ua(event);
	const struct sip_msg *msg = bevent_get_msg(event);
	struct bsk_account_ctx *a = bsk_account_find_ua(e, ua);
	bsk_error error;
	char reason[64] = "";

	if (!a || a->unregistered)
		return;

	switch (ev) {
	case BEVENT_REGISTERING:
		a->reg_inflight = true;
		if (!a->reg_started_ms)
			a->reg_started_ms = bsk_now_ms();
		a->state = BSK_REG_REGISTERING;
		emit_registration(e, a, NULL, 0);
		break;

	case BEVENT_REGISTER_OK:
	case BEVENT_FALLBACK_OK:
		a->reg_inflight = false;
		a->registered = true;
		a->state = BSK_REG_REGISTERED;
		{
			uint32_t expires = account_regint(ua_account(ua));
			uint64_t t = a->reg_started_ms
					     ? bsk_now_ms() - a->reg_started_ms
					     : 0;
			char msgbuf[96];
			int n = re_snprintf(msgbuf, sizeof(msgbuf),
					    "bsk: registration ok in %llu ms",
					    (unsigned long long)t);
			if (n > 0)
				bsk_log_emit(e, BSK_LOG_INFO,
					     BSK_LOG_DOMAIN_CORE, msgbuf,
					     (size_t)n);
			a->reg_started_ms = 0;
			emit_registration(e, a, NULL, expires);
		}
		if (a->has_pending_cparams) {
			a->has_pending_cparams = false;
			(void)apply_cparams(a, a->pending_cparams, true);
			memset(a->pending_cparams, 0,
			       sizeof(a->pending_cparams));
		}
		break;

	case BEVENT_REGISTER_FAIL:
	case BEVENT_FALLBACK_FAIL:
		a->reg_inflight = false;
		a->registered = false;
		a->state = BSK_REG_FAILED;
		a->reg_started_ms = 0;
		{
			const char *text = bevent_get_text(event);
			uint16_t scode = msg ? msg->scode : 0;

			if (msg) {
				(void)pl_strcpy(&msg->reason, reason,
						sizeof(reason));
			} else if (text && isdigit((unsigned char)text[0])) {
				const char *sp = strchr(text, ' ');
				scode = (uint16_t)atoi(text);
				if (sp)
					str_ncpy(reason, sp + 1,
						 sizeof(reason));
			}
			bsk_error_set(&error,
				      (!scode && a->tls && text &&
				       (strstr(text, "Protocol") ||
					strstr(text, "certificate") ||
					strstr(text, "TLS")))
					      ? BSK_ERR_TLS
					      : status_from_sip(scode),
				      0, scode, reason, "%s",
				      text ? text : "registration failed");
		}
		emit_registration(e, a, &error, 0);
		if (a->has_pending_cparams) {
			a->has_pending_cparams = false;
			(void)account_set_contact_params(ua_account(ua),
							 a->pending_cparams);
			memset(a->pending_cparams, 0,
			       sizeof(a->pending_cparams));
		}
		break;

	case BEVENT_UNREGISTERING:
		a->reg_inflight = false;
		a->registered = false;
		if (a->state != BSK_REG_UNREGISTERING) {
			a->state = BSK_REG_UNREGISTERING;
			emit_registration(e, a, NULL, 0);
			a->state = BSK_REG_NONE;
		}
		break;

	default: break;
	}
}
