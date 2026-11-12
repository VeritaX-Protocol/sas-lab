#!/usr/bin/env python3
"""Lee el TTL real (liveUntilLedgerSeq) de las entradas de un contrato Attest Protocol en testnet.
Uso: ttl.py CONTRATO WASM_SHA256 SCHEMA_UID ATTESTATION_UID G_ATTESTER [NOMBRE_SALIDA.json]
Solo lectura (RPC getLedgerEntries). Convierte ledgers a días con el cierre objetivo (5 s)."""
import base64, json, subprocess, sys, urllib.request

RPC = "https://soroban-testnet.stellar.org"
CIERRE_S = 5  # ledger_target_close_time_milliseconds de testnet (ejercicio 00)
contrato, wasm, schema, att, attester = sys.argv[1:6]
salida = sys.argv[6] if len(sys.argv) > 6 else None


def xdr_key(obj):
    r = subprocess.run(["stellar", "xdr", "encode", "--type", "LedgerKey", "--input", "json", "--output", "single-base64"],
                       input=json.dumps(obj), capture_output=True, text=True)
    if r.returncode:
        raise SystemExit("xdr encode falló: " + r.stderr[:300])
    return r.stdout.strip()


def dato(clave, dur="persistent"):
    return {"contract_data": {"contract": contrato, "key": clave, "durability": dur}}


def tupla(nombre, valor):
    return {"vec": [{"symbol": nombre}, valor]}


entradas = {
    "instancia del contrato (incluye los schemas)": dato({"ledger_key_contract_instance": None}),
    "código Wasm": {"contract_code": {"hash": wasm}},
    "schema (clave propia, solo si estuviera en persistent)": dato(tupla("Schema", {"bytes": schema})),
    "attestation": dato(tupla("AttestationUID", {"bytes": att})),
    "nonce del emisor": dato(tupla("AttesterNonce", {"address": attester})),
}
claves = {n: xdr_key(k) for n, k in entradas.items()}
req = {"jsonrpc": "2.0", "id": 1, "method": "getLedgerEntries", "params": {"keys": list(claves.values())}}
resp = json.load(urllib.request.urlopen(urllib.request.Request(RPC, json.dumps(req).encode(), {"content-type": "application/json", "user-agent": "sas-lab/1.0"}), timeout=30))["result"]
ahora = resp["latestLedger"]
vivas = {e["key"]: e for e in resp.get("entries", [])}
filas = []
for n, k in claves.items():
    e = vivas.get(k)
    if not e:
        filas.append({"entrada": n, "existe": False})
        continue
    hasta = e["liveUntilLedgerSeq"]
    filas.append({"entrada": n, "existe": True, "liveUntilLedgerSeq": hasta, "ledgers_restantes": hasta - ahora,
                  "dias": round((hasta - ahora) * CIERRE_S / 86400, 1)})
res = {"ledger_actual": ahora, "cierre_s_supuesto": CIERRE_S, "entradas": filas}
if salida:
    json.dump(res, open(salida, "w"), indent=2, ensure_ascii=False)
print(f"Ledger actual: {ahora}  (cierre supuesto {CIERRE_S} s)\n")
print("| Entrada | Vive hasta (ledger) | Ledgers restantes | Días |\n| --- | --- | --- | --- |")
for f in filas:
    print(f"| {f['entrada']} | " + (f"{f['liveUntilLedgerSeq']} | {f['ledgers_restantes']} | {f['dias']} |" if f["existe"] else "no existe | — | — |"))
