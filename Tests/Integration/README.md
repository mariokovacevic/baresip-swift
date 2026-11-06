# Integration tests (Asterisk + coturn)

`docker-compose.yml` starts Asterisk (PJSIP, UDP 5060 and TLS 5061, users `alice`/`alicepass` and `bob`/`bobpass`, Opus/G.711/H.264/VP8, ICE, SDES-SRTP optimistic) and coturn (`bsk`/`bsk`, UDP 3478) on the host network. `run_integration.sh` generates a self-signed certificate for Asterisk, starts both containers and runs `bsk_test_integration` (`Tests/Core/test_integration.c`), which covers:

1. registration over TLS with the private CA given in memory;
2. an outgoing audio call to the `echo` extension and RTP statistics;
3. early media from the `early` extension (183 with SDP);
4. DTMF over RFC 4733 and over SIP INFO;
5. hold/resume on an established call;
6. an ICE call with the TURN relay forced (`turn:HOSTIP:3478`);
7. a second call to `bob` from a second account while the first is held, and swapping.

The suite needs Docker and a host-network capable engine (Linux, or Docker Desktop on macOS with the Asterisk ports mapped). It is not part of the default CI yet; run it manually:

```bash
PREFIX=Build/out/host/prefix HOSTIP=<address> Tests/Integration/run_integration.sh
```
