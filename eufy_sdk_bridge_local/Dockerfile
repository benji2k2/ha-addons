# eufy-sdk bridge als HA-App, auf dem Host gebaut.
#
# Baut dasselbe Abbild wie das Dockerfile der Bridge (node:24-alpine + go2rtc + npm-Abhängigkeiten
# + Bridge-Quelltext), nur holt es den Quelltext per git auf einem festen Commit, weil der
# Supervisor als Build-Kontext nur diesen Ordner kennt. Danach die Hülle aus dem Add-on von
# mega-yfue: jq/curl und run.sh, das die App-Optionen in Umgebungsvariablen übersetzt.
#
# Ändert sich das Dockerfile der Bridge (z. B. go2rtc-Version, neue Laufzeitdateien), muss
# dieses hier nachgezogen werden.
ARG BUILD_FROM=node:24-alpine
FROM ${BUILD_FROM}

RUN apk add --no-cache ffmpeg curl jq
WORKDIR /app

ARG GO2RTC_VERSION=1.9.9
ARG TARGETARCH
RUN case "${TARGETARCH:-amd64}" in \
      amd64) g2="go2rtc_linux_amd64" ;; \
      arm64) g2="go2rtc_linux_arm64" ;; \
      *) echo "unsupported TARGETARCH: ${TARGETARCH}" && exit 1 ;; \
    esac \
 && curl -fsSL -o /usr/local/bin/go2rtc \
      "https://github.com/AlexxIT/go2rtc/releases/download/v${GO2RTC_VERSION}/${g2}" \
 && chmod +x /usr/local/bin/go2rtc

# Quelltext auf dem festen Commit. GitHub erlaubt das Holen eines einzelnen Commits per SHA.
ARG BRIDGE_REPO=https://github.com/benji2k2/ha-eufy-sdk-bridge.git
ARG BRIDGE_REF
RUN test -n "$BRIDGE_REF" \
 && apk add --no-cache --virtual .fetch git \
 && git init -q /tmp/src \
 && git -C /tmp/src fetch -q --depth 1 "$BRIDGE_REPO" "$BRIDGE_REF" \
 && git -C /tmp/src checkout -q FETCH_HEAD \
 && echo "bridge commit: $(git -C /tmp/src rev-parse HEAD)" \
 && cp /tmp/src/package.json /tmp/src/package-lock.json \
       /tmp/src/server.mjs /tmp/src/streams.mjs /tmp/src/go2rtc-config.mjs /app/ \
 && cp -r /tmp/src/src /tmp/src/bin /app/ \
 && git -C /tmp/src rev-parse HEAD > /app/BRIDGE_COMMIT \
 && rm -rf /tmp/src \
 && apk del .fetch

# Abhängigkeiten wie im Bridge-Dockerfile: erst der gesperrte Stand, dann optional das SDK
# überlagern (npm-Tag, Version oder URL eines Tarballs).
ARG SDK_DIST_TAG=
RUN npm ci --omit=dev --no-audit --no-fund \
 && if [ -n "$SDK_DIST_TAG" ]; then \
      echo "SDK_DIST_TAG=$SDK_DIST_TAG"; \
      npm install --omit=dev --no-audit --no-fund --no-save "@mega-yfue/eufy-sdk@$SDK_DIST_TAG"; \
    fi \
 && node -e "console.log('SDK:', require('/app/node_modules/@mega-yfue/eufy-sdk/package.json').version)" \
 && npm cache clean --force

RUN chmod +x bin/start.sh && ln -sf /app/bin/start.sh /usr/local/bin/eufy-sdk-bridge

ENV BRIDGE_APP_DIR=/app BRIDGE_PORT=3000 BRIDGE_HOST=0.0.0.0 \
    GO2RTC_CONFIG=/app/data/go2rtc.yaml
RUN mkdir -p /app/data

COPY run.sh /run.sh
RUN chmod +x /run.sh

LABEL \
    org.opencontainers.image.title="HA App: eufy-sdk bridge (lokal)" \
    org.opencontainers.image.description="ha-eufy-sdk bridge aus benji2k2/ha-eufy-sdk-bridge, lokal gebaut." \
    org.opencontainers.image.licenses="MIT"

CMD [ "/run.sh" ]
