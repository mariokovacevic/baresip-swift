# Integration tests (Asterisk + coturn)

`docker-compose.yml` starts Asterisk (PJSIP, UDP 5060 and TLS 5061, users `alice`/`alicepass` and `bob`/`bobpass`, Opus/G.711/H.264/VP8, ICE; SRTP is offered optionally by the client and declined by this Asterisk build) and coturn (`bsk`/`bsk`, UDP 3478) on the host network. `run_integration.sh` generates a self-signed certificate for Asterisk, starts both containers and runs `bsk_test_integration` (`Tests/Core/test_integration.c`), which covers:

1. registration over TLS with the private CA given in memory;
2. an outgoing audio call to the `echo` extension and RTP statistics;
3. early media from the `early` extension (183 with SDP);
4. DTMF over RFC 4733 and over SIP INFO;
5. hold/resume on an established call;
6. an ICE call with the TURN relay forced (`turn:HOSTIP:3478`);
7. a second call to `bob` from a second account while the first is held, and swapping;
8. a separate engine with the relay-only ICE policy (`ice_relay_only`), run three times with the TURN server reached over UDP (`turn:...?transport=udp`), TCP (`turn:...?transport=tcp`) and TLS (`turns:...:5349`); each must select a relay candidate and send and receive RTP through coturn;
9. relay-only call attempts with a TURN server that cannot be used, which must end with a failure within 20 seconds instead of waiting forever: TURN over TCP on a closed port (`refused`), `turns:` on a port that answers in plain text (`plaintext`), TURN over TCP on a port that accepts the connection and never answers (`silent`, ends after the 10 second gathering timeout of patch 0007), and coturn with a wrong password (`credentials`). The first three use listeners inside the test and need no server: `bsk_test_integration <address> turn-failure refused`.

The images are pinned: Asterisk 23.5.0 by tag and digest (the image `latest` pointed to on 2026-11-04), coturn 4.6.3 by tag.

`Scripts/dev-pbx.sh start` runs the same Asterisk and coturn for manual testing with the sample app on a phone, with a coturn configuration of its own (`docker-compose.dev.yml`): a random TURN password, printed at start, and no `allow-loopback-peers`, so the relay cannot be used to reach services on the computer's loopback interface; see [Docs/DeviceTesting.md](../../Docs/DeviceTesting.md).

The suite needs Docker and a host-network capable engine (Linux, or Docker Desktop on macOS with the Asterisk ports mapped). It runs in CI as the `integration` job on an Ubuntu runner; to run it locally:

```bash
PREFIX=Build/out/host/prefix HOSTIP=<address> Tests/Integration/run_integration.sh
```
