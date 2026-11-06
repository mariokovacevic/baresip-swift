#include <string.h>
#include <strings.h>
#include "bsk_internal.h"

static const struct {
	const char *key;
	size_t keep;
	const char *stop;
} redactions[] = {
	{ "response=\"", 0, "\"" },
	{ "pn-tok=", 8, ";>, \r\n" },
	{ "auth_pass=", 0, ";>, \r\n" },
	{ "stunpass=", 0, ";>, \r\n" },
	{ "password=", 0, ";>&, \r\n" },
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


size_t bsk_redact(const char *in, size_t len, char *out, size_t out_len)
{
	size_t i = 0, o = 0;

	if (!in || !out || !out_len)
		return 0;

	while (i < len && o + 1 < out_len) {
		bool matched = false;
		size_t r;

		for (r = 0; r < RE_ARRAY_SIZE(redactions); r++) {
			const char *key = redactions[r].key;
			size_t klen = strlen(key);
			size_t vlen, keep, k;

			if (len - i < klen || 0 != strncasecmp(&in[i], key, klen))
				continue;

			for (k = 0; k < klen && o + 1 < out_len; k++)
				out[o++] = in[i + k];
			i += klen;

			vlen = redact_span(&in[i], len - i, redactions[r].stop);
			keep = min(vlen, redactions[r].keep);
			for (k = 0; k < keep && o + 1 < out_len; k++)
				out[o++] = in[i + k];
			if (vlen > keep) {
				const char *mask = "[redacted]";
				size_t mlen = strlen(mask);
				for (k = 0; k < mlen && o + 1 < out_len; k++)
					out[o++] = mask[k];
			}
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


void bsk_log_emit(bsk_engine *engine, bsk_log_level level,
		  bsk_log_domain domain, const char *line, size_t len)
{
	char buf[2048];
	size_t n;

	if (!engine || !engine->logh || level < engine->log_level)
		return;

	while (len && (line[len - 1] == '\n' || line[len - 1] == '\r'))
		len--;

	n = bsk_redact(line, len, buf, sizeof(buf));
	engine->logh(level, domain, buf, n, engine->log_user);
}


static bsk_log_level map_baresip_level(uint32_t level)
{
	switch (level) {
	case LEVEL_DEBUG: return BSK_LOG_DEBUG;
	case LEVEL_INFO:  return BSK_LOG_INFO;
	case LEVEL_WARN:  return BSK_LOG_WARNING;
	default:          return BSK_LOG_ERROR;
	}
}


static void baresip_log_handler(uint32_t level, const char *msg)
{
	bsk_engine *engine = bsk_global_engine();

	if (!engine || !msg)
		return;

	bsk_log_emit(engine, map_baresip_level(level), BSK_LOG_DOMAIN_CORE,
		     msg, strlen(msg));
}


static void libre_dbg_handler(int level, const char *p, size_t len,
			      void *arg)
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


void bsk_sip_trace_handler(bool tx, enum sip_transp tp,
			   const struct sa *src, const struct sa *dst,
			   const uint8_t *pkt, size_t len, void *arg)
{
	bsk_engine *engine = bsk_global_engine();
	char head[160];
	char buf[4096];
	int n;
	(void)arg;

	if (!engine || !engine->logh)
		return;

	n = re_snprintf(head, sizeof(head), "%s %s %J -> %J (%zu bytes)\n",
			tx ? "TX" : "RX", sip_transp_name(tp), src, dst, len);
	if (n < 0)
		return;

	len = min(len, sizeof(buf) - (size_t)n - 1);
	memcpy(buf, head, (size_t)n);
	memcpy(buf + n, pkt, len);

	bsk_log_emit(engine, BSK_LOG_INFO, BSK_LOG_DOMAIN_SIP, buf,
		     (size_t)n + len);
}


void bsk_log_init(bsk_engine *engine)
{
	if (!engine)
		return;

	log_enable_stdout(false);
	log_level_set(engine->log_level <= BSK_LOG_DEBUG ? LEVEL_DEBUG :
		      engine->log_level == BSK_LOG_INFO ? LEVEL_INFO :
		      engine->log_level == BSK_LOG_WARNING ? LEVEL_WARN :
		      LEVEL_ERROR);

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
