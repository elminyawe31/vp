FROM ghcr.io/selkies-project/selkies/desktop:main-ubuntu26.04

# Railway will run the container's main process as UID 0.
# We deliberately do NOT replace Selkies' sudo/fakeroot setup.
#
# The important distinction is:
#   - build image remains the official Selkies image
#   - runtime main process is started by Railway as real root
#   - therefore the desktop/session processes inherit UID 0
#   - apt/dpkg operate on the real filesystem/package database

USER 0

ENV PORT=8080
ENV SELKIES_PORT=8080
ENV SELKIES_MODE=websockets
ENV SELKIES_ENABLE_HTTPS=false
ENV SELKIES_WAYLAND=false

EXPOSE 8080
