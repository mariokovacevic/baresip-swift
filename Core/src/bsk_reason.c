#include <ctype.h>
#include <string.h>
#include <strings.h>
#include "bsk_reason.h"


static const char *skip_space(const char *p, const char *end)
{
	while (p < end && (*p == ' ' || *p == '\t'))
		++p;

	return p;
}


static const char *value_end(const char *p, const char *end)
{
	bool quoted = false;

	for (; p < end; ++p) {
		if (*p == '"')
			quoted = !quoted;
		else if (*p == '\\' && quoted && p + 1 < end)
			++p;
		else if (*p == ',' && !quoted)
			break;
	}

	return p;
}


static const char *find_param(const char *p, const char *end, const char *name)
{
	size_t len = strlen(name);
	bool quoted = false;

	for (; p < end; ++p) {
		const char *q;

		if (*p == '"')
			quoted = !quoted;
		if (quoted || *p != ';')
			continue;

		q = skip_space(p + 1, end);
		if ((size_t)(end - q) <= len || strncasecmp(q, name, len))
			continue;

		q = skip_space(q + len, end);
		if (q < end && *q == '=')
			return skip_space(q + 1, end);
	}

	return NULL;
}


static void copy_text(const char *p, const char *end, char *phrase, size_t size)
{
	size_t n = 0;

	if (!phrase || !size)
		return;

	if (p && p < end && *p == '"') {
		for (++p; p < end && *p != '"' && n + 1 < size; ++p) {
			if (*p == '\\' && p + 1 < end)
				++p;
			phrase[n++] = *p;
		}
	} else if (p) {
		for (; p < end && *p != ';' && *p != ' ' && *p != '\t' &&
		       n + 1 < size;
		     ++p)
			phrase[n++] = *p;
	}

	phrase[n] = '\0';
}


static bool sip_value(const char *p, const char *end, uint16_t *cause,
		      char *phrase, size_t size)
{
	const char *c;
	unsigned value = 0;
	int digits = 0;

	p = skip_space(p, end);
	if (end - p < 4 || strncasecmp(p, "SIP", 3))
		return false;

	p = skip_space(p + 3, end);
	if (p >= end || *p != ';')
		return false;

	c = find_param(p, end, "cause");
	if (!c)
		return false;

	for (; c < end && isdigit((unsigned char)*c) && digits < 4; ++c) {
		value = value * 10 + (unsigned)(*c - '0');
		++digits;
	}

	if (digits != 3 || value < 100 || value > 699)
		return false;

	*cause = (uint16_t)value;
	copy_text(find_param(p, end, "text"), end, phrase, size);

	return true;
}


bool bsk_reason_sip_cause(const char *text, uint16_t *cause, char *phrase,
			  size_t size)
{
	const char *p;
	const char *end;

	if (phrase && size)
		phrase[0] = '\0';

	if (!text || !cause)
		return false;

	p = text;
	end = text + strlen(text);

	while (p < end) {
		const char *next = value_end(p, end);

		if (sip_value(p, next, cause, phrase, size))
			return true;

		p = next < end ? next + 1 : end;
	}

	return false;
}
