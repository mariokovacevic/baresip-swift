#include <string.h>
#include <openssl/x509.h>
#include <openssl/sha.h>
#include "bsk_internal.h"


static bool spki_sha256_base64(const uint8_t *der, size_t der_len, char *out,
			       size_t out_len)
{
	const unsigned char *p = der;
	X509 *cert;
	unsigned char *spki = NULL;
	int spki_len;
	uint8_t digest[SHA256_DIGEST_LENGTH];
	size_t olen = out_len;
	int err;

	cert = d2i_X509(NULL, &p, (long)der_len);
	if (!cert)
		return false;

	spki_len = i2d_X509_PUBKEY(X509_get_X509_PUBKEY(cert), &spki);
	X509_free(cert);
	if (spki_len <= 0 || !spki)
		return false;

	SHA256(spki, (size_t)spki_len, digest);
	OPENSSL_free(spki);

	err = base64_encode(digest, sizeof(digest), out, &olen);
	if (err || olen >= out_len)
		return false;
	out[olen] = '\0';

	return true;
}


static void tls_warn(bsk_engine *e, const char *msg)
{
	bsk_log_emit(e, BSK_LOG_WARNING, BSK_LOG_DOMAIN_CORE, msg, strlen(msg));
}


static void pin_reset(bsk_engine *e)
{
	e->pin_matched = false;
	e->pin_depth_seen = false;
}


static void pin_check(bsk_engine *e, const uint8_t *der, size_t der_len)
{
	char b64[64];
	size_t i;

	if (!der || !spki_sha256_base64(der, der_len, b64, sizeof(b64)))
		return;

	for (i = 0; i < e->pin_count; i++) {
		if (0 == strcmp(e->pins[i], b64))
			e->pin_matched = true;
	}
}


static int verify_handler(int preverify_ok, int depth, const uint8_t *der,
			  size_t der_len, void *arg)
{
	bsk_engine *e = arg;
	bool matched;

	if (!e)
		return preverify_ok;

	if (!e->pin_depth_seen || depth >= e->pin_last_depth) {
		e->pin_matched = false;
		e->pin_depth_seen = true;
	}
	e->pin_last_depth = depth;

	pin_check(e, der, der_len);

	if (!preverify_ok) {
		pin_reset(e);
		tls_warn(e, "bsk: tls: certificate chain verification failed");
		return 0;
	}

	if (depth > 0)
		return 1;

	matched = e->pin_matched;
	pin_reset(e);

	if (!matched) {
		tls_warn(e, "bsk: tls: no certificate matched a pinned key");
		return 0;
	}

	return 1;
}


int bsk_tls_install_pins(bsk_engine *e)
{
	struct tls *tls = uag_tls();

	if (!e->pin_count)
		return 0;
	if (!tls)
		return ENOSYS;

	return tls_set_verify_server_handler(tls, verify_handler, e);
}
