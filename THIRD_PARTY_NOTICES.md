# Third-party notices

BaresipKit includes software developed by third parties. The full license texts of the pinned
versions in `Build/versions.env` are in [`LICENSES/`](LICENSES); CI checks that they match the
pinned upstream sources. The iOS release ships them as `BaresipKitCore-licenses.zip`.

An app that ships BaresipKit must include these notices, for example on an "Acknowledgements"
screen or in its legal notices.

## libre and baresip

Used by the core on every platform. Licensed under the BSD 3-Clause License
(`LICENSES/libre-LICENSE`, `LICENSES/baresip-LICENSE`).

- Copyright (C) 2020 - 2026, Baresip Foundation (https://github.com/baresip)
- Copyright (c) 2010 - 2024, Alfred E. Heggestad
- Copyright (c) 2010 - 2021, Richard Aas (libre: 2010 - 2020)
- Copyright (c) 2010 - 2021, Creytiv.com (libre: 2010 - 2020)

## OpenSSL

Used by the core on every platform for TLS, DTLS-SRTP and SRTP. Licensed under the Apache
License, Version 2.0 (`LICENSES/OpenSSL-LICENSE.txt`). Copyright (c) 1998-2025 The OpenSSL
Project Authors. OpenSSL 3 has no `NOTICE` file; shipping the license text is enough.

## Opus

Used by the core on every platform. Licensed under the BSD 3-Clause License, with the patent
grants described in `LICENSES/Opus-COPYING`.

Copyright 2001-2023 Xiph.Org, Skype Limited, Octasic, Jean-Marc Valin, Timothy B. Terriberry,
CSIRO, Gregory Maxwell, Mark Borgerding, Erik de Castro Lopo, Mozilla, Amazon.

## G.722 (sippy/libg722)

The G.722 encoder and decoder in `Core/third_party/g722` come from sippy/libg722 (commit
`a2688d2`). Licensed under the BSD 2-Clause License (`LICENSES/libg722-LICENSE`).

- Copyright (c) CMU 1993, Computer Science, Speech Group, Chengxiang Lu and Alex Hauptmann. Use
  of the Carnegie Mellon ADPCM program for any research or commercial purpose is completely
  unrestricted.
- Copyright (C) 2005 Steve Underwood. Placed in the public domain.
- Copyright (c) 2014-2025 Sippy Software, Inc.

## libvpx

Used only where the VP8 module is built: in the Android libraries, not in the iOS release.
Licensed under the BSD 3-Clause License (`LICENSES/libvpx-LICENSE`), with the additional patent
grant in `LICENSES/libvpx-PATENTS`. Copyright (c) 2010, The WebM Project authors.

## H.264 / AVC

H.264 is provided by Apple's VideoToolbox framework on Apple platforms and by the device's
MediaCodec codecs on Android, and is not distributed with BaresipKit. H.264 is covered by patents
licensed through the Via-LA AVC/H.264 patent pool; app publishers are responsible for their own
licensing position.

## Barlow Semi Condensed (sample apps only)

The sample apps bundle two styles of Barlow Semi Condensed: `Examples/SampleApp/SampleApp/Fonts`
on iOS and `Android/zvono/src/main/res/font` on Android. They are not part of the libraries.

Copyright 2017 The Barlow Project Authors (https://github.com/jpt/barlow). Licensed under the
SIL Open Font License, Version 1.1; the full text is in
`Examples/SampleApp/SampleApp/Fonts/OFL.txt` and `Android/zvono/FONTS-OFL.txt`.
