# Interoperability

Which SIP servers, door stations, TURN servers and phones BaresipKit has been tried with, and what
worked. The first table is what this repository's tests and tools cover; the second is what
people report from their own devices. Add yours with the
[interop report](https://github.com/mariokovacevic/baresipkit/issues/new?template=interop_report.yml)
issue form.

## Tested by this repository

| Counterpart | Version | How | What is covered |
|---|---|---|---|
| Asterisk, PJSIP | 23.5.0 (pinned image) | `Tests/Integration`, CI job `integration`, on every push | registration over TLS with a private CA, audio calls with RTP statistics, early media (183 with SDP), DTMF over RFC 4733 and SIP INFO, hold and resume, a second call and swapping, ICE through TURN |
| coturn | 4.6.3 | `Tests/Integration`, on every push | TURN over UDP, TCP and TLS with the relay-only policy, and failures within 20 seconds when the TURN server cannot be used |
| Asterisk as an intercom PBX, baresip 4.13.0 as the door station | 23.5.0 | `Tools/DoorStack/simulators.sh`, by hand with the sample app on two simulators | registration over TLS, a ring from the door, calls and messages between residents on G.711, hold with the phone's music on hold passed through |

The sample app's UI test and screenshots run against a minimal TLS registrar
(`Tools/ContactParameterProof/tls_registrar.py`) and a BaresipKit test peer; they test the app,
not interoperability. `Tools/DoorStack/doorstack.sh test` checks the door stack itself with a
scripted phone, not BaresipKit.

## Reported by users

No reports yet.

| Counterpart | Kind | Version or firmware | Transport | Works | Does not work | Report |
|---|---|---|---|---|---|---|

Kind is one of: SIP server or PBX, hosted SIP provider, door station or intercom, phone or
softphone, TURN or media relay.

## What to try

A report is most useful when it says, for each of these, whether it worked, failed or was not
tried:

1. Registration over UDP, TCP and TLS, and staying registered for an hour.
2. An outgoing and an incoming audio call, in both directions for at least a minute.
3. Video in both directions (H.264).
4. Seeing and hearing a door station before answering (early media preview).
5. Opening a door with a code (DTMF over RFC 4733 or SIP INFO).
6. Hold and resume, and music on hold heard by the other side.
7. Blind and attended transfer.
8. Messages (SIP MESSAGE) in both directions.
9. A ring that wakes the app through a VoIP push.
10. A call that survives switching between Wi-Fi and mobile data.

Attach a SIP trace with `logSIPTrace` enabled for anything that failed, with passwords,
Authorization headers, push tokens, phone numbers and real host names removed.
