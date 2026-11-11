#!/usr/bin/env bash
# Ejercicio 00: ejecuta los pasos medibles y genera informe.md.
# Uso: scripts/ejecutar.sh [paso ...]   (sin argumentos = todos)
# Pasos: versiones clon pruebas wasm red identidades auditoria sdk29 informe
set -uo pipefail
export PATH="$HOME/.cargo/bin:$PATH"

AQUI="$(cd "$(dirname "$0")/.." && pwd)"   # resultados/00-toolchain
CLON="$AQUI/attestprotocol"
CONTRATO="$CLON/contracts/stellar"
COMMIT=c0c4529
COMMIT_AUDITADO=287e2ed                    # commit que escaneó Almanax
T29="${SAS_TARGET_SDK29:-$HOME/.cache/sas-lab/t29}"
cd "$AQUI"

verde() { printf '\033[32m%s\033[0m\n' "$*"; }
rojo()  { printf '\033[31m%s\033[0m\n' "$*"; }
paso()  { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }

p_versiones() {
  paso "1. Versiones"
  { rustc -V; cargo -V; rustup target list --installed; stellar --version | head -1; node -v; git --version; } | tee versiones.txt
  rustup target list --installed | grep -qx wasm32v1-none && verde "OK target wasm32v1-none" || rojo "FALTA target wasm32v1-none (no instalar: preguntar)"
}

p_clon() {
  paso "2. Clon fijado en $COMMIT"
  [ -d "$CLON" ] || git clone -q https://github.com/daccred/attestprotocol "$CLON"
  git -C "$CLON" checkout -q "$COMMIT" && verde "OK $(git -C "$CLON" log -1 --format='%h %ci')"
}

p_pruebas() {
  paso "3. Pruebas del contrato (soroban-sdk 27.0.6) - tarda ~3 min la primera vez"
  ( cd "$CONTRATO" && cargo test --workspace --no-fail-fast ) >test-heredado.log 2>&1
  echo "salida de cargo: $? (un fallo es un hallazgo, no un error del ejercicio)"
  grep -E "^test result" test-heredado.log | awk '{p+=$4; f+=$6; i+=$8} END {printf "pasan=%d fallan=%d ignoradas=%d\n", p, f, i}'
}

p_wasm() {
  paso "4. Compilar a Wasm (make build = stellar contract build)"
  ( cd "$CONTRATO/protocol" && make build ) >build-protocol.log 2>&1 && verde "OK protocol" || rojo "FALLÓ protocol (ver build-protocol.log)"
  ( cd "$CONTRATO/resolvers" && make build ) >build-resolvers.log 2>&1 && verde "OK resolvers" || rojo "FALLÓ resolvers (ver build-resolvers.log)"
  ls -l "$CONTRATO"/target/wasm32v1-none/release/*.wasm 2>/dev/null | awk '{print $5, $9}'
}

p_grep() {
  for k in 'extend_ttl' 'instance()' 'persistent()' 'temporary()' 'mock_all_auths' 'mock_auths' 'update_current_contract_wasm' '__constructor'; do
    echo "== $k"; ( cd "$CONTRATO" && grep -rnF "$k" protocol/src resolvers/src --include=*.rs )
    echo "  (tests: $( cd "$CONTRATO" && grep -rlF "$k" protocol/tests resolvers/tests --include=*.rs | wc -l ) archivos)"
  done >grep.txt
}

p_red() {
  paso "5. Grep de línea base y red"
  p_grep && echo "OK grep.txt"
  stellar network settings --network testnet --output json-formatted >ajustes-testnet.json 2>ajustes-testnet.err && verde "OK ajustes-testnet.json" || rojo "FALLÓ settings (ver ajustes-testnet.err)"
  rpc() { curl -s -X POST https://soroban-testnet.stellar.org -H 'content-type: application/json' -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"$1\"}"; }
  rpc getVersionInfo >version-testnet.json
  rpc getLatestLedger >ledger-testnet.json
  curl -s https://horizon.stellar.org/ >version-mainnet.json
  verde "OK versión y ledger de testnet y mainnet"
}

p_identidades() {
  paso "6. Identidades de prueba (solo claves públicas)"
  for a in admin emisorA emisorB; do
    stellar keys ls 2>/dev/null | grep -qx "$a" && echo "$a ya existe, no se toca" \
      || stellar keys generate "$a" --network testnet --fund 2>&1 | tail -1
  done
  for a in admin emisorA emisorB; do echo "$a $(stellar keys address "$a")"; done | tee identidades-publicas.txt
}

p_auditoria() {
  paso "7. Cambios desde el commit que escaneó Almanax ($COMMIT_AUDITADO)"
  local rutas="contracts/stellar/protocol/src contracts/stellar/resolvers/src"
  # shellcheck disable=SC2086
  { echo "commits: $(git -C "$CLON" rev-list --count $COMMIT_AUDITADO..$COMMIT -- $rutas)"
    git -C "$CLON" diff --shortstat $COMMIT_AUDITADO $COMMIT -- $rutas
    echo "despliegue mainnet v2: $(git -C "$CLON" log -1 --format='%h %ci' --grep='current mainnet deployment' -- contracts/stellar/deployments.json)"
  } | tee auditoria.txt
}

p_sdk29() {
  paso "8. Micro-prueba con soroban-sdk 29.0.1 (en un worktree aparte; el clon no se toca)"
  local wt; wt="$(mktemp -d)/wt"
  git -C "$CLON" worktree add -q --detach "$wt" "$COMMIT" || return
  sed -i 's/soroban-sdk = { version = "27.0.6" }/soroban-sdk = { version = "29.0.1" }/' "$wt/contracts/stellar/Cargo.toml"
  mkdir -p "$T29"
  ( cd "$wt/contracts/stellar" && CARGO_TARGET_DIR="$T29" cargo test --workspace --no-fail-fast ) >sdk29-test.log 2>&1
  grep -E "^test result" sdk29-test.log | awk '{p+=$4; f+=$6; i+=$8} END {printf "pasan=%d fallan=%d ignoradas=%d\n", p, f, i}'
  git -C "$CLON" worktree remove --force "$wt"
  git -C "$CLON" status --short | head -3
  verde "OK worktree eliminado; clon limpio en $(git -C "$CLON" log -1 --format=%h)"
}

p_informe() {
  paso "9. Informe"
  python3 "$AQUI/scripts/informe.py" "$AQUI" | tee informe.md
}

if [ $# -eq 0 ]; then set -- versiones clon pruebas wasm red identidades auditoria sdk29 informe; fi
for s in "$@"; do
  case "$s" in
    versiones|clon|pruebas|wasm|red|identidades|auditoria|sdk29|informe) "p_$s" ;;
    *) rojo "paso desconocido: $s"; exit 2 ;;
  esac
done
