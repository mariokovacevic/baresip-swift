#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <re.h>
#include "baresip_kit.h"

size_t bsk_redact(const char *in, size_t len, char *out, size_t out_len);

struct bsk_ice_info {
	void *sdpm;
	bsk_ice_state state;
	bsk_candidate_type local_type;
	bsk_candidate_type remote_type;
	char local_addr[64];
	char remote_addr[64];
};
bool bsk_ice_parse_event(const char *text, size_t len, struct bsk_ice_info *out);

static void fuzz_contact(const uint8_t *data, size_t size)
{
	bsk_contact_param params[4];
	char *copy = malloc(size + 1);
	char out[512];
	size_t count = 0, i, start = 0, needed = 0;

	if (!copy)
		return;
	memcpy(copy, data, size);
	copy[size] = '\0';

	for (i = 0; i <= size && count < 4; i++) {
		if (copy[i] == '\n' || copy[i] == '\0') {
			char *eq;
			copy[i] = '\0';
			eq = strchr(copy + start, '=');
			params[count].name = copy + start;
			params[count].value = NULL;
			if (eq) {
				*eq = '\0';
				params[count].value = eq + 1;
			}
			count++;
			start = i + 1;
		}
	}

	(void)bsk_contact_params_encode(params, count, out, sizeof(out), &needed);
	(void)bsk_contact_params_encode(params, count, NULL, 0, &needed);
	(void)bsk_contact_params_encode(params, count, out, size % 32, NULL);
	free(copy);
}

static void fuzz_redact(const uint8_t *data, size_t size)
{
	char out[1024];
	char small[8];

	(void)bsk_redact((const char *)data, size, out, sizeof(out));
	(void)bsk_redact((const char *)data, size, small, sizeof(small));
	(void)bsk_redact((const char *)data, size, out, 1);
}

static void fuzz_ice(const uint8_t *data, size_t size)
{
	struct bsk_ice_info info;
	char *copy = malloc(size + 1);

	if (!copy)
		return;
	memcpy(copy, data, size);
	copy[size] = '\0';
	(void)bsk_ice_parse_event(copy, strlen(copy), &info);
	(void)bsk_ice_parse_event(copy, size, &info);
	free(copy);
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
	if (!size)
		return 0;

	switch (data[0] % 3) {
	case 0: fuzz_contact(data + 1, size - 1); break;
	case 1: fuzz_redact(data + 1, size - 1); break;
	default: fuzz_ice(data + 1, size - 1); break;
	}

	return 0;
}
