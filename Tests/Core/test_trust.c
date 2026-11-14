#include "test_common.h"

enum { MAX_CERTS = 8 };

typedef void(bsk_trust_cert_h)(const uint8_t *der, size_t len, void *arg);
bool bsk_trust_system(const char *host, const uint8_t *const *derv,
		      const size_t *lenv, size_t count, bsk_trust_cert_h *certh,
		      void *arg);

struct visit {
	const uint8_t *der;
	size_t len;
	int seen;
	int count;
};


static void visit(const uint8_t *der, size_t len, void *arg)
{
	struct visit *v = arg;

	v->count++;
	if (len == v->len && 0 == memcmp(der, v->der, len))
		v->seen++;
}


static uint8_t *read_der(const char *path, size_t *len)
{
	FILE *f = fopen(path, "rb");
	uint8_t *buf;
	long n;

	CHECK(f != NULL);
	fseek(f, 0, SEEK_END);
	n = ftell(f);
	fseek(f, 0, SEEK_SET);
	CHECK(n > 0);
	buf = malloc((size_t)n);
	CHECK(buf != NULL);
	CHECK(fread(buf, 1, (size_t)n, f) == (size_t)n);
	fclose(f);
	*len = (size_t)n;
	return buf;
}


int main(int argc, char **argv)
{
	const uint8_t *derv[MAX_CERTS];
	uint8_t *owned[MAX_CERTS];
	size_t lenv[MAX_CERTS];
	size_t count = 0;
	struct visit v = { NULL, 0, 0, 0 };
	bool unvisited = argc > 1 && 0 == strcmp(argv[1], "--unvisited");
	int first = unvisited ? 3 : 2;
	int i;

	if (argc < first + 1 || argc - first > MAX_CERTS) {
		fprintf(stderr,
			"usage: %s [--unvisited] HOST LEAF.der [CA.der...]\n",
			argv[0]);
		return 2;
	}

	for (i = first; i < argc; i++) {
		owned[count] = read_der(argv[i], &lenv[count]);
		derv[count] = owned[count];
		count++;
	}

	v.der = derv[count - 1];
	v.len = lenv[count - 1];
	CHECK(bsk_trust_system(argv[first - 1], derv, lenv, count, visit, &v));
	CHECK(v.count > 0);
	if (unvisited) {
		CHECK(v.seen == 0);
	}
	CHECK(!bsk_trust_system("other.invalid", derv, lenv, count, NULL,
				NULL));
	CHECK(!bsk_trust_system("192.0.2.1", derv, lenv, count, NULL, NULL));
	CHECK(!bsk_trust_system("", derv, lenv, count, NULL, NULL));
	lenv[0] /= 2;
	v.count = 0;
	CHECK(!bsk_trust_system(argv[first - 1], derv, lenv, count, visit, &v));
	CHECK(v.count == 0);

	for (i = 0; i < (int)count; i++)
		free(owned[i]);

	if (unvisited)
		printf("trust: PASS (%s accepted; a certificate appended to "
		       "the chain is not part of the verified chain)\n",
		       argv[first - 1]);
	else
		printf("trust: PASS (%s accepted, other names and a cut chain "
		       "rejected)\n",
		       argv[first - 1]);
	return 0;
}
