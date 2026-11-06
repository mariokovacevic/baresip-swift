#include <string.h>
#include <re.h>
#include <rem.h>
#include <baresip.h>

#ifndef REGISTRAR_HOST
#define REGISTRAR_HOST "127.0.0.1"
#endif

enum {
	REGISTRAR_PORT = 5080
};

static const char config_buf[] =
	"sip_transports\t\tudp\n"
	"call_max_calls\t\t2\n";

static const char account_fmt[] =
	"\"Alice\" <sip:alice@%s:%u;transport=udp>"
	";auth_user=alice;auth_pass=secret;regint=4";

static const char *token_set_a =
	"app-id=com.example.proof;pn-type=apple;"
	"pn-tok=0000000000000000000000000000000000000000000000000000000000000001"
	":remote&1111111111111111111111111111111111111111111111111111111111111111"
	":voip;pn-silent=1;pn-timeout=0;pn-channel=calls";

static const char *token_set_b =
	"app-id=com.example.proof;pn-type=apple;"
	"pn-tok=2222222222222222222222222222222222222222222222222222222222222222"
	":remote&3333333333333333333333333333333333333333333333333333333333333333"
	":voip;pn-silent=1;pn-timeout=0;pn-channel=calls";

static struct ua *ua;
static struct tmr tmr_quit;
static unsigned ok_count;


static void quit_handler(void *arg)
{
	(void)arg;
	re_cancel();
}


static void event_handler(enum bevent_ev ev, struct bevent *event, void *arg)
{
	int err;
	(void)event;
	(void)arg;

	switch (ev) {

	case BEVENT_REGISTER_OK:
		++ok_count;
		re_printf("proof: REGISTER_OK #%u\n", ok_count);

		if (ok_count == 1) {
			re_printf("proof: phase 2 - update push tokens via "
				  "ua_set_contact_params\n");
			err = ua_set_contact_params(ua, token_set_b);
			if (err)
				re_fprintf(stderr, "proof: update failed: %m\n",
					   err);
		}
		else if (ok_count == 2) {
			re_printf("proof: phase 3 - waiting for timer-driven "
				  "refresh\n");
		}
		else if (ok_count == 3) {
			re_printf("proof: phase 4 - unregister\n");
			ua_unregister(ua);
			tmr_start(&tmr_quit, 500, quit_handler, NULL);
		}
		break;

	case BEVENT_REGISTER_FAIL:
		re_fprintf(stderr, "proof: REGISTER_FAIL: %s\n",
			   bevent_get_text(event));
		re_cancel();
		break;

	default:
		break;
	}
}


static void signal_handler(int sig)
{
	(void)sig;
	re_cancel();
}


int main(void)
{
	char account_line[256];
	int err;

	re_snprintf(account_line, sizeof(account_line), account_fmt,
		    REGISTRAR_HOST, (unsigned)REGISTRAR_PORT);

	err = libre_init();
	if (err)
		goto out;

	err = conf_configure_buf((const uint8_t *)config_buf,
				 strlen(config_buf));
	if (err)
		goto out;

	err = baresip_init(conf_config());
	if (err)
		goto out;

	err = ua_init("contact-proof-baresip/0.1", true, false, false);
	if (err)
		goto out;

	err = bevent_register(event_handler, NULL);
	if (err)
		goto out;

	err = ua_alloc(&ua, account_line);
	if (err)
		goto out;

	err = account_set_contact_params(ua_account(ua), token_set_a);
	if (err)
		goto out;

	re_printf("proof: phase 1 - initial REGISTER with push parameters "
		  "(baresip ua API)\n");

	err = ua_register(ua);
	if (err)
		goto out;

	err = re_main(signal_handler);

 out:
	if (err)
		re_fprintf(stderr, "proof: failed: %m\n", err);

	tmr_cancel(&tmr_quit);
	bevent_unregister(event_handler);
	ua_stop_all(true);
	ua_close();
	baresip_close();
	conf_close();
	libre_close();
	mem_debug();

	return err ? 1 : 0;
}
