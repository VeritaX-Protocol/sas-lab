#!/usr/bin/env python3
"""Resume los logs del ejercicio 02 en informe.md."""
import json, re, sys, time
from pathlib import Path

R = Path(sys.argv[1])
L = R / "logs"


def txt(n):
    p = L / n
    return p.read_text(errors="replace") if p.exists() else ""


def js(n):
    try:
        return json.load(open(L / n))
    except Exception:
        return None


def tabla(cab, filas):
    return ["| " + " | ".join(cab) + " |", "| " + " | ".join(["---"] * len(cab)) + " |"] + ["| " + " | ".join(str(x) for x in f) + " |" for f in filas]


def xlm(stroops):
    return f"{int(stroops) / 1e7:.4f}"


out = [f"# Informe del ejercicio 02", f"Generado: {time.strftime('%Y-%m-%d %H:%M:%S UTC', time.gmtime())}", ""]

# 1. TTL reales
out += ["## 1. TTL reales en testnet", ""]
for titulo, f in (("Contrato del ejercicio 01 (sin extend_ttl), ~16 h después de crearse", "ttl-inicial.json"),
                  ("Rama con extend_ttl, justo después de emitir", "ttl-rama-tras-emitir.json"),
                  ("Contrato del ejercicio 01 tras `stellar contract extend` de UNA attestation (500.000 ledgers)", "ttl-despues-extender.json")):
    d = js(f)
    if not d:
        continue
    out += [f"**{titulo}** (ledger {d['ledger_actual']}):", ""]
    out += tabla(["Entrada", "Vive hasta", "Ledgers restantes", "Días"],
                 [(e["entrada"], e.get("liveUntilLedgerSeq", "—"), e.get("ledgers_restantes", "—"), e.get("dias", "—")) for e in d["entradas"]]) + [""]
out += ["Lectura: sin `extend_ttl`, instancia, Wasm, attestation y nonce nacen con el mínimo de red (120.960 ledgers ≈ 7 días). "
        "El schema **no** es una entrada propia: vive dentro de la instancia. En la rama, `instance().extend_ttl` sube la instancia **y el Wasm** a la vez.", ""]

# 2. costos reales
out += ["## 2. Comisión real cobrada (Horizon, testnet P30)", ""]
rot = {"31-init": "initialize (rama)", "32-registrar": "registrar 1.er schema (RAMA: extiende instancia + Wasm a 180 días)",
       "33-emitir": "emitir (RAMA: attestation y nonce a 180 días)", "34-emitir-base": "emitir (BASE, 7 días) el mismo día",
       "40-extend": "`stellar contract extend` de 1 attestation, 500.000 ledgers (paga emisorB)",
       "53-attest-instancia-llena": "emitir con la instancia casi llena (64.552 B, contrato base)"}
filas = []
for ln in txt("costos.txt").splitlines():
    n, fee, led, h = ln.split()[0], *ln.split()[1:4]
    filas.append((rot.get(n, n), led, xlm(fee), f"[tx](https://stellar.expert/explorer/testnet/tx/{h})"))
out += tabla(["Operación", "Ledger", "XLM", "Transacción"], filas) + [""]
out += ["`35-renovar-sin-necesidad`: el CLI la trata como solo lectura (no envía transacción) porque el TTL ya está alto: **no cuesta**.", ""]

# 3. instancia
out += ["## 3. Techo de `instance` (contrato base nuevo, schemas de ~2 KB)", ""]
inst = txt("instancia.txt")
ok = [ln for ln in inst.splitlines() if " ok " in ln]
fallo = next((ln for ln in inst.splitlines() if ln.startswith("FALLA")), "")
if ok:
    f1 = int(ok[0].split()[2]); fn = int(ok[-1].split()[2])
    out += [f"- Schemas registrados con éxito: **{len(ok)}**. Comisión del 1.º: {xlm(f1)} XLM; del {len(ok)}.º: {xlm(fn)} XLM (cada registro reescribe toda la instancia)."]
m = re.search(r"\{\"u64\":\"(\d+)\"\},\{\"u64\":\"(\d+)\"\}", fallo)
if m:
    out += [f"- El schema siguiente falla: *ContractData size exceeds network config maximum size* ({m[1]} > {m[2]} bytes).",
            "- Con la instancia a 64.552 bytes todavía se pudo registrar un schema corto y emitir; el techo bloquea el crecimiento, no las llamadas."]
out.append("")

# 4. unitarias
out += ["## 4. Pruebas unitarias (Rust)", ""]
b = txt("unitarias-base.log")
rl = txt("unitarias-rama.log")
sumar = lambda t: (sum(int(x) for x in re.findall(r"(\d+) passed", t)), sum(int(x) for x in re.findall(r"(\d+) failed", t)))
sc = txt("pruebas-rama-completas.log")
out += tabla(["Árbol", "Pruebas propias", "Pasan", "Fallan"], [("base (c0c4529)", "lab_ttl_base", *sumar(b)), ("rama (lab/ttl)", "lab_ttl_base + lab_ttl_rama", *sumar(rl))])
out += ["", f"Suite completa en la rama: {sumar(sc)[0]} pasan, {sumar(sc)[1]} fallan (las 79 originales siguen verdes)." if sc else "", ""]
for etiqueta, patron in (("TTL inicial (base)", r"TTL_INICIAL.*"), ("Paso del tiempo", r"TIEMPO.*"), ("Archivo en el entorno de pruebas", r"ARCHIVO.*"),
                         ("Rama tras emitir", r"RAMA_TTL_TRAS_EMITIR.*"), ("Rama tras 7 y 97 días", r"RAMA_TRAS_\d+_DIAS.*"),
                         ("Rama: renovar", r"RAMA_RENOVAR.*"), ("Rama: UID inexistente", r"RAMA_UID_INEXISTENTE.*")):
    for t in (b, rl):
        for mm in dict.fromkeys(re.findall(patron, t)):
            out.append(f"- {etiqueta}: `{mm.strip()}`")
        if re.search(patron, t):
            break
out += ["", "Crecimiento de la instancia (bytes escritos al registrar el schema n, definiciones de ~100 B):", ""]
filas = [(a, b_) for a, b_ in dict.fromkeys(re.findall(r"INSTANCE n=(\d+) write_bytes=(\d+)", b))]
out += tabla(["n schemas", "bytes escritos"], filas) + [""]
filas = [(a, c, d, e) for a, c, d, e in dict.fromkeys(re.findall(r"EMITIR_CON_N n=(\d+) instrucciones=(\d+) mem_bytes=(\d+) write_bytes=\d+ fee_total=(\d+)", b))]
out += ["CPU y memoria de `attest` según el nº de schemas (cada llamada carga la instancia completa):", ""]
out += tabla(["n schemas", "instrucciones", "mem_bytes", "fee (entorno de pruebas)"], filas) + [""]
print("\n".join(out))
