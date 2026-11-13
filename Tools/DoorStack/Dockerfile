ARG BASE=ubuntu:26.04

FROM ${BASE} AS build
ARG RE_VERSION=v4.13.0
ARG BARESIP_VERSION=v4.13.0
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      build-essential cmake git ca-certificates pkg-config zlib1g-dev libssl-dev libopus-dev \
      libavcodec-dev libavformat-dev libavdevice-dev libavfilter-dev libswscale-dev libswresample-dev \
 && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch ${RE_VERSION} https://github.com/baresip/re /src/re \
 && cmake -S /src/re -B /src/re/build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/baresip \
 && cmake --build /src/re/build -j"$(nproc)" \
 && cmake --install /src/re/build
RUN git clone --depth 1 --branch ${BARESIP_VERSION} https://github.com/baresip/baresip /src/baresip \
 && cmake -S /src/baresip -B /src/baresip/build -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/opt/baresip -DCMAKE_PREFIX_PATH=/opt/baresip \
      -DMODULES="account;menu;g711;opus;avcodec;avformat;swscale;ausine;aubridge;fakevideo;stun;ice;ctrl_tcp" \
 && cmake --build /src/baresip/build -j"$(nproc)" \
 && cmake --install /src/baresip/build

FROM ${BASE}
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ffmpeg libopus0 openssl ca-certificates \
      python3 python3-httpx python3-h2 python3-jwt python3-cryptography \
 && rm -rf /var/lib/apt/lists/*
COPY --from=build /opt/baresip /opt/baresip
RUN echo /opt/baresip/lib > /etc/ld.so.conf.d/baresip.conf && ldconfig \
 && ln -s /opt/baresip/bin/baresip /usr/local/bin/baresip

RUN mkdir -p /media \
 && ffmpeg -loglevel error -f lavfi -i "testsrc2=size=640x480:rate=15" -t 300 \
      -c:v libx264 -preset veryfast -crf 30 -g 30 -pix_fmt yuv420p /media/door.mp4

COPY init.sh /opt/doorstack/init.sh
COPY gateway/push_gateway.py /opt/doorstack/push_gateway.py
COPY apns-mock/apns_mock.py /opt/doorstack/apns_mock.py
COPY fcm-mock/fcm_mock.py /opt/doorstack/fcm_mock.py
COPY doorstation/doorstation.py /opt/doorstack/doorstation.py
COPY test/phone_sim.py /opt/doorstack/phone_sim.py

ENV PYTHONUNBUFFERED=1
WORKDIR /opt/doorstack
