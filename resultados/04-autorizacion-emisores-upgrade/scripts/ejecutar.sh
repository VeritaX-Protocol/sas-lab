#!/usr/bin/env bash
# Ejercicio 04: autorización, lista de emisores y upgrade. Solo testnet. No imprime claves secretas.
# Uso: scripts/ejecutar.sh [pruebas|wasm|testnet|informe ...]   (sin argumentos = todo)
#   testnet despliega un contrato nuevo (v1), emite, retira, actualiza a v2 y revoca: unas 20 transacciones y ≈ 40 XLM de testnet
#   (el primer `register` de la rama paga la renta de 180 días de Wasm e instancia, ver ejercicio 02).
set -uo pipefail
export PATH="$HOME/.cargo/bin:$PATH"
AQUI="$(cd "$(dirname "$0")/.." && pwd)"; cd "$AQUI"; mkdir -p logs wasm
N="--network testnet"
CLON=attestprotocol-emisores/contracts/stellar
T04="${SAS_TARGET_04:-$HOME/.cache/sas-lab/t04}"
paso() { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
fee_de() { curl -s -A sas-lab/1.0 "https://horizon-testnet.stellar.org/transactions/$1" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['fee_charged'],d['ledger'])"; }
hash_de() { grep -o 'tx/[0-9a-f]\{64\}' "$1" | tail -1 | cut -c4-; }

# inv NOMBRE FUENTE CONTRATO fn args...  -> logs/NOMBRE.{out,err}; costos en logs/costos.txt; resultado en LAST_OUT
inv() {
  local nombre=$1 fuente=$2 id=$3; shift 3
  stellar contract invoke --id "$id" --source-account "$fuente" $N -- "$@" >"logs/$nombre.out" 2>"logs/$nombre.err"
  local rc=$? h f; h=$(hash_de "logs/$nombre.err")
  if [ $rc -eq 0 ] && [ -n "$h" ]; then f=$(fee_de "$h"); echo "$nombre $f $h" >>logs/costos.txt; echo "$nombre: OK fee,ledger=$f"
  elif [ $rc -eq 0 ]; then echo "$nombre: OK (solo lectura) $(tr -d '\n' <"logs/$nombre.out" | cut -c1-80)"
  else echo "$nombre: ERROR $(grep -o 'Error([A-Za-z]*, #\?[A-Za-z0-9]*)' "logs/$nombre.err" | head -1) $(grep -m1 -i 'error' "logs/$nombre.err" | cut -c1-110)"; fi
  LAST_OUT=$(tr -d '"\n' <"logs/$nombre.out")
}

p_pruebas() {
  paso "1. Pruebas Rust (mock_auths) en v1, en v2 y suite completa"
  cp pruebas/lab_emisores.rs "$CLON/protocol/tests/"
  ( cd "$CLON" && CARGO_TARGET_DIR="$T04" cargo test -p protocol --test lab_emisores -- --nocapture --test-threads=1 ) >logs/pruebas-v1.log 2>&1
  ( cd "$CLON" && CARGO_TARGET_DIR="$T04" cargo test -p protocol --features v2 --test lab_emisores -- --nocapture --test-threads=1 ) >logs/pruebas-v2.log 2>&1
  for v in v1 v2; do echo "$v: $(grep -E '^test result' logs/pruebas-$v.log | tail -1)"; done
  ( cd "$CLON" && CARGO_TARGET_DIR="$T04" cargo test --workspace --no-fail-fast ) >logs/suite-completa-v1.log 2>&1
  ( cd "$CLON" && CARGO_TARGET_DIR="$T04" cargo test --workspace --no-fail-fast --features protocol/v2 ) >logs/suite-completa-v2.log 2>&1
  for v in v1 v2; do python3 -c "
import re,sys
t=open('logs/suite-completa-$v.log').read()
s=lambda k: sum(int(x) for x in re.findall(r'(\d+) '+k,t))
print('suite $v: pasan',s('passed'),'fallan',s('failed'))"; done
}

p_wasm() {
  paso "2. Compilar v1, v2 y el resolver de emisores (stellar contract build)"
  ( cd "$CLON" && export CARGO_TARGET_DIR="${SAS_TARGET_04W:-$HOME/.cache/sas-lab/t04w}"
    stellar contract build --package protocol --out-dir "$AQUI/wasm/v1" && cp "$AQUI/wasm/v1/protocol.wasm" "$AQUI/wasm/protocol-v1.wasm"
    stellar contract build --package protocol --features v2 --out-dir "$AQUI/wasm/v2" && cp "$AQUI/wasm/v2/protocol.wasm" "$AQUI/wasm/protocol-v2.wasm"
    stellar contract build --package resolvers --features export-issuer-resolver --out-dir "$AQUI/wasm/res" && cp "$AQUI/wasm/res/resolvers.wasm" "$AQUI/wasm/resolver-emisores.wasm" ) >logs/build.log 2>&1
  rm -rf wasm/v1 wasm/v2 wasm/res; ( cd wasm && sha256sum *.wasm | tee SHA256.txt; ls -l *.wasm | awk '{print $5, $9}' )
}

p_testnet() {
  paso "3. Testnet: v1 con lista de emisores, retirar, upgrade a v2 por admin, v2 lee lo de v1"
  : >logs/costos.txt
  ADMIN=$(stellar keys address admin); A=$(stellar keys address emisorA); B=$(stellar keys address emisorB)
  stellar contract deploy --wasm wasm/protocol-v1.wasm --source-account admin $N --alias sas04 >logs/30-deploy-v1.out 2>logs/30-deploy-v1.err || { echo "falló el despliegue"; return 1; }
  ID=$(cat logs/30-deploy-v1.out); echo "ID=$ID" >datos-04.env; echo "contrato v1: $ID"
  inv 31-init            admin   "$ID" initialize --admin "$ADMIN"
  inv 32-registrar       admin   "$ID" register --caller "$ADMIN" --schema_definition 'curso:string,asistio:bool' --revocable true; S=$LAST_OUT
  echo "S=$S" >>datos-04.env
  echo "-- emisorB emite en un schema SIN lista (comportamiento heredado)"
  inv 33-b-sin-lista     emisorB "$ID" attest --attester "$B" --schema_uid "$S" --value '{"t":"sin-lista"}'
  echo "-- el admin añade a emisorA; emisorB intenta añadirse solo"
  inv 34-b-se-autoañade  emisorB "$ID" add_issuer --caller "$B" --schema_uid "$S" --issuer "$B"
  inv 35-admin-añade-a   admin   "$ID" add_issuer --caller "$ADMIN" --schema_uid "$S" --issuer "$A"
  inv 36-a-emite         emisorA "$ID" attest --attester "$A" --schema_uid "$S" --value '{"t":"emisorA-activo"}'; ATT1=$LAST_OUT; echo "ATT1=$ATT1" >>datos-04.env
  inv 37-b-rechazado     emisorB "$ID" attest --attester "$B" --schema_uid "$S" --value '{"t":"emisorB"}'
  echo "-- retirar a emisorA: ya no emite, pero lo anterior sigue"
  inv 38-retira-a        admin   "$ID" retire_issuer --caller "$ADMIN" --schema_uid "$S" --issuer "$A"
  inv 39-a-retirado      emisorA "$ID" attest --attester "$A" --schema_uid "$S" --value '{"t":"tras-retiro"}'
  inv 40-lee-anterior    emisorA "$ID" get_attestation --attestation_uid "$ATT1"
  inv 41-estado-a        emisorA "$ID" issuer_status --schema_uid "$S" --issuer "$A"
  inv 42-reactiva-a      admin   "$ID" add_issuer --caller "$ADMIN" --schema_uid "$S" --issuer "$A"
  inv 43-lista           emisorA "$ID" list_issuers --schema_uid "$S"
  inv 44-version-v1      emisorA "$ID" version
  echo "-- instalar v2 y probar quién puede disparar el upgrade"
  H2=$(stellar contract upload --wasm wasm/protocol-v2.wasm --source-account admin $N 2>logs/50-upload-v2.err | tail -1); echo "H2=$H2" >>datos-04.env; echo "hash Wasm v2: $H2"
  H1=$(sha256sum wasm/protocol-v1.wasm | cut -d' ' -f1); echo "H1=$H1" >>datos-04.env
  inv 51-upgrade-por-b   emisorB "$ID" upgrade --new_wasm_hash "$H2"
  inv 52-version-sigue-1 emisorA "$ID" version
  inv 53-upgrade-admin   admin   "$ID" upgrade --new_wasm_hash "$H2"
  inv 54-version-v2      emisorA "$ID" version
  echo "-- v2 lee lo de v1, conserva la lista y no renumera errores"
  inv 55-v2-lee-att1     emisorA "$ID" get_attestation --attestation_uid "$ATT1"
  inv 56-v2-estado-b     emisorA "$ID" issuer_status --schema_uid "$S" --issuer "$B"
  inv 57-v2-b-rechazado  emisorB "$ID" attest --attester "$B" --schema_uid "$S" --value '{"t":"v2-b"}'
  inv 58-v2-a-emite      emisorA "$ID" attest --attester "$A" --schema_uid "$S" --value '{"t":"v2-a"}'; ATT2=$LAST_OUT; echo "ATT2=$ATT2" >>datos-04.env
  echo "-- quién puede revocar en v2"
  inv 59-b-revoca        emisorB "$ID" revoke --revoker "$B" --attestation_uid "$ATT1"
  inv 60-admin-revoca    admin   "$ID" revoke --revoker "$ADMIN" --attestation_uid "$ATT1"
  inv 61-lee-revocada    emisorA "$ID" get_attestation --attestation_uid "$ATT1"
  inv 62-a-revoca-la-suya emisorA "$ID" revoke --revoker "$A" --attestation_uid "$ATT2"
}

p_informe() { paso "4. informe.md"; python3 scripts/informe.py . >informe.md && echo "listo: informe.md"; }
[ $# -eq 0 ] && set -- pruebas wasm testnet informe
for p in "$@"; do "p_$p"; done
