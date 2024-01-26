# Run Node Locally without Docker

## Dependencies

### Build

Build 

```shell
make docker-build-deps
```

### Install Cartesi Machine

Follow [The Cartesi Machine repo](https://github.com/cartesi/machine-emulator) install instructions.
If an error happens when using the available Debian package to install the Cartesi Machine, running 
`apt-get install --fix-broken` can be usefull

### Install Server Manager

Follow [The Server Manager repo](https://github.com/cartesi/server-manager) install instructions

### Install Redis

Follow Redis install instructions

### Save Machine Snapshot

```shell
go run ./cmd/cartesi-rollups-cli/ save-snapshot
```

## Build node 

```shell
cd ./offchain/
cargo build
```

## Setup Environment

```shell
source ./setup_env.sh
```

## Run

Start Server Manager

```
server-manager --manager-address=0.0.0.0:5001
```

Start Dependencies

```
go run ./cmd/cartesi-rollups-cli/ run-deps
```


Run Node 

```
go run ./cmd/cartesi-rollups-node/ 
```