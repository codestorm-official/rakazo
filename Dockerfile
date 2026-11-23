# Rakazo on Railway: one service runs the API, worker, and web client on a shared /data volume.
#
# Pins the official Rakazo application image. The upstream Railway image builds from source;
# this packaging reuses the published release image and adds the small process supervisor
# (gosu + tini) plus a Railway-specific start script.
FROM ghcr.io/elie222/rakazo/app:v0.14.0

# The base image runs as node. Railway mounts volumes root-owned, so start as root,
# fix /data ownership, then drop back to node.
USER root

RUN apt-get update \
  && apt-get install -y --no-install-recommends gosu tini \
  && rm -rf /var/lib/apt/lists/*

COPY --chmod=755 start.sh /usr/local/bin/rakazo-start
COPY --chmod=644 sandbox-environment.mjs /usr/local/share/rakazo/sandbox-environment.mjs

ENV DATA_DIR=/data

EXPOSE 5173

ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/usr/local/bin/rakazo-start"]
