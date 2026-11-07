# Integration tests (Asterisk + coturn)

`docker-compose.yml` starts Asterisk (PJSIP, UDP 5060 and TLS 5061, users `alice`/`alicepass` and `bob`/`bobpass`, Opus/G.711/H.264/VP8, ICE; SRTP is offered optionally by the client and declined by this Asterisk build) and coturn (`bsk`/`bsk`, UDP 3478) on the host network. `run_integration.sh` generates a self-signed certificate for Asterisk, starts both containers and runs `bsk_test_integration` (`Tests/Core/test_integration.c`), which covers:

1. registration over TLS with the private CA given in memory;
2. an outgoing audio call to the `echo` extension and RTP statistics;
3. early media from the `early` extension (183 with SDP);
4. DTMF over RFC 4733 and over SIP INFO;
5. hold/resume on an established call;
6. an ICE call with the TURN relay forced (`turn:HOSTIP:3478`);
7. a second call to `bob` from a second account while the first is held, and swapping;
8. a separate engine with the relay-only ICE policy (`ice_relay_only`), run three times with the TURN server reached over UDP (`turn:...?transport=udp`), TCP (`turn:...?transport=tcp`) and TLS (`turns:...:5349`); each must select a relay candidate and send and receive RTP through coturn.

The suite needs Docker and a host-network capable engine (Linux, or Docker Desktop on macOS with the Asterisk ports mapped). It runs in CI as the `integration` job on an Ubuntu runner; to run it locally:

```bash
PREFIX=Build/out/host/prefix HOSTIP=<address> Tests/Integration/run_integration.sh
```
