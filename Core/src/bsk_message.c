#include <string.h>
#include "bsk_internal.h"

struct msg_ctx {
	bsk_engine *e;
	uint64_t id;
	bsk_account_id account;
};


static void resp_handler(int err, const struct sip_msg *msg, void *arg)
{
	struct msg_ctx *m = arg;
	bsk_event ev;

	if (!err && msg && msg->scode < 200)
		return;

	bsk_event_init(&ev, BSK_EVENT_MESSAGE_STATUS);
	ev.account = m->account;
	ev.u.message_status.message_id = m->id;

	if (err) {
		bsk_error_set(&ev.u.message_status.error,
			      bsk_status_from_errno(err), err, 0, NULL,
			      "message not sent: %m", err);
	} else if (msg) {
		ev.u.message_status.sip_status = msg->scode;
		ev.u.message_status.delivered = msg->scode < 300;
		if (msg->scode >= 300) {
			bsk_error_set(&ev.u.message_status.error,
				      msg->scode == 401 || msg->scode == 407
					      ? BSK_ERR_AUTH
					      : BSK_ERR_SIP,
				      0, msg->scode, NULL, "%u %r", msg->scode,
				      &msg->reason);
		}
	}

	bsk_emit(m->e, &ev);
	mem_deref(m);
}


static void recv_handler(struct ua *ua, const struct pl *peer,
			 const struct pl *ctype, struct mbuf *body, void *arg)
{
	bsk_engine *e = arg;
	struct bsk_account_ctx *a = bsk_account_find_ua(e, ua);
	bsk_event ev;

	bsk_event_init(&ev, BSK_EVENT_MESSAGE);
	ev.account = a ? a->id : BSK_ID_NONE;
	if (peer)
		(void)pl_strcpy(peer, ev.u.message.from,
				sizeof(ev.u.message.from));
	if (ctype)
		(void)pl_strcpy(ctype, ev.u.message.content_type,
				sizeof(ev.u.message.content_type));
	if (body) {
		ev.u.message.body = (const char *)mbuf_buf(body);
		ev.u.message.body_len = mbuf_get_left(body);
	}

	bsk_emit(e, &ev);
}


int bsk_message_init(bsk_engine *e)
{
	return message_listen(baresip_message(), recv_handler, e);
}


void bsk_message_close(bsk_engine *e)
{
	(void)e;
	message_unlisten(baresip_message(), recv_handler);
}


struct send_arg {
	bsk_account_id account;
	const char *peer;
	const char *text;
	uint64_t id;
};


static int send_op(bsk_engine *e, void *arg)
{
	struct send_arg *sa = arg;
	struct bsk_account_ctx *a;
	struct msg_ctx *m;
	int err;

	a = sa->account == BSK_ID_NONE ? bsk_account_default(e)
				       : bsk_account_find(e, sa->account);
	if (!a)
		return ENOENT;

	m = mem_zalloc(sizeof(*m), NULL);
	if (!m)
		return ENOMEM;

	m->e = e;
	m->id = ++e->next_message_id;
	m->account = a->id;

	err = message_send(a->ua, sa->peer, sa->text, resp_handler, m);
	if (err) {
		mem_deref(m);
		return err;
	}

	sa->id = m->id;
	return 0;
}


bsk_status bsk_message_send(bsk_engine *engine, bsk_account_id account,
			    const char *peer_uri, const char *text,
			    uint64_t *out_message_id, bsk_error *err)
{
	struct send_arg sa = { account, peer_uri, text, 0 };
	int ret;

	bsk_error_clear(err);

	if (!engine || !str_isset(peer_uri) || !text)
		return bsk_error_set(err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0,
				     NULL, "peer and text are required");

	if (!bsk_text_safe(peer_uri))
		return bsk_error_set(err, BSK_ERR_INVALID_ARGUMENT, EINVAL, 0,
				     NULL,
				     "peer must not contain control "
				     "characters");

	ret = bsk_run(engine, send_op, &sa);
	if (ret)
		return bsk_error_set(err, bsk_status_from_errno(ret), ret, 0,
				     NULL, "message send failed: %m", ret);

	if (out_message_id)
		*out_message_id = sa.id;
	return BSK_OK;
}
