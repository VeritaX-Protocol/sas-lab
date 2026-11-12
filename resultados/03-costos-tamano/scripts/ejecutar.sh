#!/usr/bin/env bash
# Ejercicio 03: costos por tamaño. Solo testnet. No imprime claves secretas.
# Requiere el ejercicio 02 (rama desplegada: ../02-almacenamiento-ttl/datos-rama.env) y `npm install` hecho aquí.
# Uso: scripts/ejecutar.sh [sim|enviar|limites|struct|informe ...]   (sin argumentos = todo)
#   enviar y los envíos de límites mandan transacciones REALES (≈ 1 XLM de testnet en total).
set -uo pipefail
export PATH="$HOME/.cargo/bin:$PATH"
AQUI="$(cd "$(dirname "$0")/.." && pwd)"; cd "$AQUI"; mkdir -p logs
RAMA=../02-almacenamiento-ttl/attestprotocol-rama/contracts/stellar
paso() { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
costos() { # reconstruye logs/costos.txt con la comisión real de Horizon
  python3 - <<'PY'
import json, urllib.request
out = []
for f in ("logs/enviar.jsonl", "logs/enviar-limites.jsonl"):
    try: lineas = open(f).read().splitlines()
    except FileNotFoundError: continue
    for l in lineas:
        d = json.loads(l) if l.startswith("{") else {}
        if d.get("estado") == "SUCCESS":
            r = json.load(urllib.request.urlopen(urllib.request.Request(f"https://horizon-testnet.stellar.org/transactions/{d['hash']}", headers={"User-Agent": "sas-lab/1.0"})))
            out.append(f"{d['n']} {r['fee_charged']} {r['ledger']} {d['hash']}")
open("logs/costos.txt", "w").write("\n".join(out) + "\n")
PY
}
p_sim()     { paso "1. Simular attest con value de ~100/300/600/1000 B (3 repeticiones)"; node --import tsx scripts/medir.ts sim | tee logs/sim.jsonl | cut -c1-200; }
p_enviar()  { paso "2. Enviar de verdad 4 tamaños y leer el desglose de renta"; node --import tsx scripts/medir.ts enviar 100,300,600,1000 | tee logs/enviar.jsonl | cut -c1-200; }
p_limites() { paso "3. Límites: simular tamaños grandes y enviar los que importan"
  node --import tsx scripts/medir.ts limites | tee logs/limites.jsonl | cut -c1-200
  node --import tsx scripts/medir.ts enviar 16000,48000,65000,65536,70000,130000 | tee logs/enviar-limites.jsonl | cut -c1-200
  node --import tsx scripts/medir.ts enviar 16050,16100,16150,16200,16300,16340,16360,16400,20000 | tee logs/enviar-bisecta.jsonl | cut -c1-200; }
p_struct()  { paso "4. String JSON frente a struct tipado (pruebas Rust)"
  cp pruebas/lab_struct.rs "$RAMA/protocol/tests/"
  ( cd "$RAMA" && CARGO_TARGET_DIR="${SAS_TARGET_02:-$HOME/.cache/sas-lab/t02}/rama" cargo test -p protocol --test lab_struct -- --nocapture ) >logs/struct.log 2>&1
  grep -E "STRUCT|test result" logs/struct.log; }
p_informe() { paso "5. informe.md"; costos; python3 scripts/informe.py . >informe.md && echo "listo: informe.md"; }
[ $# -eq 0 ] && set -- sim enviar limites struct informe
for p in "$@"; do "p_$p"; done
