#include <string.h>
#include <re.h>

enum {
	REG_EXPIRES = 4,
	REGISTRAR_PORT = 5080
};

struct proof {
	struct sip *sip;
	struct sipreg *reg;
	struct dnsc *dnsc;
	unsigned ok_count;
	bool unregistered;
};

static struct proof g;

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


static int auth_handler(char **username, char **password,
			const char *realm, void *arg)
{
	int err;
	(void)arg;

	re_printf("proof: digest challenge for realm '%s'\n", realm);

	err  = str_dup(username, "alice");
	err |= str_dup(password, "secret");

	return err;
}


static void resp_handler(int err, const struct sip_msg *msg, void *arg)
{
	(void)arg;

	if (err) {
		re_fprintf(stderr, "proof: register error: %m\n", err);
		re_cancel();
		return;
	}

	if (!msg) {
		re_fprintf(stderr, "proof: no response\n");
		re_cancel();
		return;
	}

	re_printf("proof: REGISTER -> %u %r (expires=%u)\n",
		  (unsigned)msg->scode, &msg->reason,
		  sipreg_proxy_expires(g.reg));

	if (msg->scode != 200) {
		re_cancel();
		return;
	}

	if (g.unregistered) {
		re_printf("proof: unregistered, done\n");
		re_cancel();
		return;
	}

	++g.ok_count;

	switch (g.ok_count) {

	case 1:
		re_printf("proof: phase 2 - update push tokens "
			  "and re-register\n");
		err = sipreg_set_contact_params(g.reg, token_set_b);
		if (!err)
			err = sipreg_send(g.reg);
		if (err) {
			re_fprintf(stderr, "proof: update failed: %m\n", err);
			re_cancel();
		}
		break;

	case 2:
		re_printf("proof: phase 3 - waiting for timer-driven "
			  "refresh (~%u ms)\n", (unsigned)(REG_EXPIRES * 900));
		break;

	case 3:
		re_printf("proof: phase 4 - unregister\n");
		g.unregistered = true;
		sipreg_unregister(g.reg);
		break;

	default:
		break;
	}
}


static void signal_handler(int sig)
{
	re_printf("proof: signal %d\n", sig);
	re_cancel();
}


int main(void)
{
	struct sa laddr;
	char reg_uri[64];
	int err;

	err = libre_init();
	if (err)
		goto out;

	err = dnsc_alloc(&g.dnsc, NULL, NULL, 0);
	if (err)
		goto out;

	err = sip_alloc(&g.sip, g.dnsc, 32, 32, 32,
			"contact-proof/0.1", NULL, NULL);
	if (err)
		goto out;

	err = sa_set_str(&laddr, "127.0.0.1", 0);
	if (err)
		goto out;

	err = sip_transp_add(g.sip, SIP_TRANSP_UDP, &laddr);
	if (err)
		goto out;

	re_snprintf(reg_uri, sizeof(reg_uri), "sip:127.0.0.1:%u",
		    REGISTRAR_PORT);

	err = sipreg_alloc(&g.reg, g.sip, reg_uri,
			   "sip:alice@example.invalid",
			   "Alice",
			   "sip:alice@example.invalid",
			   REG_EXPIRES, "alice",
			   NULL, 0, 0,
			   auth_handler, NULL, false,
			   resp_handler, NULL,
			   NULL,
			   "Allow: INVITE,ACK,BYE,CANCEL,OPTIONS,INFO,"
			   "REFER,NOTIFY,UPDATE\r\n");
	if (err)
		goto out;

	err = sipreg_set_contact_params(g.reg, token_set_a);
	if (err)
		goto out;

	re_printf("proof: phase 1 - initial REGISTER with push "
		  "parameters\n");

	err = sipreg_send(g.reg);
	if (err)
		goto out;

	err = re_main(signal_handler);

 out:
	if (err)
		re_fprintf(stderr, "proof: failed: %m\n", err);

	g.reg = mem_deref(g.reg);
	sip_close(g.sip, true);
	g.sip = mem_deref(g.sip);
	g.dnsc = mem_deref(g.dnsc);

	tmr_debug();
	mem_debug();
	libre_close();

	return err ? 1 : 0;
}
