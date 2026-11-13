#include <string.h>
#include <stdarg.h>
#include <stdio.h>
#include "bsk_internal.h"
#include "bsk_engine_internal.h"


uint32_t bsk_abi_version(void)
{
	return ((uint32_t)BSK_ABI_VERSION_MAJOR << 16) | BSK_ABI_VERSION_MINOR;
}


const char *bsk_version_string(void)
{
	return BSK_VERSION_STRING;
}


const char *bsk_status_string(bsk_status status)
{
	switch (status) {
	case BSK_OK: return "ok";
	case BSK_ERR_INVALID_ARGUMENT: return "invalid argument";
	case BSK_ERR_INVALID_STATE: return "invalid state";
	case BSK_ERR_NOT_FOUND: return "not found";
	case BSK_ERR_NO_MEMORY: return "out of memory";
	case BSK_ERR_UNSUPPORTED: return "unsupported";
	case BSK_ERR_BUSY: return "busy";
	case BSK_ERR_TIMEOUT: return "timeout";
	case BSK_ERR_NETWORK: return "network error";
	case BSK_ERR_TLS: return "tls error";
	case BSK_ERR_AUTH: return "authentication failed";
	case BSK_ERR_SIP: return "sip error";
	case BSK_ERR_MEDIA: return "media error";
	case BSK_ERR_BUFFER_TOO_SMALL: return "buffer too small";
	default: return "internal error";
	}
}


uint64_t bsk_now_ms(void)
{
	return tmr_jiffies();
}


void bsk_error_clear(bsk_error *err)
{
	if (err)
		memset(err, 0, sizeof(*err));
}


bsk_status bsk_error_set(bsk_error *err, bsk_status status, int sys_errno,
			 uint16_t sip_status, const char *sip_reason,
			 const char *fmt, ...)
{
	if (!err)
		return status;

	memset(err, 0, sizeof(*err));
	err->status = status;
	err->sys_errno = sys_errno;
	err->sip_status = sip_status;
	if (sip_reason)
		str_ncpy(err->sip_reason, sip_reason, sizeof(err->sip_reason));
	if (fmt) {
		va_list ap;
		va_start(ap, fmt);
		(void)re_vsnprintf(err->message, sizeof(err->message), fmt, ap);
		va_end(ap);
	}

	return status;
}


bsk_status bsk_status_from_errno(int err)
{
	switch (err) {
	case 0: return BSK_OK;
	case EINVAL: return BSK_ERR_INVALID_ARGUMENT;
	case ENOMEM: return BSK_ERR_NO_MEMORY;
	case ENOENT: return BSK_ERR_NOT_FOUND;
	case ENODEV: return BSK_ERR_NOT_FOUND;
	case ENOSYS: return BSK_ERR_UNSUPPORTED;
	case EPROTONOSUPPORT: return BSK_ERR_UNSUPPORTED;
	case EBUSY: return BSK_ERR_BUSY;
	case EALREADY: return BSK_ERR_INVALID_STATE;
	case ETIMEDOUT: return BSK_ERR_TIMEOUT;
	case EAUTH: return BSK_ERR_AUTH;
	case ECONNREFUSED:
	case ECONNRESET:
	case EHOSTUNREACH:
	case ENETUNREACH:
	case EADDRNOTAVAIL: return BSK_ERR_NETWORK;
	default: return BSK_ERR_INTERNAL;
	}
}


bool bsk_text_safe(const char *s)
{
	if (!s)
		return true;

	for (; *s; s++) {
		if ((unsigned char)*s < 0x20 || *s == 0x7f)
			return false;
	}

	return true;
}


bool bsk_name_safe(const char *s, const char *extra)
{
	if (!s)
		return true;

	for (; *s; s++) {
		unsigned char c = (unsigned char)*s;

		if ((c >= '0' && c <= '9') || (c >= 'A' && c <= 'Z') ||
		    (c >= 'a' && c <= 'z') || c == '_')
			continue;
		if (extra && strchr(extra, *s))
			continue;
		return false;
	}

	return true;
}


int bsk_first_error(int err, int next)
{
	return err ? err : next;
}


size_t bsk_capabilities(char *buf, size_t buf_len)
{
	static const char caps[] =
		"sip.udp sip.tcp sip.tls sip.wss "
		"auth.md5 auth.sha256 "
		"reg.outbound reg.contact-params "
		"call.hold call.transfer.blind call.transfer.attended "
		"call.early-media call.recording call.no-audio call.headers "
		"call.session-timer "
		"message.sip "
		"dtmf.rfc4733 dtmf.sip-info "
		"nat.ice nat.stun nat.turn-udp nat.turn-tcp nat.turn-tls "
		"nat.rtcp-mux nat.pinhole "
		"ice.restart ice.trickle:unsupported "
		"media.srtp media.dtls-srtp "
		"codec.opus codec.g722 codec.g711 "
		"video.h264.videotoolbox video.vp8:optional "
		"video.adaptive-bitrate video.picture-update.sip-info "
		"audio.hold-music tls.pinning";
	size_t len = sizeof(caps) - 1;

	if (buf && buf_len) {
		size_t n = min(len, buf_len - 1);
		memcpy(buf, caps, n);
		buf[n] = '\0';
	}

	return len;
}
