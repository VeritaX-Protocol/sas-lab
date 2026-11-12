#!/usr/bin/env bash
# Ejercicio 01: ciclo completo en testnet y evidencia.md.
# Uso: scripts/ejecutar.sh [desplegar|ciclo|eventos|informe ...]   (sin argumentos = todo)
# Solo testnet. No imprime claves secretas.
set -uo pipefail
export PATH="$HOME/.cargo/bin:$PATH"
AQUI="$(cd "$(dirname "$0")/.." && pwd)"; cd "$AQUI"
mkdir -p logs
N="--network testnet"

verde() { printf '\033[32m%s\033[0m\n' "$*"; }
rojo()  { printf '\033[31m%s\033[0m\n' "$*"; }
paso()  { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }

declare -A ERR=( [3]=SchemaNotFound [5]=AttestationNotFound [6]=NotAuthorized [10]=ResolverError [13]=AlreadyInitialized
  [15]=AttestationNotRevocable [16]=InvalidSchemaDefinition [17]=InvalidAttestationValue [22]=AttestationExpired
  [23]=InvalidDeadline [24]=ResolverCallFailed [28]=SchemaAlreadyExists [29]=AlreadyRevoked )

# inv NOMBRE FUENTE CONTRATO fn --arg valor ...   -> logs/NOMBRE.{out,err} y una fila en evidencia.md
inv() {
  local nombre=$1 fuente=$2 id=$3; shift 3
  stellar contract invoke --id "$id" --source-account "$fuente" $N -- "$@" >"logs/$nombre.out" 2>"logs/$nombre.err"
  local rc=$? hash cod estado
  hash=$(grep -o 'tx/[0-9a-f]\{64\}' "logs/$nombre.err" | tail -1 | cut -c4-)
  cod=$(grep -o 'Error(Contract, #[0-9]*)' "logs/$nombre.err" | head -1 | grep -o '[0-9]*')
  if [ $rc -eq 0 ]; then estado="OK"; else estado="ERROR #${cod:-?} ${ERR[${cod:-0}]:-}"; fi
  printf '| %s | %s | `%s` | %s |\n' "$nombre" "$estado" "$(tr -d '\n' <"logs/$nombre.out" | cut -c1-66)" \
    "${hash:+[tx](https://stellar.expert/explorer/testnet/tx/$hash)}" >>evidencia.md
  echo "$nombre: $estado ${hash:+(tx ${hash:0:10}…)}"
  LAST_OUT=$(tr -d '"\n' <"logs/$nombre.out")
}

cargar() { # shellcheck disable=SC1091
  . ./datos.env; EMISOR_B=$(stellar keys address emisorB); }

p_desplegar() {
  paso "1. Desplegar protocolo y resolver por defecto (admin)"
  mkdir -p wasm
  stellar contract deploy --wasm wasm/protocol.wasm --source-account admin $N --alias sas01_protocol >logs/10-deploy-protocol.out 2>logs/10-deploy-protocol.err || { rojo "falló el despliegue"; return 1; }
  stellar contract deploy --wasm wasm/resolvers-default.wasm --source-account admin $N --alias sas01_resolver >logs/11-deploy-resolver.out 2>logs/11-deploy-resolver.err || { rojo "falló el resolver"; return 1; }
  { echo "PROTOCOLO=$(cat logs/10-deploy-protocol.out)"; echo "RESOLVER=$(cat logs/11-deploy-resolver.out)"
    echo "ADMIN=$(stellar keys address admin)"; echo "EMISOR_A=$(stellar keys address emisorA)"; } >datos.env
  cargar
  verde "protocolo $PROTOCOLO  resolver $RESOLVER"
  stellar contract invoke --id "$PROTOCOLO" --source-account admin $N -- initialize --admin "$ADMIN" >logs/12-init.out 2>logs/12-init.err && verde "initialize OK"
}

p_ciclo() {
  cargar
  local P=$PROTOCOLO R=$RESOLVER A=$EMISOR_A B=$EMISOR_B NOW; NOW=$(date +%s)
  local V='{"tipo":"asistencia","curso":"Demo","sal_hash":"e3b0c44298fc1c149afbf4c8996fb924"}'  # sin datos personales
  curl -s -X POST https://soroban-testnet.stellar.org -H 'content-type: application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"getLatestLedger"}' | python3 -c "import sys,json;print(json.load(sys.stdin)['result']['sequence'])" >logs/ledger-inicio.txt
  { echo "# Evidencia del ejercicio 01 (testnet)"; echo
    echo "Generado: $(date -u '+%F %T UTC')  |  protocolo \`$P\`  |  resolver \`$R\`"; echo
    echo "Despliegue (admin):"; echo
    for f in 10-deploy-protocol 11-deploy-resolver 12-init; do
      h=$(grep -o 'tx/[0-9a-f]\{64\}' "logs/$f.err" 2>/dev/null | tail -1 | cut -c4-); echo "- $f: ${h:+[tx](https://stellar.expert/explorer/testnet/tx/$h)}"; done; echo
    echo "| Operación | Resultado | Salida | Transacción |"; echo "| --- | --- | --- | --- |"; } >evidencia.md

  paso "2. Schemas (caller: emisorA)"
  inv 21-schema-sin-resolver-sintaxis2 emisorA "$P" register --caller "$A" --schema_definition 'curso:string,asistio:bool' --revocable true;            S_SIN=$LAST_OUT
  inv 22-schema-struct-sintaxis1       emisorA "$P" register --caller "$A" --schema_definition 'struct Cert { string curso; bool asistio; }' --revocable true
  inv 23-schema-tipos-sintaxis3        emisorA "$P" register --caller "$A" --schema_definition 'string curso, bool asistio' --revocable true
  inv 24-schema-con-resolver           emisorA "$P" register --caller "$A" --schema_definition 'curso:string,asistio:bool,r:default' --resolver "\"$R\"" --revocable true; S_RES=$LAST_OUT
  inv 25-schema-no-revocable           emisorA "$P" register --caller "$A" --schema_definition 'curso:string,norev:bool' --revocable false;           S_NOREV=$LAST_OUT
  inv 26-schema-duplicado              emisorA "$P" register --caller "$A" --schema_definition 'curso:string,asistio:bool' --revocable true
  inv 27-get-schema                    emisorA "$P" get_schema --schema_uid "$S_SIN"

  paso "3. Emitir (hipótesis: con el resolver por defecto, la emisión directa falla)"
  inv 31-attest-sin-resolver           emisorA "$P" attest --attester "$A" --schema_uid "$S_SIN" --value "$V";                                   ATT1=$LAST_OUT
  inv 32-attest-con-resolver           emisorA "$P" attest --attester "$A" --schema_uid "$S_RES" --value "$V"
  inv 33-exp-segundos-futuro           emisorA "$P" attest --attester "$A" --schema_uid "$S_SIN" --value "$V" --expiration_time $((NOW+31536000))
  inv 34-exp-milisegundos              emisorA "$P" attest --attester "$A" --schema_uid "$S_SIN" --value "$V" --expiration_time $((NOW*1000)); ATT_MS=$LAST_OUT
  inv 35-exp-pasado                    emisorA "$P" attest --attester "$A" --schema_uid "$S_SIN" --value "$V" --expiration_time 1700000000
  inv 36-attest-no-revocable           emisorA "$P" attest --attester "$A" --schema_uid "$S_NOREV" --value "$V";                                 ATT_NR=$LAST_OUT
  inv 37-emisorB-emite-sin-lista       emisorB "$P" attest --attester "$B" --schema_uid "$S_SIN" --value "$V"

  paso "4. Consultar"
  inv 41-get-attestation               emisorA "$P" get_attestation --attestation_uid "$ATT1"
  cp logs/41-get-attestation.out logs/41-get-attestation-antes.json
  inv 42-get-uid-inexistente           emisorA "$P" get_attestation --attestation_uid 0000000000000000000000000000000000000000000000000000000000000000
  inv 43-get-exp-ms                    emisorA "$P" get_attestation --attestation_uid "$ATT_MS"

  paso "5. Revocar"
  inv 51-revoca-emisorB                emisorB "$P" revoke --revoker "$B" --attestation_uid "$ATT1"
  inv 52-revoca-emisorA                emisorA "$P" revoke --revoker "$A" --attestation_uid "$ATT1"
  inv 53-revoca-dos-veces              emisorA "$P" revoke --revoker "$A" --attestation_uid "$ATT1"
  inv 54-revoca-no-revocable           emisorA "$P" revoke --revoker "$A" --attestation_uid "$ATT_NR"
  inv 55-get-tras-revocar              emisorA "$P" get_attestation --attestation_uid "$ATT1"
  {
    echo "S_SIN=$S_SIN"; echo "S_RES=$S_RES"; echo "S_NOREV=$S_NOREV"; echo "ATT1=$ATT1"; echo "ATT_MS=$ATT_MS"; echo "ATT_NR=$ATT_NR"
  } >uids.env
  verde "evidencia.md escrita; UIDs en uids.env"
}

p_eventos() {
  paso "6. Eventos del contrato"
  cargar
  local ini; ini=$(( $(cat logs/ledger-inicio.txt 2>/dev/null || echo 0) - 3000 ))
  stellar events --id "$PROTOCOLO" $N --start-ledger "$ini" --count 200 --output plain >logs/eventos.txt 2>logs/eventos.err
  python3 - <<'PY'
import re,collections
b=re.split(r"^Event ", open("logs/eventos.txt").read(), flags=re.M)[1:]
c=collections.Counter(" / ".join(re.findall(r"StringM\((\w+)\)", x.split("Value:")[0])) for x in b)
for k,v in c.most_common(): print(f"{v:3} {k}")
print("total eventos:", len(b))
PY
}

p_informe() {
  paso "7. Informe"
  python3 "$AQUI/scripts/informe.py" "$AQUI" | tee informe.md
}

if [ $# -eq 0 ]; then set -- ciclo eventos informe; fi
for s in "$@"; do
  case "$s" in desplegar|ciclo|eventos|informe) "p_$s" ;; *) rojo "paso desconocido: $s"; exit 2 ;; esac
done
