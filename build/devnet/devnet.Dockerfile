# syntax=docker.io/docker/dockerfile:1.4
FROM debian:bookworm-20230814-slim as devnet-base

# install curl and jq (for healthcheck support)
RUN <<EOF
apt-get update
DEBIAN_FRONTEND="noninteractive" apt-get install -y --no-install-recommends ca-certificates curl git jq xxd
rm -rf /var/lib/apt/lists/*
EOF

# download pre-compiled binaries
RUN curl -sSL https://github.com/foundry-rs/foundry/releases/download/nightly/foundry_nightly_linux_$(dpkg --print-architecture).tar.gz | \
    tar -zx -C /usr/local/bin

# healthcheck script using net_listening JSON-RPC method
COPY eth_isready /usr/local/bin

HEALTHCHECK CMD eth_isready
CMD ["anvil"]


FROM devnet-base as devnet-deploy

WORKDIR /usr/share/cartesi
COPY deploy-rollups-anvil.sh .

RUN ./deploy-rollups-anvil.sh .


FROM devnet-base as devnet

WORKDIR /usr/share/cartesi
COPY ./entrypoint.sh /
COPY --from=devnet-deploy /usr/share/cartesi/anvil_state.json .
COPY --from=devnet-deploy /usr/share/cartesi/localhost.json .

ENTRYPOINT ["/entrypoint.sh"]
CMD ["anvil", "--load-state", "/usr/share/cartesi/state.json"]
