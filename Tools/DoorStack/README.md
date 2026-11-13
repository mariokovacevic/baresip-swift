# Door stack

A PBX, a push gateway and a door station simulator in Docker, for trying the sample app as a
video intercom and for developing the server side of one. It is a development setup: it runs on
your computer, for the phones in your network.

| Service | What it does |
|---|---|
| `asterisk` | The PBX. Residents `100` and `101`, the door station `door1`, SIP over UDP and TCP on 5060 and TLS on 5061. |
| `push-gateway` | Sends a push to the resident's phone when the door rings: a VoIP push to Apple for an iPhone, a high-priority data message to Firebase Cloud Messaging for an Android phone, or to the stand-ins below. |
| `apns-mock` | Stands in for Apple's push service, so the stack runs without an Apple key and without a phone. |
| `fcm-mock` | Stands in for Firebase Cloud Messaging, so the stack runs without a Google project and without a phone. |
| `doorstation` | baresip 4.13.0 acting as a door station: H.264 video of a test picture, a tone as audio, a door code. |
| `init` | Runs once: creates the passwords and the certificates in `state/`. |
| `phone-sim` | A scripted phone for `doorstack.sh test`; not started otherwise. |

All services use the host's network, like the integration tests in `Tests/Integration`, so the
phone reaches the PBX at the computer's address; on macOS Asterisk publishes its ports instead
(see the end of this file). The stack and `Scripts/dev-pbx.sh` use the same ports and cannot run together.

## Run it

```bash
Tools/DoorStack/doorstack.sh start
```

```bash
Tools/DoorStack/doorstack.sh ring
```

```bash
Tools/DoorStack/doorstack.sh test
```

```bash
Tools/DoorStack/doorstack.sh stop
```

`start` builds the image (the first time this compiles libre and baresip and takes a few
minutes), starts the services and prints the address, the residents' password and the path of
the certificate. `ring` makes the door station call resident 100, or the one you name.
`logs [service]` follows the logs. Set `HOSTIP` when the script picks the wrong address.

`test` checks the whole path without Apple and without a phone: a scripted phone registers with
a push token and goes away like a suspended app, the door rings, the push arrives at the
stand-in, the phone registers again and gets the INVITE with the UUID of the push, previews
the door's video before answering, answers, sends the door code, and the door station opens
the door and hangs up.

## With the sample app on simulators

```bash
Tools/DoorStack/simulators.sh
```

With the stack started, this builds the sample for the simulator and starts it on two iPhone
simulators, signed in over TLS as residents 100 and 101 with the stack's CA and with door1 as their
Front door and the other one as a contact. Call or write to Neighbour 101 from 100 in Keypad,
Contacts; look at the door (its video; 1234 opens it), or ring a simulator with
`doorstack.sh ring 100`. Asterisk passes a hold through to the other phone, which hears the music
the holding phone plays (`HoldMusic.wav` in the sample). The simulators use the Mac's microphone
and speakers; they get no VoIP push and no CallKit screen, and send no camera picture.

## How a ring reaches a sleeping phone

1. BaresipKit registers with its push tokens in the Contact:
   `pn-tok=<token>:remote&<token>:voip` and `app-id=<bundle identifier>`.
2. iOS suspends the app. The registration stays on the PBX (`maximum_expiration` is 30 days and
   the contact is not qualified), and with it the token.
3. The door station calls the resident. The dialplan (`asterisk/extensions.conf`, context
   `doors`) finds a push token in the resident's contact and raises the `BSKPush` event on the
   manager interface.
4. `push-gateway` reads the event and sends a VoIP push for the token, topic
   `<bundle identifier>.voip`, with the payload `{"from": "sip:door1@<address>", "name": "Front
   door", "video": true, "uuid": "<UUID of the call>"}`.
5. The app wakes, reports the call to iOS under that UUID and registers again. The dialplan
   sees the new registration, at most ten seconds later, and only then rings the phone. The
   INVITE carries the same UUID in the `X-Call-UUID` header, so the app binds it to the call
   it reported, whatever else rings at that moment.

An Android phone registers with `pn-type=firebase`, `pn-tok=<registration token>` and
`app-id=<package>` instead (`BaresipPushTokens` in the Android SDK). For such a contact the
gateway sends a Firebase data message with high priority and the same fields as strings, plus
`"type": "call"`: `{"from": ..., "name": ..., "video": "1", "uuid": ..., "type": "call"}`, which
`BaresipPushCall.from` reads in the app's `FirebaseMessagingService`.

A resident without a push token is rung at once; one without a registration gets 480.

## With the sample app on a phone

1. Start the stack and put `state/asterisk/keys/asterisk.pem` on the phone (AirDrop or Files).
2. In the sample's setup screen, or in Settings, Account: the computer's address as server,
   user `100`, the printed password and TLS. Import the certificate as server CA in Account.
3. In Settings turn on **Reachable when Zvono is closed**, and in Account set the registration
   time to a day or more, so the registration outlives the time the app is suspended. Add a door
   with the SIP user `door1` and the code 1234 to get its picture and the Open door action.
4. Point the gateway at Apple with a token signing key from your developer account:

   ```bash
   APNS_HOST=api.sandbox.push.apple.com APNS_KEY_PATH=/path/to/AuthKey_ABC123.p8 \
     APNS_KEY_ID=ABC123 APNS_TEAM_ID=DEF456 Tools/DoorStack/doorstack.sh start
   ```

   Use `api.push.apple.com` for an app from TestFlight or the App Store. The app needs your own
   bundle identifier and the Push Notifications capability; see the sample's README.
5. Put the app in the background and run `doorstack.sh ring`.

`GET http://127.0.0.1:8088/pushes` lists what the gateway sent and what Apple answered.

For an Android phone, create a Firebase project with the app's package, add `google-services.json`
to the Android sample as its README says, and point the gateway at Google with a service account
key that may send messages:

```bash
FCM_HOST=fcm.googleapis.com FCM_PROJECT_ID=my-project \
  FCM_SERVICE_ACCOUNT_PATH=/path/to/service-account.json Tools/DoorStack/doorstack.sh start
```

`doorstack.sh test` runs the scripted phone twice, once as an iPhone against the APNs stand-in and
once as an Android phone against the FCM stand-in.

## Settings

| Variable | Default | Meaning |
|---|---|---|
| `HOSTIP` | first address of the computer | The address phones use; it is in the certificate. |
| `DOOR_CODE` | `1234` | DTMF that opens the door. |
| `RING_EVERY` | `0` | Seconds between automatic rings; 0 rings only on request. |
| `APNS_HOST` | `127.0.0.1:8443` | Where pushes go; the stand-in by default. |
| `APNS_KEY_PATH`, `APNS_KEY_ID`, `APNS_TEAM_ID` | empty | Token signing key for Apple's servers. |
| `FCM_HOST` | `127.0.0.1:8444` | Where Firebase messages go; the stand-in by default. |
| `FCM_PROJECT_ID` | `doorstack` | The Firebase project. |
| `FCM_SERVICE_ACCOUNT_PATH` | empty | Service account key that signs requests to Google's servers. |

The door station is controlled over `http://127.0.0.1:8089`: `POST /ring?to=101`,
`POST /hangup`, `GET /status`.

## What this is not

- The push token lives in the registration only. A phone whose registration expired cannot be
  woken; a product keeps tokens in its own store and knows when a user signed out.
- Only VoIP pushes are sent. Regular notifications with a picture need a server that can
  provide one.
- There is no TURN server; phones outside your network need one (`Scripts/dev-pbx.sh` has
  coturn).
- The passwords in `state/` are generated per computer and readable by its users, and the PBX
  listens on every interface. Do not run it on an untrusted network.
- Tried here only with the scripted phone and the stand-in for Apple's service, not yet with a
  phone and Apple's servers.
- On macOS the stack does not use Docker Desktop's host networking, which runs the containers
  in a VM: UDP replies to the Mac's network do not come back there, and a phone's connection
  reaches Asterisk from 127.0.0.1. `doorstack.sh` adds `docker-compose.desktop.yml` instead:
  Asterisk on a bridge network with published ports (5060, 5061 and RTP 20000-20200), the other
  services in its network namespace, and the Mac's address as Asterisk's external address.
