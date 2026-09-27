FROM ghcr.io/selkies-project/selkies/desktop:main-ubuntu26.04

USER root

ARG TARGETARCH

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        bash \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) CF_ARCH="amd64" ;; \
        arm64) CF_ARCH="arm64" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    curl -fsSL \
        "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CF_ARCH}" \
        -o /usr/local/bin/cloudflared; \
    chmod 755 /usr/local/bin/cloudflared; \
    cloudflared --version

ENV PORT=8080 \
    SELKIES_PORT=8080 \
    SELKIES_MODE=websockets \
    SELKIES_ENABLE_HTTPS=false \
    SELKIES_WAYLAND=false \
    PASSWD=yaso

RUN mkdir -p \
    /etc/s6-overlay/s6-rc.d/cloudflared/dependencies.d \
    /etc/s6-overlay/user-bundles.d/user/contents.d

COPY cloudflared-run /etc/s6-overlay/s6-rc.d/cloudflared/run

RUN printf '%s\n' 'longrun' \
        > /etc/s6-overlay/s6-rc.d/cloudflared/type && \
    touch /etc/s6-overlay/s6-rc.d/cloudflared/dependencies.d/base && \
    touch /etc/s6-overlay/user-bundles.d/user/contents.d/cloudflared && \
    chmod 755 /etc/s6-overlay/s6-rc.d/cloudflared/run

EXPOSE 8080
