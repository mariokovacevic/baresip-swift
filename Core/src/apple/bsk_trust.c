#include <CoreFoundation/CoreFoundation.h>
#include <Security/Security.h>
#include "../bsk_internal.h"


static bool append_certificate(CFMutableArrayRef certs, const uint8_t *der,
			       size_t len)
{
	CFDataRef data = CFDataCreate(kCFAllocatorDefault, der, (CFIndex)len);
	SecCertificateRef cert;

	if (!data)
		return false;

	cert = SecCertificateCreateWithData(kCFAllocatorDefault, data);
	CFRelease(data);
	if (!cert)
		return false;

	CFArrayAppendValue(certs, cert);
	CFRelease(cert);
	return true;
}


bool bsk_trust_system(const char *host, const uint8_t *const *derv,
		      const size_t *lenv, size_t count)
{
	CFMutableArrayRef certs = NULL;
	CFStringRef name = NULL;
	SecPolicyRef policy = NULL;
	SecTrustRef trust = NULL;
	bool ok = false;
	size_t i;

	if (!str_isset(host) || !derv || !lenv || !count)
		return false;

	certs = CFArrayCreateMutable(kCFAllocatorDefault, (CFIndex)count,
				     &kCFTypeArrayCallBacks);
	name = CFStringCreateWithCString(kCFAllocatorDefault, host,
					 kCFStringEncodingUTF8);
	if (!certs || !name)
		goto out;

	for (i = 0; i < count; i++) {
		if (!append_certificate(certs, derv[i], lenv[i]))
			goto out;
	}

	policy = SecPolicyCreateSSL(true, name);
	if (!policy || errSecSuccess != SecTrustCreateWithCertificates(
						certs, policy, &trust))
		goto out;

	ok = SecTrustEvaluateWithError(trust, NULL);

out:
	if (trust)
		CFRelease(trust);
	if (policy)
		CFRelease(policy);
	if (name)
		CFRelease(name);
	if (certs)
		CFRelease(certs);

	return ok;
}
