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


struct bsk_account_ctx *bsk_account_find(bsk_engine *engine,
					 bsk_account_id id)
{
	struct le *le;

	for (le = engine->accounts.head; le; le = le->next) {
		struct bsk_account_ctx *a = le->data;
		if (a->id == id)
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
	default:                return "udp";
	}
}


static const char *mediaenc_name(bsk_media_encryption enc)
{
	switch (enc) {
	case BSK_MEDIA_ENC_SRTP_OPTIONAL:  return "srtp";
	case BSK_MEDIA_ENC_SRTP_MANDATORY: return "srtp-mand";
	case BSK_MEDIA_ENC_DTLS_SRTP:      return "dtls_srtp";
	default:                           return NULL;
	}
}


static const char *medianat_name(bsk_nat_traversal nat)
{
	switch (nat) {
	case BSK_NAT_STUN: return "stun";
	case BSK_NAT_ICE:  return "ice";
	default:           return NULL;
	}
}


static int join_codecs(char *buf, size_t len, const char *const *codecs,
		       size_t count)
{
	size_t i;
	int n = 0;

	buf[0] = '\0';
	for (i = 0; i < count; i++) {
		int r = re_snprintf(buf + n, len - (size_t)n, "%s%s",
				    i ? "," : "", codecs[i]);
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
		if ((unsigned char)*s < 0x20 || *s == 0x7f || strchr(forbidden, *s))
			return false;
	}

	return true;
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
	size_t i;

	{
		size_t n = aa->cfg->size ? aa->cfg->size : sizeof(local);

		if (n > sizeof(local))
			n = sizeof(local);
		memset(&local, 0, sizeof(local));
		memcpy(&local, aa->cfg, n);
		local.size = (uint32_t)sizeof(local);
	}

	if (!account_text_safe(c->aor, "\"<>; \t") ||
	    !account_text_safe(c->display_name, "\"\\<>"))
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
			  "%s%s%s%s%s",
			  str_isset(c->display_name) ? "\"" : "",
			  str_isset(c->display_name) ? c->display_name : "",
			  str_isset(c->display_name) ? "\" " : "",
			  c->aor, transport_name(c->transport),
			  menc ? ";mediaenc=" : "", menc ? menc : "",
			  mnat ? ";medianat=" : "", mnat ? mnat : "",
			  c->sip_outbound ? ";sipnat=outbound" : "");
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

	if (str_isset(c->auth_user))
		err |= account_set_auth_user(acc, c->auth_user);
	if (c->auth_password)
		err |= account_set_auth_pass(acc, c->auth_password);
	if (str_isset(c->outbound_proxy))
		err |= account_set_outbound(acc, c->outbound_proxy, 0);
	else if (str_isset(c->registrar))
		err |= account_set_outbound(acc, c->registrar, 0);

	switch (c->dtmf_mode) {
	case BSK_DTMF_RTP_EVENT:
		err |= account_set_dtmfmode(acc, DTMFMODE_RTP_EVENT);
		break;
	case BSK_DTMF_SIP_INFO:
		err |= account_set_dtmfmode(acc, DTMFMODE_SIP_INFO);
		break;
	default:
		err |= account_set_dtmfmode(acc, DTMFMODE_AUTO);
		break;
	}

	if (c->nat.mode != BSK_NAT_NONE) {
		if (c->nat.turn_count && c->nat.turn_servers) {
			const bsk_turn_server *t = &c->nat.turn_servers[0];
			err |= account_set_stun_uri(acc, t->uri);
			if (t->username)
				err |= account_set_stun_user(acc, t->username);
			if (t->password)
				err |= account_set_stun_pass(acc, t->password);
		}
		else if (str_isset(c->nat.stun_uri)) {
			err |= account_set_stun_uri(acc, c->nat.stun_uri);
		}
	}

	if (c->audio_codec_count && c->audio_codecs) {
		err |= join_codecs(codecs, sizeof(codecs), c->audio_codecs,
				   c->audio_codec_count);
		err |= account_set_audio_codecs(acc, codecs);
	}
	if (c->video_codec_count && c->video_codecs) {
		err |= join_codecs(codecs, sizeof(codecs), c->video_codecs,
				   c->video_codec_count);
		err |= account_set_video_codecs(acc, codecs);
	}

	if (c->contact_param_count) {
		bsk_status st = bsk_contact_params_encode(c->contact_params,
							  c->contact_param_count,
							  cparams,
							  sizeof(cparams), NULL);
		if (st != BSK_OK) {
			err = EINVAL;
		}
		else {
			err |= account_set_contact_params(acc, cparams);
		}
	}

	err |= account_set_mwi(acc, false);

	if (err) {
		ua_destroy(a->ua);
		a->ua = NULL;
		mem_deref(a);
		return err;
	}

	for (i = 0; i < RE_ARRAY_SIZE(cparams) && cparams[i]; i++)
		cparams[i] = 0;

	a->is_default = list_isempty(&e->accounts);
	a->answer_early_media = c->answer_early_media;
	list_append(&e->accounts, &a->le, a);
	aa->id = a->id;

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

	if (!account_text_safe(config->aor, "\"<>; \t"))
		return bsk_error_set(err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0,
				     NULL, "aor must not contain quotes, "
				     "angle brackets, ';' or whitespace");

	if (!account_text_safe(config->display_name, "\"\\<>"))
		return bsk_error_set(err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0,
				     NULL, "display name must not contain "
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


static int remove_op(bsk_engine *e, void *arg)
{
	struct id_arg *ia = arg;
	struct bsk_account_ctx *a = bsk_account_find(e, ia->id);

	if (!a)
		return ENOENT;

	if (a->ua) {
		ua_destroy(a->ua);
		a->ua = NULL;
	}
	mem_deref(a);

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

	ua_unregister(a->ua);
	a->state = BSK_REG_UNREGISTERING;
	a->registered = false;
	emit_registration(e, a, NULL, 0);
	a->state = BSK_REG_NONE;

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
		err |= account_set_auth_user(acc, ca->user);
	err |= account_set_auth_pass(acc, ca->pass);

	return err;
}


bsk_status bsk_account_set_credentials(bsk_engine *engine, bsk_account_id id,
				       const char *auth_user,
				       const char *auth_password,
				       bsk_error *err)
{
	struct cred_arg ca = { id, auth_user, auth_password };
	int ret;

	bsk_error_clear(err);

	if (!engine || id == BSK_ID_NONE)
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


bsk_status bsk_account_set_contact_params(bsk_engine *engine,
					  bsk_account_id id,
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
		return bsk_error_set(err, bsk_status_from_errno(ret), ret, 0,
				     NULL, "contact parameter update failed: %m",
				     ret);

	return BSK_OK;
}


bsk_status bsk_account_get_registration_state(const bsk_engine *engine,
					      bsk_account_id id,
					      bsk_registration_state *out)
{
	struct bsk_account_ctx *a;

	if (!engine || !out)
		return BSK_ERR_INVALID_ARGUMENT;

	a = bsk_account_find((bsk_engine *)engine, id);
	if (!a)
		return BSK_ERR_NOT_FOUND;

	*out = a->state;
	return BSK_OK;
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

	if (!a)
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
			uint64_t t = a->reg_started_ms ?
				bsk_now_ms() - a->reg_started_ms : 0;
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
			}
			else if (text && isdigit((unsigned char)text[0])) {
				const char *sp = strchr(text, ' ');
				scode = (uint16_t)atoi(text);
				if (sp)
					str_ncpy(reason, sp + 1, sizeof(reason));
			}
			bsk_error_set(&error,
				      (!scode && a->tls && text &&
				       (strstr(text, "Protocol") ||
					strstr(text, "certificate") ||
					strstr(text, "TLS"))) ? BSK_ERR_TLS :
				      status_from_sip(scode), 0, scode,
				      reason, "%s",
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

	default:
		break;
	}
}
