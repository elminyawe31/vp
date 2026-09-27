FROM ghcr.io/selkies-project/selkies/desktop:main-ubuntu26.04

USER root

ARG TARGETARCH

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) CF_ARCH="amd64" ;; \
        arm64) CF_ARCH="arm64" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    curl -fsSL \
      "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CF_ARCH}" \
      -o /usr/local/bin/cloudflared; \
    chmod +x /usr/local/bin/cloudflared; \
    cloudflared --version

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

ENV PORT=8080
ENV SELKIES_PORT=8080
ENV SELKIES_MODE=websockets
ENV SELKIES_ENABLE_HTTPS=false
ENV SELKIES_WAYLAND=false

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
