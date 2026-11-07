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
static int dup_str(char **dst, const char *src)
{
	*dst = NULL;
	if (!str_isset(src))
		return 0;
	return str_dup(dst, src);
}


int bsk_engine_copy_config(bsk_engine *e, const bsk_engine_config *c)
{
	int err = 0;
	size_t i;

	err |= dup_str(&e->user_agent, c->user_agent);
	err |= dup_str(&e->instance_uuid, c->instance_uuid);
	err |= dup_str(&e->network_interface, c->network_interface);
	err |= dup_str(&e->extra_config, c->extra_config);
	err |= dup_str(&e->cipher_list, c->tls.cipher_list);

	if (c->tls.ca_pem && c->tls.ca_pem_len) {
		e->ca_pem = mem_zalloc(c->tls.ca_pem_len + 1, NULL);
		if (!e->ca_pem)
			return ENOMEM;
		memcpy(e->ca_pem, c->tls.ca_pem, c->tls.ca_pem_len);
		e->ca_pem_len = c->tls.ca_pem_len;
	}
	if (c->tls.client_cert_pem && c->tls.client_cert_pem_len) {
		e->client_cert_pem =
			mem_zalloc(c->tls.client_cert_pem_len + 1, NULL);
		if (!e->client_cert_pem)
			return ENOMEM;
		memcpy(e->client_cert_pem, c->tls.client_cert_pem,
		       c->tls.client_cert_pem_len);
		e->client_cert_pem_len = c->tls.client_cert_pem_len;
	}

	if (c->tls.pinned_count && c->tls.pinned_spki_sha256_base64) {
		if (c->tls.pinned_count > RE_ARRAY_SIZE(e->pins))
			return EINVAL;
		for (i = 0; i < c->tls.pinned_count; i++)
			err |= dup_str(&e->pins[i],
				       c->tls.pinned_spki_sha256_base64[i]);
		e->pin_count = c->tls.pinned_count;
	}

	e->tls_min_version = c->tls.min_version;
	e->verify_server = c->tls.verify_server;
	e->ipv6 = c->ipv6;
	e->rtp_port_min = c->rtp_port_min ? c->rtp_port_min : 10000;
	e->rtp_port_max = c->rtp_port_max ? c->rtp_port_max : 20000;
	e->max_calls = c->max_calls ? c->max_calls : 4;
	e->log_level = c->log_level;
	e->log_sip_trace = c->log_sip_trace;
	e->ice_relay_only = c->ice_relay_only;
	e->video_adaptive = c->video_adaptive_bitrate;

	if (c->modules && c->module_count) {
		if (c->module_count > BSK_MAX_MODULES)
			return EINVAL;
		for (i = 0; i < c->module_count; i++)
			err |= dup_str(&e->modules[i], c->modules[i]);
		e->module_count = c->module_count;
	} else {
		for (i = 0; i < RE_ARRAY_SIZE(default_modules); i++)
			err |= dup_str(&e->modules[i], default_modules[i]);
		e->module_count = RE_ARRAY_SIZE(default_modules);
	}

	str_ncpy(e->audio_src_mod,
		 str_isset(c->audio.source_module) ? c->audio.source_module
						   : "audiounit",
		 sizeof(e->audio_src_mod));
	str_ncpy(e->audio_src_dev,
		 c->audio.source_device ? c->audio.source_device : "",
		 sizeof(e->audio_src_dev));
	str_ncpy(e->audio_play_mod,
		 str_isset(c->audio.player_module) ? c->audio.player_module
						   : "audiounit",
		 sizeof(e->audio_play_mod));
	str_ncpy(e->audio_play_dev,
		 c->audio.player_device ? c->audio.player_device : "",
		 sizeof(e->audio_play_dev));
	e->audio_srate = c->audio.sample_rate;
	e->audio_channels = c->audio.channels;
	e->audio_ptime = c->audio.ptime_ms ? c->audio.ptime_ms : 20;
	e->jb_min_ms = c->audio.jitter_buffer_min_ms
			       ? c->audio.jitter_buffer_min_ms
			       : 40;
	e->jb_max_ms = c->audio.jitter_buffer_max_ms
			       ? c->audio.jitter_buffer_max_ms
			       : 200;
	e->jb_adaptive = c->audio.jitter_buffer_adaptive;
	e->voice_processing = c->audio.voice_processing;

	str_ncpy(e->video_src_mod,
		 str_isset(c->video.source_module) ? c->video.source_module
						   : "bskcapture",
		 sizeof(e->video_src_mod));
	str_ncpy(e->video_src_dev,
		 c->video.source_device ? c->video.source_device : "",
		 sizeof(e->video_src_dev));
	e->video_width = c->video.width ? c->video.width : 640;
	e->video_height = c->video.height ? c->video.height : 480;
	e->video_fps = c->video.fps ? c->video.fps : 30;
	e->video_bitrate = c->video.bitrate_bps ? c->video.bitrate_bps : 800000;
	e->video_min_bitrate =
		c->video_min_bitrate_bps ? c->video_min_bitrate_bps : 150000;
	if (e->video_min_bitrate > e->video_bitrate)
		e->video_min_bitrate = e->video_bitrate;

	return err;
}


int bsk_engine_build_config(bsk_engine *e, struct mbuf *mb)
{
	int err;

	err = mbuf_printf(
		mb,
		"sip_transports\t\tudp,tcp,tls,wss\n"
		"sip_verify_server\t%s\n"
		"sip_trans_def\t\tudp\n"
		"call_accept\t\tyes\n"
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

	return err;
}


int bsk_engine_apply_tls(bsk_engine *e)
{
	struct tls *tls = uag_tls();
	int err = 0;

	if (!tls)
		return 0;

	if (e->ca_pem)
		err = tls_add_capem(tls, e->ca_pem);
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

	return bsk_tls_install_pins(e);
}
