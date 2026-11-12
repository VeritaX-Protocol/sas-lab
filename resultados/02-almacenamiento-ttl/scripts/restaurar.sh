#!/usr/bin/env bash
# Ejercicio 02, tarea de restauración REAL. Ejecutar DESPUÉS de 2026-11-18 20:50 UTC.
# El contrato del ejercicio 01 (sin extend_ttl) archiva su Wasm, su instancia y ATT1 en ese momento
# (ledgers 5.802.176 / 5.802.229 / 5.802.245). Este script comprueba el archivo y mide qué cuesta restaurar.
# Uso: scripts/restaurar.sh      (solo testnet; no imprime claves secretas)
set -uo pipefail
export PATH="$HOME/.cargo/bin:$PATH"
AQUI="$(cd "$(dirname "$0")/.." && pwd)"; cd "$AQUI"; mkdir -p logs
N="--network testnet"
. ./datos-entrada.env
A=$(stellar keys address emisorA)

ahora=$(curl -s -X POST https://soroban-testnet.stellar.org -H 'content-type: application/json' -H 'user-agent: sas-lab/1.0' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getLatestLedger"}' | python3 -c "import sys,json;print(json.load(sys.stdin)['result']['sequence'])")
echo "Ledger actual: $ahora"
[ "$ahora" -gt 5802246 ] || { echo "Todavía no vencen (vencen en el ledger 5802246). Vuelve después de 2026-11-18 20:50 UTC."; exit 1; }

fee_de() { curl -s -A sas-lab/1.0 "https://horizon-testnet.stellar.org/transactions/$1" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['fee_charged'],d['ledger'])"; }
hash_de() { grep -o 'tx/[0-9a-f]\{64\}' "$1" | tail -1 | cut -c4-; }

echo; echo "== 1. ¿Están archivadas? (getLedgerEntries no devuelve las archivadas)"
python3 scripts/ttl.py "$PROTOCOLO" "$WASM_SHA256" "$S_SIN" "$ATT1" "$EMISOR_A" logs/ttl-tras-vencer.json | tee logs/ttl-tras-vencer.md

echo; echo "== 2. Leer la attestation sin restaurar nada (el CLI debería añadir la restauración solo)"
stellar contract invoke --id "$PROTOCOLO" --source-account emisorA $N -- get_attestation --attestation_uid "$ATT1" >logs/60-get-tras-vencer.out 2>logs/60-get-tras-vencer.err
echo "rc=$?  $(tr -d '\n' <logs/60-get-tras-vencer.out | cut -c1-100)"
grep -i -E "restor|archiv|expired" logs/60-get-tras-vencer.err | head -5 | cut -c1-200
h=$(hash_de logs/60-get-tras-vencer.err); [ -n "$h" ] && echo "tx con restauración automática: $(fee_de "$h") (fee_stroops ledger)  https://stellar.expert/explorer/testnet/tx/$h"

echo; echo "== 3. Restauración MANUAL (RestoreFootprintOp) de una entrada, si sigue archivada"
K=$(printf '{"vec":[{"symbol":"AttesterNonce"},{"address":"%s"}]}' "$EMISOR_A" | stellar xdr encode --type ScVal --input json --output single-base64)
stellar contract restore --id "$PROTOCOLO" --durability persistent --key-xdr "$K" --source-account emisorA $N >logs/61-restore.out 2>logs/61-restore.err
echo "rc=$?  $(tr -d '\n' <logs/61-restore.out | cut -c1-100)"
h=$(hash_de logs/61-restore.err); [ -n "$h" ] && echo "tx de restauración manual: $(fee_de "$h") (fee_stroops ledger)  https://stellar.expert/explorer/testnet/tx/$h"

echo; echo "== 4. TTL tras restaurar"
python3 scripts/ttl.py "$PROTOCOLO" "$WASM_SHA256" "$S_SIN" "$ATT1" "$EMISOR_A" logs/ttl-tras-restaurar.json | tee logs/ttl-tras-restaurar.md
echo; echo "Anota en NOTA.md: ¿restauró solo el CLI? ¿cuánto costó cada camino? ¿qué TTL queda tras restaurar?"
