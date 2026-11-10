#include "test_common.h"

enum { MAX_CERTS = 8 };

bool bsk_trust_system(const char *host, const uint8_t *const *derv,
		      const size_t *lenv, size_t count);


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
	int i;

	if (argc < 3 || argc - 2 > MAX_CERTS) {
		fprintf(stderr, "usage: %s HOST LEAF.der [CA.der...]\n",
			argv[0]);
		return 2;
	}

	for (i = 2; i < argc; i++) {
		owned[count] = read_der(argv[i], &lenv[count]);
		derv[count] = owned[count];
		count++;
	}

	CHECK(bsk_trust_system(argv[1], derv, lenv, count));
	CHECK(!bsk_trust_system("other.invalid", derv, lenv, count));
	CHECK(!bsk_trust_system("192.0.2.1", derv, lenv, count));
	CHECK(!bsk_trust_system("", derv, lenv, count));
	lenv[0] /= 2;
	CHECK(!bsk_trust_system(argv[1], derv, lenv, count));

	for (i = 0; i < (int)count; i++)
		free(owned[i]);

	printf("trust: PASS (%s accepted, other names and a cut chain "
	       "rejected)\n",
	       argv[1]);
	return 0;
}
