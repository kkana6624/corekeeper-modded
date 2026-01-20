# syntax=docker/dockerfile:1

# Core Keeper Dedicated Server (vanilla) container
# - Uses SteamCMD to install/update the dedicated server at container start
# - Persists save/config under /home/steam/core-keeper-data

FROM cm2network/steamcmd:root

LABEL org.opencontainers.image.title="corekeeper-modded" \
      org.opencontainers.image.description="Core Keeper dedicated server container (vanilla bootstrap)" \
      org.opencontainers.image.source="local"

ENV STEAMAPPDIR="${HOMEDIR}/core-keeper-dedicated" \
    STEAMAPPDATADIR="${HOMEDIR}/core-keeper-data" \
    SCRIPTSDIR="${HOMEDIR}/scripts" \
    # Steam IDs used by the upstream container implementation
    # (1007: Steamworks SDK Redist, 1963720: Core Keeper Dedicated Server)
    STEAMAPPID=1007 \
    STEAMAPPID_TOOL=1963720

# Runtime deps:
# - xvfb: Unity headless needs an X server
# - libs: common Unity/mono dependencies
# - tini: proper signal handling
# - gosu: drop privileges when starting as root
RUN set -eux; \
    dpkg --add-architecture i386; \
    apt-get update; \
    apt-get install -y --no-install-recommends --no-install-suggests \
      xvfb \
      curl \
      unzip \
      libxi6 \
      libxcursor1 \
      libxinerama1 \
      libxss1 \
      libdbus-1-3 \
      libpulse0 \
      libatomic1 \
      libmonosgen-2.0-1 \
      tini \
      tzdata \
      gosu \
      ca-certificates; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p /tmp/.X11-unix; \
    chmod 1777 /tmp/.X11-unix; \
    chown root:root /tmp/.X11-unix

COPY ./scripts/ "${SCRIPTSDIR}/"

RUN set -eux; \
    chmod +x -R "${SCRIPTSDIR}"; \
    mkdir -p "${STEAMAPPDIR}" "${STEAMAPPDATADIR}"; \
    chown -R "${USER}:${USER}" "${SCRIPTSDIR}" "${STEAMAPPDIR}" "${STEAMAPPDATADIR}"

# Dedicated server config (minimal defaults)
ENV PUID=1000 \
    PGID=1000 \
    WORLD_INDEX=0 \
    WORLD_NAME="Core Keeper Server" \
    WORLD_SEED="" \
    WORLD_MODE=0 \
    GAME_ID="" \
    DATA_PATH="${STEAMAPPDATADIR}" \
    MAX_PLAYERS=10 \
    SERVER_IP="" \
    SERVER_PORT="" \
    PASSWORD=""

WORKDIR "${HOMEDIR}"

ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["bash","/home/steam/scripts/entry.sh"]
