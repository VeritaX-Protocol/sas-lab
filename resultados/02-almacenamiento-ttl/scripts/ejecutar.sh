#!/usr/bin/env bash
# Ejercicio 02: TTL y almacenamiento.
# Nota: cada árbol (base y rama) usa su propio CARGO_TARGET_DIR; compartirlo mezcla los dos crates 'protocol'. Solo testnet. No imprime claves secretas.
# Uso: scripts/ejecutar.sh [ttl-base|unitarias|rama|extender|instancia|informe ...]   (sin argumentos = todo)
set -uo pipefail
export PATH="$HOME/.cargo/bin:$PATH"
AQUI="$(cd "$(dirname "$0")/.." && pwd)"; cd "$AQUI"
mkdir -p logs
N="--network testnet"
T02="${SAS_TARGET_02:-$HOME/.cache/sas-lab/t02}"
BASE=attestprotocol/contracts/stellar
RAMA=attestprotocol-rama/contracts/stellar

verde() { printf '\033[32m%s\033[0m\n' "$*"; }
rojo()  { printf '\033[31m%s\033[0m\n' "$*"; }
paso()  { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }

fee_de() { # fee_de HASH -> "fee_stroops ledger" desde Horizon
  curl -s -A sas-lab/1.0 "https://horizon-testnet.stellar.org/transactions/$1" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['fee_charged'],d['ledger'])"
}
hash_de() { grep -o 'tx/[0-9a-f]\{64\}' "$1" | tail -1 | cut -c4-; }

# inv NOMBRE FUENTE CONTRATO fn args...  -> logs/NOMBRE.{out,err}; guarda FEE_<nombre> en logs/costos.txt
inv() {
  local nombre=$1 fuente=$2 id=$3; shift 3
  stellar contract invoke --id "$id" --source-account "$fuente" $N -- "$@" >"logs/$nombre.out" 2>"logs/$nombre.err"
  local rc=$? h f; h=$(hash_de "logs/$nombre.err")
  if [ $rc -eq 0 ] && [ -n "$h" ]; then f=$(fee_de "$h"); echo "$nombre $f $h" >>logs/costos.txt; echo "$nombre: OK fee,ledger=$f"
  elif [ $rc -eq 0 ]; then echo "$nombre: OK (solo lectura)"
  else echo "$nombre: ERROR $(grep -o 'Error(Contract, #[0-9]*)' "logs/$nombre.err" | head -1)"; fi
  LAST_OUT=$(tr -d '"\n' <"logs/$nombre.out")
}

p_ttl-base() {
  paso "1. TTL reales del despliegue del ejercicio 01 (solo lectura)"
  . ./datos-entrada.env
  python3 scripts/ttl.py "$PROTOCOLO" "$WASM_SHA256" "$S_SIN" "$ATT1" "$EMISOR_A" logs/ttl-inicial.json | tee logs/ttl-inicial.md
}

p_unitarias() {
  paso "2. Pruebas unitarias (Rust) en la base y en la rama con extend_ttl"
  cp pruebas/lab_ttl_base.rs "$BASE/protocol/tests/"; cp pruebas/lab_ttl_base.rs pruebas/lab_ttl_rama.rs "$RAMA/protocol/tests/"
  ( cd "$BASE" && CARGO_TARGET_DIR="$T02/base" cargo test -p protocol --test lab_ttl_base -- --nocapture --test-threads=1 ) >logs/unitarias-base.log 2>&1
  ( cd "$RAMA" && CARGO_TARGET_DIR="$T02/rama" cargo test -p protocol --test lab_ttl_base --test lab_ttl_rama -- --nocapture --test-threads=1 ) >logs/unitarias-rama.log 2>&1
  for f in base rama; do echo "$f: $(grep -E '^test result' logs/unitarias-$f.log | awk '{p+=$4; q+=$6} END {print p" pasan, "q" fallan"}')"; done
  ( cd "$RAMA" && CARGO_TARGET_DIR="$T02/rama" cargo test --workspace --no-fail-fast ) >logs/pruebas-rama-completas.log 2>&1
  python3 - <<'EOF'
import re
t=open("logs/pruebas-rama-completas.log").read()
s=lambda k: sum(int(x) for x in re.findall(rf"(\d+) {k}",t))
print("rama, toda la suite: pasan",s("passed"),"fallan",s("failed"),"ignoradas",s("ignored"))
EOF
}

p_rama() {
  paso "3. Desplegar la RAMA (extend_ttl) en testnet y medir TTL y comisión reales"
  stellar contract deploy --wasm wasm/protocol-rama.wasm --source-account admin $N --alias sas02_rama >logs/30-deploy-rama.out 2>logs/30-deploy-rama.err || { rojo "falló el despliegue"; return 1; }
  RAMA_ID=$(cat logs/30-deploy-rama.out); echo "RAMA_ID=$RAMA_ID" >datos-rama.env
  ADMIN=$(stellar keys address admin); A=$(stellar keys address emisorA)
  inv 31-init           admin   "$RAMA_ID" initialize --admin "$ADMIN"
  inv 32-registrar      emisorA "$RAMA_ID" register --caller "$A" --schema_definition 'curso:string,asistio:bool' --revocable true; S=$LAST_OUT
  inv 33-emitir         emisorA "$RAMA_ID" attest --attester "$A" --schema_uid "$S" --value '{"tipo":"asistencia","curso":"Demo"}'; ATT=$LAST_OUT
  echo "S_RAMA=$S"  >>datos-rama.env; echo "ATT_RAMA=$ATT" >>datos-rama.env
  W=$(sha256sum wasm/protocol-rama.wasm | cut -d' ' -f1); echo "WASM_RAMA=$W" >>datos-rama.env
  python3 scripts/ttl.py "$RAMA_ID" "$W" "$S" "$ATT" "$A" logs/ttl-rama-tras-emitir.json | tee logs/ttl-rama-tras-emitir.md
  # Emisión equivalente en la BASE (ejercicio 01) el mismo día, para comparar la comisión
  . ./datos-entrada.env
  inv 34-emitir-base    emisorA "$PROTOCOLO" attest --attester "$A" --schema_uid "$S_SIN" --value '{"tipo":"asistencia","curso":"Demo"}'; ATT_B=$LAST_OUT
  echo "ATT_BASE_HOY=$ATT_B" >>datos-rama.env
  # Renovar sin necesidad (TTL ya alto) por un tercero (emisorB): ¿cuánto cuesta?
  inv 35-renovar-sin-necesidad emisorB "$RAMA_ID" extend_attestation_ttl --attestation_uid "$ATT"
  inv 36-renovar-uid-falso     emisorB "$RAMA_ID" extend_attestation_ttl --attestation_uid 0000000000000000000000000000000000000000000000000000000000000000
}

clave_att() { # clave_att UID -> XDR base64 de la clave AttestationUID(uid) (ScVal)
  printf '{"vec":[{"symbol":"AttestationUID"},{"bytes":"%s"}]}' "$1" | stellar xdr encode --type ScVal --input json --output single-base64
}

p_extender() {
  paso "4. Renovar desde fuera con 'stellar contract extend' (cualquier cuenta paga)"
  . ./datos-entrada.env; . ./datos-rama.env 2>/dev/null
  local K; K=$(clave_att "$ATT_MS")
  python3 scripts/ttl.py "$PROTOCOLO" "$WASM_SHA256" "$S_SIN" "$ATT_MS" "$EMISOR_A" logs/ttl-antes-extender.json >/dev/null
  # emisorB (que no emitió) paga la renta
  stellar contract extend --id "$PROTOCOLO" --durability persistent --key-xdr "$K" --ledgers-to-extend 500000 --source-account emisorB $N >logs/40-extend.out 2>logs/40-extend.err
  echo "extend rc=$? salida: $(tr -d '\n' <logs/40-extend.out | cut -c1-80)"
  local h; h=$(hash_de logs/40-extend.err); [ -n "$h" ] && { echo "40-extend $(fee_de "$h") $h" >>logs/costos.txt; echo "fee,ledger=$(fee_de "$h")"; }
  python3 scripts/ttl.py "$PROTOCOLO" "$WASM_SHA256" "$S_SIN" "$ATT_MS" "$EMISOR_A" logs/ttl-despues-extender.json | tee logs/ttl-despues-extender.md
}

p_instancia() {
  paso "5. Techo de instance: schemas de ~2 KB hasta fallar (contrato base NUEVO)"
  stellar contract deploy --wasm wasm/protocol-base.wasm --source-account admin $N --alias sas02_instancia >logs/50-deploy.out 2>logs/50-deploy.err || { rojo "falló"; return 1; }
  local I; I=$(cat logs/50-deploy.out); echo "INSTANCIA_ID=$I" >datos-instancia.env
  local ADMIN A; ADMIN=$(stellar keys address admin); A=$(stellar keys address emisorA)
  stellar contract invoke --id "$I" --source-account admin $N -- initialize --admin "$ADMIN" >/dev/null 2>&1
  : >logs/instancia.txt
  local n=0 def relleno; relleno=$(head -c 1990 /dev/zero | tr '\0' 'x')
  while [ $n -lt 60 ]; do
    n=$((n+1)); def="curso$(printf '%03d' $n):$relleno"
    stellar contract invoke --id "$I" --source-account emisorA $N -- register --caller "$A" --schema_definition "$def" --revocable true >logs/51-reg.out 2>logs/51-reg.err
    if [ $? -ne 0 ]; then echo "FALLA en el schema $n: $(grep -m1 -E 'error|Error' logs/51-reg.err | cut -c1-220)" | tee -a logs/instancia.txt; cp logs/51-reg.err logs/instancia-fallo.err; break; fi
    h=$(hash_de logs/51-reg.err); echo "$n ok $(fee_de "$h")" >>logs/instancia.txt
    [ $((n % 10)) -eq 0 ] && echo "  $n schemas registrados"
  done
  echo "schemas registrados con éxito: $((n - ( $(grep -c FALLA logs/instancia.txt) )))"
  python3 - "$I" <<'EOF'
import base64, json, subprocess, sys, urllib.request
c = sys.argv[1]
k = subprocess.run(["stellar","xdr","encode","--type","LedgerKey","--input","json","--output","single-base64"], input=json.dumps({"contract_data":{"contract":c,"key":{"ledger_key_contract_instance":None},"durability":"persistent"}}), capture_output=True, text=True).stdout.strip()
req = {"jsonrpc":"2.0","id":1,"method":"getLedgerEntries","params":{"keys":[k]}}
r = json.load(urllib.request.urlopen(urllib.request.Request("https://soroban-testnet.stellar.org", json.dumps(req).encode(), {"content-type":"application/json","user-agent":"sas-lab/1.0"}), timeout=30))["result"]["entries"][0]
print("tamaño de la entrada de instancia (XDR del valor):", len(base64.b64decode(r["xdr"])), "bytes")
EOF
  # ¿Se puede emitir aún con la instancia al límite?
  local S2; S2=$(stellar contract invoke --id "$I" --source-account emisorA $N -- register --caller "$A" --schema_definition 'corto:string' --revocable true 2>logs/52-corto.err | tr -d '"'); echo "registrar un schema corto con la instancia llena: ${S2:-ERROR $(grep -o 'Error(Contract, #[0-9]*)' logs/52-corto.err | head -1)}"
}

p_informe() {
  paso "6. Informe"
  python3 scripts/informe.py "$AQUI" | tee informe.md
}

if [ $# -eq 0 ]; then set -- ttl-base unitarias rama extender instancia informe; fi
for s in "$@"; do
  case "$s" in ttl-base|unitarias|rama|extender|instancia|informe) "p_$s" ;; *) rojo "paso desconocido: $s"; exit 2 ;; esac
done
