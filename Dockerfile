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

COPY cloudflared-start.sh /usr/local/bin/cloudflared-start.sh

RUN chmod 755 /usr/local/bin/cloudflared-start.sh

ENTRYPOINT ["/usr/local/bin/cloudflared-start.sh"]

EXPOSE 8080
