# App lifecycle, network changes, certificates and logs

Go offline or pause SIP in the background and online again when the app is active, keep calls and registrations
working across network changes, check certificates before using them, and keep logs on disk.

## Overview

These helpers are optional. Each does a job most apps need; apps with their own solution can
leave them out and call the engine directly.

### Background, foreground and termination

`BaresipAppLifecycle` follows the app on iOS:

- In the background with no call, the engine does what `backgroundBehavior` says. With
  `.goOffline` every registered account unregisters, so nobody reaches the app until it returns.
  With `.suspend`, the default, the engine is suspended and its registrations stay on the server,
  so a VoIP push can still announce a call. A call that ends in the background does the same.
- When the app is active again, the transports open again and the accounts register.
- When the app terminates, the engine stops: calls end and every account unregisters.

```swift
let lifecycle = BaresipAppLifecycle(engine: engine)
lifecycle.backgroundBehavior = .goOffline
lifecycle.setChangeHandler { change in print("SIP:", change) }
lifecycle.start()
```

`.stayOnline` and `disconnectsOnTermination` turn the parts off. Going offline asks iOS for a
little background time, so the unregistration is sent before the app is suspended. iOS does not
tell a suspended app that it is removed from the app switcher; with `.suspend`, its registration
then stays on the server until it expires.

### Network changes

When the device moves from Wi-Fi to cellular or back, the engine has to open its transports on
the new address, register again and move running calls. `BaresipNetworkMonitor` watches the
network path and calls ``BaresipEngine/networkDidChange(reregister:updateCalls:)`` when the
available interfaces change. It ignores the first path, paths without a connection and updates
that change nothing.

```swift
let monitor = BaresipNetworkMonitor(engine: engine)
monitor.setChangeHandler { path in
    print("network: \(path.interfaceSummary)")
}
monitor.start()
```

Keep the monitor while the engine runs and call `stop()` before stopping the engine. To decide
yourself, watch `NWPathMonitor` and call `networkDidChange` directly.

### Certificates

``BaresipTLSConfiguration`` takes certificates as PEM. `BaresipCertificates` checks what the
user imports before the engine uses it, with errors that can be shown to the user:

```swift
tls.caCertificatesPEM = try BaresipCertificates.caBundle(from: fileData)          // PEM or DER
tls.clientCertificatePEM = try BaresipCertificates.clientIdentity(from: pemData)  // certificate and key
let names = BaresipCertificates.summaries(tls.caCertificatesPEM)
```

`clientIdentity(from:)` needs the private key unencrypted; `split(_:)` gives the certificate
and key text back, for example to edit them.

### Log files

`BaresipFileLog` writes log lines to one file per day, keeps the last days and can still write
while the device is locked, so the log of a call that arrived then can be shared afterwards:

```swift
let fileLog = BaresipFileLog()
engine.setLogHandler(fileLog.handler(forwardingTo: BaresipOSLog.handler()))
fileLog.write("user tapped Call")
let files = fileLog.files()   // for a share sheet
```
