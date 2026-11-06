#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size);

static uint32_t rng_state = 0x9e3779b9u;

static uint32_t rng(void)
{
	rng_state ^= rng_state << 13;
	rng_state ^= rng_state >> 17;
	rng_state ^= rng_state << 5;
	return rng_state;
}

static void mutate(uint8_t *buf, size_t *len, size_t cap)
{
	switch (rng() % 5) {
	case 0:
		if (*len)
			buf[rng() % *len] = (uint8_t)rng();
		break;
	case 1:
		if (*len)
			buf[rng() % *len] ^= (uint8_t)(1u << (rng() % 8));
		break;
	case 2:
		if (*len + 1 < cap) {
			size_t pos = rng() % (*len + 1);
			memmove(buf + pos + 1, buf + pos, *len - pos);
			buf[pos] = (uint8_t)rng();
			(*len)++;
		}
		break;
	case 3:
		if (*len > 1) {
			size_t pos = rng() % *len;
			memmove(buf + pos, buf + pos + 1, *len - pos - 1);
			(*len)--;
		}
		break;
	default:
		if (*len) {
			const char *tokens[] = { ";", "=", "&", ":", "pn-tok=", "response=\"",
						 "ice,connected,", "sdpm=0x", " ltype=relay" };
			const char *t = tokens[rng() % 9];
			size_t tl = strlen(t);
			size_t pos = rng() % *len;
			if (*len + tl < cap) {
				memmove(buf + pos + tl, buf + pos, *len - pos);
				memcpy(buf + pos, t, tl);
				*len += tl;
			}
		}
		break;
	}
}

int main(int argc, char **argv)
{
	const char *dir = argc > 1 ? argv[1] : "corpus";
	long runs = argc > 2 ? atol(argv[2]) : 100000;
	DIR *d = opendir(dir);
	struct dirent *ent;
	uint8_t *seeds[64];
	size_t seed_len[64];
	size_t nseeds = 0;
	uint8_t buf[1024];
	long i;

	if (!d) {
		fprintf(stderr, "cannot open corpus %s\n", dir);
		return 1;
	}
	while ((ent = readdir(d)) && nseeds < 64) {
		char path[1024];
		FILE *f;
		long n;
		if (ent->d_name[0] == '.')
			continue;
		snprintf(path, sizeof(path), "%s/%s", dir, ent->d_name);
		f = fopen(path, "rb");
		if (!f)
			continue;
		fseek(f, 0, SEEK_END);
		n = ftell(f);
		fseek(f, 0, SEEK_SET);
		if (n < 0 || n > 1000) {
			fclose(f);
			continue;
		}
		seeds[nseeds] = malloc((size_t)n + 1);
		if (fread(seeds[nseeds], 1, (size_t)n, f) != (size_t)n) {
			fclose(f);
			free(seeds[nseeds]);
			continue;
		}
		seed_len[nseeds] = (size_t)n;
		nseeds++;
		fclose(f);
	}
	closedir(d);

	for (i = 0; i < runs; i++) {
		size_t len;
		if (nseeds && (rng() % 4)) {
			size_t s = rng() % nseeds;
			len = seed_len[s];
			memcpy(buf, seeds[s], len);
		}
		else {
			size_t k;
			len = rng() % 64;
			for (k = 0; k < len; k++)
				buf[k] = (uint8_t)rng();
		}
		{
			int m = (int)(rng() % 6);
			while (m--)
				mutate(buf, &len, sizeof(buf));
		}
		LLVMFuzzerTestOneInput(buf, len);
	}

	for (i = 0; i < (long)nseeds; i++)
		free(seeds[i]);

	printf("driver: %ld iterations without a sanitizer report\n", runs);
	return 0;
}
