# NAT traversal with STUN, ICE and TURN

Get media through NATs and firewalls.

## Overview

Each account has its own ``BaresipAccountConfiguration/nat`` settings. SIP itself usually needs
nothing more than a server that handles NAT for the signaling; media needs one of the methods
below.

### Choosing a method

- ``BaresipNATTraversal/none``: the default. The far side and the server rely on symmetric RTP,
  sending media back to where it comes from. This works with most SIP servers that act as a media
  relay.
- ``BaresipNATTraversal/stun``: the engine learns its public address from a STUN server and puts
  it into the SDP. It helps behind simple NATs, not behind symmetric ones.
- ``BaresipNATTraversal/ice``: ICE (RFC 8445) gathers host, server reflexive and, with a TURN
  server, relayed candidates, and both sides pick the pair that works. Use it whenever the far
  side supports ICE, and always with a TURN server for networks that block direct UDP.

```swift
var account = BaresipAccountConfiguration(aor: "sip:alice@example.com", authPassword: password)
account.nat = BaresipNATConfiguration(
    mode: .ice,
    stunURI: "stun:stun.example.com:3478",
    turnServers: [BaresipTURNServer(uri: "turns:turn.example.com:5349",
                                    username: "alice", password: turnPassword)]
)
```

A TURN server can be reached over UDP (`turn:host:3478`), TCP (`turn:host:3478?transport=tcp`) or TLS (`turns:host:5349`),
which gets through networks that allow only HTTPS-like traffic. One TURN server per account is
supported.

### State and network changes

``BaresipICEEvent`` reports the ICE state and the selected candidate types for each call, so the
app can show, for example, that a call is relayed. When the device changes networks, call
``BaresipEngine/networkDidChange(reregister:updateCalls:)``: calls with ICE restart it on the new
network; see <doc:NetworkChanges>. ``BaresipEngine/restartICE(callID:)`` restarts it for one
call.

### Media relays and receive-only streams

``BaresipNATConfiguration/rtcpMultiplexing`` keeps RTCP on the RTP port, which means one NAT
binding per stream; it is on by default. ``BaresipNATConfiguration/pinhole`` makes a stream that
only receives send empty RTP packets until the peer's media arrives, for relays that forward media
only after they have seen a packet from this side, such as an early media preview without ICE.

### Timeouts

``BaresipNATConfiguration/rtpTimeout`` ends an established call that receives no RTP for that
long, for example after the network went away for good.
