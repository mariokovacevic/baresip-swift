#include <string.h>
#include <strings.h>
#include "bsk_internal.h"

enum { BSK_LOG_LINE_MAX = 16384 };

static const struct {
	const char *key;
	size_t keep;
	const char *stop;
} redactions[] = {
	{ "response=\"", 0, "\"" },      { "pn-tok=", 8, ";>, \r\n" },
	{ "pn-prid=", 8, ";>, \r\n" },   { "pn-voip-tok=", 8, ";>, \r\n" },
	{ "auth_pass=", 0, ";>, \r\n" }, { "stunpass=", 0, ";>, \r\n" },
	{ "password=", 0, ";>&, \r\n" }, { "inline:", 0, "|; \r\n" },
	{ "a=ice-pwd:", 0, " \r\n" },    { "Signal=", 0, " \r\n" },
	{ "DTMF digit: '", 0, "'" },     { "DTMF digit end: '", 0, "'" },
	{ "DTMF event: '", 0, "'" },     { "INFO DTMF: '", 0, "'" },
};


static size_t redact_span(const char *p, size_t len, const char *stop)
{
	size_t i;

	for (i = 0; i < len; i++) {
		if (strchr(stop, p[i]))
			break;
	}

	return i;
}


static size_t uri_password(const char *p, size_t len, size_t *plen)
{
	size_t scheme, i, colon = 0;

	if (len >= 5 && 0 == strncasecmp(p, "sips:", 5))
		scheme = 5;
	else if (len >= 4 && 0 == strncasecmp(p, "sip:", 4))
		scheme = 4;
	else
		return 0;

	for (i = scheme; i < len; i++) {
		if (p[i] == '@')
			break;
		if (strchr(" <>;,\"\r\n", p[i]))
			return 0;
		if (p[i] == ':' && !colon)
			colon = i;
	}
	if (i == len || !colon)
		return 0;

	*plen = i - colon - 1;
	return colon + 1;
}


static size_t put(char *out, size_t o, size_t out_len, const char *text,
		  size_t len)
{
	size_t k;

	for (k = 0; k < len && o + 1 < out_len; k++)
		out[o++] = text[k];

	return o;
}


size_t bsk_redact(const char *in, size_t len, char *out, size_t out_len)
{
	static const char mask[] = "[redacted]";
	size_t i = 0, o = 0;

	if (!in || !out || !out_len)
		return 0;

	while (i < len && o + 1 < out_len) {
		bool matched = false;
		size_t r, secret = 0, prefix;

		prefix = uri_password(&in[i], len - i, &secret);
		if (prefix) {
			o = put(out, o, out_len, &in[i], prefix);
			o = put(out, o, out_len, mask, sizeof(mask) - 1);
			i += prefix + secret;
			continue;
		}

		for (r = 0; r < RE_ARRAY_SIZE(redactions); r++) {
			const char *key = redactions[r].key;
			size_t klen = strlen(key);
			size_t vlen, keep, k;

			if (len - i < klen ||
			    0 != strncasecmp(&in[i], key, klen))
				continue;

			for (k = 0; k < klen && o + 1 < out_len; k++)
				out[o++] = in[i + k];
			i += klen;

			vlen = redact_span(&in[i], len - i, redactions[r].stop);
			keep = min(vlen, redactions[r].keep);
			for (k = 0; k < keep && o + 1 < out_len; k++)
				out[o++] = in[i + k];
			if (vlen > keep)
				o = put(out, o, out_len, mask,
					sizeof(mask) - 1);
			i += vlen;
			matched = true;
			break;
		}

		if (!matched)
			out[o++] = in[i++];
	}

	out[o] = '\0';
	return o;
}


static _Thread_local unsigned log_depth;


void bsk_log_emit(bsk_engine *engine, bsk_log_level level,
		  bsk_log_domain domain, const char *line, size_t len)
{
	static _Thread_local char buf[BSK_LOG_LINE_MAX];
	bsk_log_handler handler;
	void *user;
	bool tracked;
	size_t n;

	if (!engine || level < engine->log_level)
		return;

	mtx_lock(&engine->log_mtx);
	handler = engine->logh;
	user = engine->log_user;
	if (handler)
		engine->log_inflight++;
	mtx_unlock(&engine->log_mtx);

	if (!handler)
		return;

	while (len && (line[len - 1] == '\n' || line[len - 1] == '\r'))
		len--;

	n = bsk_redact(line, len, buf, sizeof(buf));
	tracked = bsk_on_engine_thread(engine);

	if (tracked)
		engine->emit_depth++;
	log_depth++;
	handler(level, domain, buf, n, user);
	log_depth--;
	if (tracked)
		engine->emit_depth--;

	mtx_lock(&engine->log_mtx);
	if (--engine->log_inflight == 0)
		cnd_broadcast(&engine->log_cnd);
	mtx_unlock(&engine->log_mtx);
}


void bsk_log_set_handler(bsk_engine *engine, bsk_log_handler handler,
			 void *user)
{
	bool wait = !bsk_on_engine_thread(engine);

	mtx_lock(&engine->log_mtx);
	engine->logh = handler;
	engine->log_user = user;
	while (wait && engine->log_inflight > log_depth)
		cnd_wait(&engine->log_cnd, &engine->log_mtx);
	mtx_unlock(&engine->log_mtx);
}


bool bsk_log_has_handler(bsk_engine *engine)
{
	bool has;

	mtx_lock(&engine->log_mtx);
	has = engine->logh != NULL;
	mtx_unlock(&engine->log_mtx);

	return has;
}


static bsk_log_level map_baresip_level(uint32_t level)
{
	switch (level) {
	case LEVEL_DEBUG: return BSK_LOG_DEBUG;
	case LEVEL_INFO: return BSK_LOG_INFO;
	case LEVEL_WARN: return BSK_LOG_WARNING;
	default: return BSK_LOG_ERROR;
	}
}


static void baresip_log_handler(uint32_t level, const char *msg)
{
	bsk_engine *engine = bsk_global_engine();

	if (!engine || !msg)
		return;

	bsk_log_emit(engine, map_baresip_level(level), BSK_LOG_DOMAIN_CORE, msg,
		     strlen(msg));
}


static void libre_dbg_handler(int level, const char *p, size_t len, void *arg)
{
	bsk_engine *engine = arg;
	bsk_log_level lvl;

	if (!engine || !p)
		return;

	if (level <= DBG_ERR)
		lvl = BSK_LOG_ERROR;
	else if (level <= DBG_WARNING)
		lvl = BSK_LOG_WARNING;
	else if (level <= DBG_INFO)
		lvl = BSK_LOG_INFO;
	else
		lvl = BSK_LOG_DEBUG;

	bsk_log_emit(engine, lvl, BSK_LOG_DOMAIN_CORE, p, len);
}


static size_t message_body(const uint8_t *pkt, size_t len)
{
	size_t i;

	for (i = 0; i + 3 < len; i++) {
		if (0 == memcmp(pkt + i, "\r\n\r\n", 4))
			return i + 4;
	}

	return len;
}


void bsk_sip_trace_handler(bool tx, enum sip_transp tp, const struct sa *src,
			   const struct sa *dst, const uint8_t *pkt, size_t len,
			   void *arg)
{
	static const char hidden[] = "[body redacted]";
	bsk_engine *engine = bsk_global_engine();
	char head[160];
	static _Thread_local char buf[16384];
	int n;
	(void)arg;

	if (!engine || !bsk_log_has_handler(engine))
		return;

	n = re_snprintf(head, sizeof(head), "%s %s %J -> %J (%zu bytes)\n",
			tx ? "TX" : "RX", sip_transp_name(tp), src, dst, len);
	if (n < 0)
		return;

	len = min(len, sizeof(buf) - (size_t)n - sizeof(hidden));
	memcpy(buf, head, (size_t)n);
	memcpy(buf + n, pkt, len);

	if (len > 8 && 0 == memcmp(pkt, "MESSAGE ", 8)) {
		size_t body = message_body(pkt, len);

		if (body < len) {
			memcpy(buf + n + body, hidden, sizeof(hidden) - 1);
			len = body + sizeof(hidden) - 1;
		}
	}

	bsk_log_emit(engine, BSK_LOG_INFO, BSK_LOG_DOMAIN_SIP, buf,
		     (size_t)n + len);
}


void bsk_log_init(bsk_engine *engine)
{
	if (!engine)
		return;

	log_enable_stdout(false);
	log_level_set(engine->log_level <= BSK_LOG_DEBUG     ? LEVEL_DEBUG
		      : engine->log_level == BSK_LOG_INFO    ? LEVEL_INFO
		      : engine->log_level == BSK_LOG_WARNING ? LEVEL_WARN
							     : LEVEL_ERROR);

	engine->baresip_log.h = baresip_log_handler;
	log_register_handler(&engine->baresip_log);

	dbg_init(engine->log_level <= BSK_LOG_DEBUG ? DBG_DEBUG : DBG_INFO,
		 DBG_NONE);
	dbg_handler_set(libre_dbg_handler, engine);
}


void bsk_log_close(bsk_engine *engine)
{
	if (!engine)
		return;

	log_unregister_handler(&engine->baresip_log);
	dbg_handler_set(NULL, NULL);
}
