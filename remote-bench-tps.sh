#!/usr/bin/env bash
set -ex
exec > solana/client.log
exec 2>&1

cd "$(dirname "$0")"

PATH=$PATH:.cargo/bin/

host=$1
if [[ -z $host ]]; then
  host=tds.solana.com
fi

txCount=$2

scp -o "ConnectTimeout=20" -o "BatchMode=yes" \
  -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" \
  solana@$host:solana/config/mint-keypair.json .

solana -u http://$host:8899 -k mint-keypair.json balance --lamports

if [[ ! -f bench-tps.json ]]; then
  solana-keygen new -o bench-tps.json
fi

solana -u http://$host:8899 -k mint-keypair.json \
  pay "$(solana-keygen pubkey bench-tps.json)" 1000 SOL
solana -u http://$host:8899 -k bench-tps.json balance

export RUST_LOG=solana=info
solana-bench-tps -i bench-tps.json --tx_count=$txCount --write-client-keys client-accounts.yml
solana-bench-tps -i bench-tps.json --tx_count=$txCount --read-client-keys client-accounts.yml \
  -n $host:8001 -N 2 --sustained --thread-batch-sleep-ms=1000
