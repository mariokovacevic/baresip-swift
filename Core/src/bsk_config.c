#include <string.h>
#include <stdarg.h>
#include <stdio.h>
#include "bsk_internal.h"
#include "bsk_engine_internal.h"


static const char *default_modules[] = {
	"g711",      "opus",      "l16",  "auconv",    "auresamp",    "ice",
	"turn",      "stun",      "srtp", "dtls_srtp", "rtcpsummary",
#if defined(__APPLE__)
	"audiounit", "fakevideo",
#endif
};
static int join_list(char *buf, size_t len, const char *const *v, size_t n)
{
	size_t used = 0;
	size_t i;

	buf[0] = '\0';
	for (i = 0; v && i < n; i++) {
		size_t need = str_len(v[i]) + (used ? 1 : 0);

		if (!str_isset(v[i]) || !bsk_name_safe(v[i], "-./"))
			return EINVAL;
		if (used + need + 1 > len)
			return EOVERFLOW;
		(void)re_snprintf(buf + used, len - used, "%s%s",
				  used ? "," : "", v[i]);
		used += need;
	}

	return 0;
}


static int dup_str(char **dst, const char *src)
{
	*dst = NULL;
	if (!str_isset(src))
		return 0;
	if (!bsk_text_safe(src))
		return EINVAL;
	return str_dup(dst, src);
}


static int copy_name(char *dst, size_t len, const char *src, const char *def)
{
	const char *value = str_isset(src) ? src : def;

	if (!bsk_name_safe(value, "-.") || str_len(value) >= len)
		return EINVAL;

	str_ncpy(dst, value, len);
	return 0;
}


static int copy_device(char *dst, size_t len, const char *src)
{
	const char *value = src ? src : "";

	if (!bsk_text_safe(value) || str_len(value) >= len)
		return EINVAL;

	str_ncpy(dst, value, len);
	return 0;
}


static int copy_bytes(char **dst, size_t *dst_len, const char *src, size_t len)
{
	if (!src || !len)
		return 0;

	*dst = mem_zalloc(len + 1, NULL);
	if (!*dst)
		return ENOMEM;

	memcpy(*dst, src, len);
	*dst_len = len;
	return 0;
}


static bool pin_valid(const char *pin)
{
	size_t i;

	if (str_len(pin) != 44 || pin[43] != '=')
		return false;

	for (i = 0; i < 43; i++) {
		if (!bsk_name_safe((char[]){ pin[i], '\0' }, "+/") ||
		    pin[i] == '_')
			return false;
	}

	return true;
}


static int copy_tls(bsk_engine *e, const bsk_tls_config *tls)
{
	size_t i;
	int err;

	err = dup_str(&e->cipher_list, tls->cipher_list);
	err = bsk_first_error(err, copy_bytes(&e->ca_pem, &e->ca_pem_len,
					      tls->ca_pem, tls->ca_pem_len));
	err = bsk_first_error(err, copy_bytes(&e->client_cert_pem,
					      &e->client_cert_pem_len,
					      tls->client_cert_pem,
					      tls->client_cert_pem_len));
	if (err)
		return err;

	if (tls->pinned_count && !tls->pinned_spki_sha256_base64)
		return EINVAL;
	if (tls->pinned_count > RE_ARRAY_SIZE(e->pins))
		return EINVAL;
	if (tls->pinned_count && tls->insecure_skip_verify)
		return EINVAL;

	for (i = 0; i < tls->pinned_count; i++) {
		if (!pin_valid(tls->pinned_spki_sha256_base64[i]))
			return EINVAL;
		err = str_dup(&e->pins[i], tls->pinned_spki_sha256_base64[i]);
		if (err)
			return err;
		e->pin_count = i + 1;
	}

	e->tls_min_version = tls->min_version;
	e->verify_server = !tls->insecure_skip_verify;

	return 0;
}


static int copy_modules(bsk_engine *e, const bsk_engine_config *c)
{
	const char *const *names = c->modules;
	size_t count = c->module_count;
	size_t i;

	if (!names || !count) {
		names = default_modules;
		count = RE_ARRAY_SIZE(default_modules);
	}
	if (count > BSK_MAX_MODULES)
		return EINVAL;

	for (i = 0; i < count; i++) {
		int err;

		if (!str_isset(names[i]) || !bsk_name_safe(names[i], "-."))
			return EINVAL;
		err = str_dup(&e->modules[i], names[i]);
		if (err)
			return err;
		e->module_count = i + 1;
	}

	return 0;
}


static int copy_audio(bsk_engine *e, const bsk_audio_config *audio)
{
	int err;

	err = copy_name(e->audio_src_mod, sizeof(e->audio_src_mod),
			audio->source_module, "audiounit");
	err = bsk_first_error(err, copy_device(e->audio_src_dev,
					       sizeof(e->audio_src_dev),
					       audio->source_device));
	err = bsk_first_error(
		err, copy_name(e->audio_play_mod, sizeof(e->audio_play_mod),
			       audio->player_module, "audiounit"));
	err = bsk_first_error(err, copy_device(e->audio_play_dev,
					       sizeof(e->audio_play_dev),
					       audio->player_device));
	err = bsk_first_error(
		err, join_list(e->audio_codecs, sizeof(e->audio_codecs),
			       audio->codecs, audio->codec_count));
	if (err)
		return err;

	e->audio_srate = audio->sample_rate;
	e->audio_channels = audio->channels;
	e->audio_ptime = audio->ptime_ms ? audio->ptime_ms : 20;
	e->jb_min_ms =
		audio->jitter_buffer_min_ms ? audio->jitter_buffer_min_ms : 40;
	e->jb_max_ms =
		audio->jitter_buffer_max_ms ? audio->jitter_buffer_max_ms : 200;
	e->jb_adaptive = audio->jitter_buffer_adaptive;

	return 0;
}


static int copy_video(bsk_engine *e, const bsk_engine_config *c)
{
	const bsk_video_config *video = &c->video;
	int err;

	err = copy_name(e->video_src_mod, sizeof(e->video_src_mod),
			video->source_module, "bskcapture");
	err = bsk_first_error(err, copy_device(e->video_src_dev,
					       sizeof(e->video_src_dev),
					       video->source_device));
	err = bsk_first_error(
		err, join_list(e->video_codecs, sizeof(e->video_codecs),
			       video->codecs, video->codec_count));
	if (err)
		return err;

	e->video_width = video->width ? video->width : 640;
	e->video_height = video->height ? video->height : 480;
	e->video_fps = video->fps ? video->fps : 30;
	e->video_bitrate = video->bitrate_bps ? video->bitrate_bps : 800000;
	e->video_min_bitrate =
		c->video_min_bitrate_bps ? c->video_min_bitrate_bps : 150000;
	if (e->video_min_bitrate > e->video_bitrate)
		e->video_min_bitrate = e->video_bitrate;

	return 0;
}


int bsk_engine_copy_config(bsk_engine *e, const bsk_engine_config *c)
{
	int err;

	if (!bsk_name_safe(c->network_interface, "-.:%"))
		return EINVAL;

	err = dup_str(&e->user_agent, c->user_agent);
	err = bsk_first_error(err,
			      dup_str(&e->instance_uuid, c->instance_uuid));
	err = bsk_first_error(
		err, dup_str(&e->network_interface, c->network_interface));
	err = bsk_first_error(
		err, str_isset(c->extra_config)
			     ? str_dup(&e->extra_config, c->extra_config)
			     : 0);
	err = bsk_first_error(err, copy_tls(e, &c->tls));
	err = bsk_first_error(err, copy_modules(e, c));
	err = bsk_first_error(err, copy_audio(e, &c->audio));
	err = bsk_first_error(err, copy_video(e, c));
	if (err)
		return err;

	e->ipv6 = c->ipv6;
	e->rtp_port_min = c->rtp_port_min ? c->rtp_port_min : 10000;
	e->rtp_port_max = c->rtp_port_max ? c->rtp_port_max : 20000;
	if (e->rtp_port_min > e->rtp_port_max)
		return EINVAL;
	e->max_calls = c->max_calls ? c->max_calls : 4;
	e->log_level = c->log_level;
	e->log_sip_trace = c->log_sip_trace;
	e->ice_relay_only = c->ice_relay_only;
	e->video_adaptive = c->video_adaptive_bitrate;

	return 0;
}


int bsk_engine_build_config(bsk_engine *e, struct mbuf *mb)
{
	int err;

	err = mbuf_printf(
		mb,
		"sip_transports\t\tudp,tcp,tls,wss\n"
		"sip_verify_server\t%s\n"
		"sip_trans_def\t\tudp\n"
		"call_accept\t\tno\n"
		"call_max_calls\t\t%u\n"
		"call_local_timeout\t120\n"
		"audio_source\t\t%s,%s\n"
		"audio_player\t\t%s,%s\n"
		"audio_jitter_buffer_type\t%s\n"
		"audio_jitter_buffer_ms\t%u-%u\n"
		"rtp_ports\t\t%u-%u\n"
		"rtp_stats\t\tyes\n"
		"rtp_timeout\t\t30\n"
		"net_af\t\t\t%s\n"
		"dns_getaddrinfo\t\tyes\n"
		"video_source\t\t%s,%s\n"
		"video_display\t\tbsk,\n"
		"video_size\t\t%ux%u\n"
		"video_fps\t\t%u\n"
		"video_bitrate\t\t%u\n",
		e->verify_server ? "yes" : "no", e->max_calls, e->audio_src_mod,
		e->audio_src_dev, e->audio_play_mod, e->audio_play_dev,
		e->jb_adaptive ? "adaptive" : "fixed", e->jb_min_ms,
		e->jb_max_ms, (unsigned)e->rtp_port_min,
		(unsigned)e->rtp_port_max, e->ipv6 ? "unspecified" : "ipv4",
		e->video_src_mod, e->video_src_dev, e->video_width,
		e->video_height, e->video_fps, e->video_bitrate);

	if (e->audio_srate)
		err |= mbuf_printf(mb,
				   "ausrc_srate\t\t%u\nauplay_srate\t\t%u\n",
				   e->audio_srate, e->audio_srate);
	if (e->audio_channels)
		err |= mbuf_printf(
			mb, "ausrc_channels\t\t%u\nauplay_channels\t\t%u\n",
			e->audio_channels, e->audio_channels);
	err |= mbuf_printf(mb, "ice_policy\t\t%s\n",
			   e->ice_relay_only ? "relay" : "all");
	if (str_isset(e->network_interface))
		err |= mbuf_printf(mb, "net_interface\t\t%s\n",
				   e->network_interface);
	if (str_isset(e->extra_config))
		err |= mbuf_printf(mb, "%s\n", e->extra_config);

	return err ? ENOMEM : 0;
}


static int add_ca_bundle(struct tls *tls, const char *pem)
{
	static const char begin[] = "-----BEGIN CERTIFICATE-----";
	static const char end[] = "-----END CERTIFICATE-----";
	const char *p = pem;
	size_t added = 0;
	int err = 0;

	while (!err) {
		const char *first = strstr(p, begin);
		const char *last = first ? strstr(first, end) : NULL;
		char *one = NULL;
		size_t len;

		if (!first || !last)
			break;

		len = (size_t)(last - first) + sizeof(end) - 1;
		one = mem_zalloc(len + 2, NULL);
		if (!one)
			return ENOMEM;
		memcpy(one, first, len);
		one[len] = '\n';

		err = tls_add_capem(tls, one);
		mem_deref(one);
		added++;
		p = last + sizeof(end) - 1;
	}

	if (!err && !added)
		return EINVAL;

	return err;
}


static int apply_tls(bsk_engine *e, struct tls *tls)
{
	int err = 0;

	if (e->ca_pem)
		err = add_ca_bundle(tls, e->ca_pem);
	if (err)
		return err;

	if (e->client_cert_pem) {
		err = tls_set_certificate_pem(tls, e->client_cert_pem,
					      e->client_cert_pem_len, NULL, 0);
		if (err)
			return err;
	}

	if (e->tls_min_version)
		err = tls_set_min_proto_version(tls, e->tls_min_version);
	if (err)
		return err;

	if (e->cipher_list) {
		const char *cipherv[1] = { e->cipher_list };
		err = tls_set_ciphers(tls, cipherv, 1);
	}
	if (err)
		return err;

	return bsk_tls_install(e, tls);
}


int bsk_engine_apply_tls(bsk_engine *e)
{
	struct tls *tls = uag_tls();
	struct tls *wss = uag_wss_tls();
	int err;

	if (!tls || tls == e->tls_configured)
		return 0;

	err = apply_tls(e, tls);
	if (!err && wss)
		err = apply_tls(e, wss);
	if (err)
		return err;

	e->tls_configured = tls;
	if (!e->verify_server) {
		static const char msg[] =
			"bsk: tls: server certificate verification is OFF";

		bsk_log_emit(e, BSK_LOG_WARNING, BSK_LOG_DOMAIN_CORE, msg,
			     sizeof(msg) - 1);
	}

	return 0;
}
