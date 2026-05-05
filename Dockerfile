FROM docker.io/alpine:3.23 AS base

RUN apk update  \
    && apk upgrade \
    && apk add --no-cache --upgrade \
      bash \
      tzdata

FROM base AS recorder

COPY --chmod=0755 recorder.sh /usr/local/bin/

RUN apk add --no-cache --upgrade \
      ffmpeg \
    && rm -rf /tmp/* /var/cache/apk/*

VOLUME /recordings

ENTRYPOINT ["/usr/local/bin/recorder.sh"]

FROM base AS supercronic

ENV SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/v0.2.45/supercronic-linux-amd64 \
    SUPERCRONIC_SHA1SUM=e894b193bea75a5ee644e700c59e30eedc804cf7 \
    SUPERCRONIC=supercronic-linux-amd64

RUN apk add --no-cache --upgrade \
      curl 

RUN curl -fsSLO "$SUPERCRONIC_URL" \
    && echo "${SUPERCRONIC_SHA1SUM}  ${SUPERCRONIC}" | sha1sum -c - \
    && chmod +x "$SUPERCRONIC" \
    && mv "$SUPERCRONIC" "/usr/local/bin/${SUPERCRONIC}" \
    && cp "/usr/local/bin/${SUPERCRONIC}" /usr/local/bin/supercronic

FROM supercronic AS purger

ENV PURGE_SCHEDULE="0 */6 * * *"

COPY --chmod=0755 purger.sh /usr/local/bin/
COPY --from=supercronic /usr/local/bin/supercronic /usr/local/bin/
COPY --chmod=0755 purger-entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]


