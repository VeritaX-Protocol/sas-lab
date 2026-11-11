#!/usr/bin/env python3
"""Convierte los logs del ejercicio 00 en un informe en Markdown (se imprime y va a informe.md)."""
import json, re, sys, time
from pathlib import Path

R = Path(sys.argv[1])
MAX_WASM = 131072


def leer(nombre):
    p = R / nombre
    return p.read_text(errors="replace") if p.exists() else None


def json_de(nombre):
    t = leer(nombre)
    try:
        return json.loads(t) if t else None
    except ValueError:
        return None


def contar(log):
    """Suma 'N passed; M failed; K ignored' de todos los binarios de prueba y lista los tests fallidos."""
    t = leer(log)
    if t is None:
        return None
    suma = lambda k: sum(int(x) for x in re.findall(rf"(\d+) {k}", t))
    fallan = sorted(set(re.findall(r"^test (\S+) \.\.\. FAILED", t, re.M)))
    causas = sorted(set(re.findall(r'data:\["([^"]+)", (\d+)\]', t)))
    return suma("passed"), suma("failed"), suma("ignored"), fallan, causas


def buscar(o, clave):
    """Primer valor con esa clave en un JSON anidado."""
    if isinstance(o, dict):
        if clave in o:
            return o[clave]
        for v in o.values():
            r = buscar(v, clave)
            if r is not None:
                return r
    elif isinstance(o, list):
        for v in o:
            r = buscar(v, clave)
            if r is not None:
                return r
    return None


def fila(*c):
    return "| " + " | ".join(str(x) for x in c) + " |"


def tabla(cab, filas):
    return [fila(*cab), fila(*["---"] * len(cab))] + [fila(*f) for f in filas]


out = [f"# Informe del ejercicio 00", f"Generado: {time.strftime('%Y-%m-%d %H:%M:%S UTC', time.gmtime())}", ""]

# 1. Versiones
v = leer("versiones.txt")
out += ["## 1. Versiones", "```", v.strip() if v else "sin datos (ejecutar paso: versiones)", "```", ""]

# 2. Pruebas
out += ["## 2. Pruebas del contrato", ""]
filas = []
for etiqueta, log in (("soroban-sdk 27.0.6 (tal cual)", "test-heredado.log"), ("soroban-sdk 29.0.1 (micro-prueba)", "sdk29-test.log")):
    c = contar(log)
    if c is None:
        filas.append((etiqueta, "—", "—", "—", "sin datos"))
        continue
    p, f, i, _, _ = c
    filas.append((etiqueta, p, f, i, "OK" if f == 0 else f"{f} fallos"))
out += tabla(["Versión", "Pasan", "Fallan", "Ignoradas", "Estado"], filas) + [""]
c29 = contar("sdk29-test.log")
if c29 and c29[1]:
    out += [f"Fallos con SDK 29 ({c29[1]}):"] + [f"- `{n}`" for n in c29[3]]
    out += ["", "Causa(s) reportada(s) por el host:"] + [f"- {m} (versión en el test: {ver})" for m, ver in c29[4]] + [""]

# 3. Wasm
out += ["## 3. Tamaño del Wasm", ""]
filas = []
base = R / "attestprotocol/contracts/stellar/target/wasm32v1-none/release"
for w in ("protocol.wasm", "resolvers.wasm"):
    f = base / w
    filas.append((w, f"{f.stat().st_size:,}".replace(",", "."), f"{100 * f.stat().st_size / MAX_WASM:.0f} %") if f.exists() else (w, "—", "—"))
out += tabla(["Archivo", "Bytes", f"% del máximo ({MAX_WASM:,} B)".replace(",", ".")], filas) + [""]

# 4. Red
out += ["## 4. Red", ""]
vt, lt, hz = json_de("version-testnet.json"), json_de("ledger-testnet.json"), json_de("version-mainnet.json")
filas = []
if vt and lt:
    r = lt.get("result", {})
    cierre = time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime(int(r["closeTime"]))) if r.get("closeTime") else "—"
    filas.append(("testnet", vt["result"].get("protocolVersion"), r.get("sequence"), cierre + " UTC"))
if hz:
    filas.append(("mainnet", f"{hz.get('current_protocol_version')} (soporta {hz.get('core_supported_protocol_version')})", hz.get("history_latest_ledger"), hz.get("history_latest_ledger_closed_at")))
out += (tabla(["Red", "Protocolo", "Ledger", "Cierre"], filas) if filas else ["sin datos (ejecutar paso: red)"]) + [""]

aj = json_de("ajustes-testnet.json")
if aj:
    esperado = [  # (etiqueta, clave, valor del análisis previo)
        ("Tamaño máx. de Wasm (bytes)", "contract_max_size_bytes", 131072),
        ("Entradas en el footprint por tx", "tx_max_footprint_entries", 400),
        ("Entradas escritas por tx", "tx_max_write_ledger_entries", 200),
        ("Bytes escritos por tx", "tx_max_write_bytes", 132096),
        ("Instrucciones de CPU por tx", "tx_max_instructions", 400000000),
        ("Entradas leídas de disco por tx", "tx_max_disk_read_entries", None),
        ("Clave de ledger (bytes)", "contract_data_key_size_bytes", None),
        ("Entrada de contract-data (bytes)", "contract_data_entry_size_bytes", None),
        ("TTL máximo (ledgers)", "max_entry_ttl", None),
        ("TTL mínimo persistente (ledgers)", "min_persistent_ttl", None),
        ("Cierre objetivo de ledger (ms)", "ledger_target_close_time_milliseconds", None),
    ]
    filas = []
    for et, k, previo in esperado:
        val = buscar(aj, k)
        if previo is None:
            marca = "nuevo"
        else:
            marca = "coincide" if str(val) == str(previo) else f"DIFIERE (análisis: {previo})"  # el JSON trae los enteros grandes como texto
        filas.append((et, val if val is not None else "—", marca))
    out += ["Límites de testnet frente al análisis previo:", ""] + tabla(["Límite", "Testnet hoy", "Análisis previo"], filas) + [""]

# 5. Contrato
out += ["## 5. Qué usa el contrato (grep de línea base)", ""]
g = leer("grep.txt")
if g:
    bloques = re.findall(r"== (.+)\n((?:.*\n)*?)  \(tests: (\d+) archivos\)", g)
    filas = [(f"`{k}`", len([ln for ln in cuerpo.splitlines() if ln.strip()]), t) for k, cuerpo, t in bloques]
    out += tabla(["Término", "Usos en src", "Archivos de test"], filas) + [""]
else:
    out += ["sin datos (ejecutar paso: red)", ""]

# 6. Auditoría
out += ["## 6. Desde el commit que escaneó Almanax", "", "```", (leer("auditoria.txt") or "sin datos (ejecutar paso: auditoria)").strip(), "```", ""]

# 7. Identidades
out += ["## 7. Identidades de prueba (solo claves públicas)", "", "```", (leer("identidades-publicas.txt") or "sin datos (ejecutar paso: identidades)").strip(), "```"]

print("\n".join(out))
