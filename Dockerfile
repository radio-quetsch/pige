FROM docker.io/alpine:3.24 AS base

RUN apk update  \
    && apk upgrade \
    && apk add --no-cache --upgrade \
      bash \
      tzdata

FROM base AS recorder

COPY --chmod=0755 recorder.sh healthcheck.sh /usr/local/bin/

RUN apk add --no-cache --upgrade \
      ffmpeg \
    && rm -rf /tmp/* /var/cache/apk/*

VOLUME /recordings

HEALTHCHECK --interval=60s --timeout=5s --start-period=30s --retries=3 \
    CMD healthcheck.sh --check

ENTRYPOINT ["/usr/local/bin/recorder.sh"]

# Build supercronic from source. The Go toolchain runs on the build platform
# and cross-compiles for the target one, so no emulation is needed.
FROM --platform=$BUILDPLATFORM docker.io/golang:1.27-alpine AS supercronic
ARG TARGETOS
ARG TARGETARCH
# renovate: datasource=github-releases depName=aptible/supercronic
ARG SUPERCRONIC_VERSION=v0.2.51

# When cross-compiling, go install puts the binary in a GOOS_GOARCH subdirectory
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go install -trimpath -ldflags="-s -w -X main.Version=${SUPERCRONIC_VERSION}" github.com/aptible/supercronic@${SUPERCRONIC_VERSION} \
    && mkdir /out \
    && find /go/bin -type f -name supercronic -exec mv {} /out/supercronic \;

FROM base AS purger

ENV PURGE_SCHEDULE="0 */6 * * *"

COPY --chmod=0755 purger.sh /usr/local/bin/
COPY --from=supercronic /out/supercronic /usr/local/bin/
COPY --chmod=0755 purger-entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]


