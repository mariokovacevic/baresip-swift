# TLS and certificates

Register over TLS with the system trust store, a private CA, a pinned server key or a client
certificate.

## Overview

The TLS settings belong to the engine, in ``BaresipConfiguration/tls``, and apply to every
account that uses ``BaresipTransport/tls``. The server certificate is always verified, and there
is no setting that accepts any certificate.

### The system trust store

With the default ``BaresipTLSConfiguration``, the server's chain is validated against the system
trust store, and its name or IP address against the host the connection goes to: the registrar,
or the outbound proxy when the account has one. Nothing else is needed for a server with a
certificate from a public CA.

### A private CA or a self-signed server

Add the CA certificates in PEM format. They are trusted next to the system store, so a server
whose certificate chains to either is accepted. A self-signed server certificate is its own CA.

```swift
let ca = try BaresipCertificates.caBundle(from: pemOrDERData)
configuration.tls = BaresipTLSConfiguration(caCertificatesPEM: ca)
```

``BaresipCertificates/caBundle(from:)`` accepts PEM or DER and rejects data that holds no
certificate.

### Pinning the server key

``BaresipTLSConfiguration/pinnedSPKISHA256`` lists the base64-encoded SHA-256 hashes of server
public keys (SubjectPublicKeyInfo). With pins, a connection succeeds only when the validated
chain contains one of these keys, so a certificate from another CA for the same name is refused.
Pins are checked in addition to the validation, never instead of it. Pin a key you control, and
keep a second, backup key in the list for the next rotation.

```bash
openssl x509 -in server.pem -pubkey -noout | openssl pkey -pubin -outform der \
  | openssl dgst -sha256 -binary | base64
```

### Mutual TLS

For a server that asks for a client certificate, pass the certificate followed by its private
key, in PEM format, in ``BaresipTLSConfiguration/clientCertificatePEM``. The key must not be
encrypted. ``BaresipCertificates/clientIdentity(from:)`` checks PEM data for a certificate and an
unencrypted key and returns it in that form.

### Versions and ciphers

``BaresipTLSConfiguration/minimumVersion`` is TLS 1.2 by default; set
``BaresipTLSConfiguration/TLSVersion/tls13`` for servers that support it. Older versions are not
available. ``BaresipTLSConfiguration/cipherList`` takes an OpenSSL cipher list for TLS 1.2 and is
rarely needed.

### Media encryption

TLS protects signaling only. Encrypt media with ``BaresipAccountConfiguration/mediaEncryption``;
SRTP keys negotiated with SDES travel in the SIP messages, so use SDES only over TLS.
