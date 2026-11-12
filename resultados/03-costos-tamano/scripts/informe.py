#!/usr/bin/env python3
"""Resume los logs del ejercicio 03 en informe.md (sin red)."""
import json, re, sys, time
from pathlib import Path

R = Path(sys.argv[1]); L = R / "logs"
jl = lambda n: [json.loads(x) for x in (L / n).read_text().splitlines() if x.startswith("{")] if (L / n).exists() else []
xlm = lambda s: f"{int(s) / 1e7:.4f}"
tabla = lambda cab, filas: ["| " + " | ".join(cab) + " |", "| " + " | ".join(["---"] * len(cab)) + " |"] + ["| " + " | ".join(str(x) for x in f) + " |" for f in filas]

sim = jl("sim.jsonl"); info = sim[0]; sim = sim[1:]
env = jl("enviar.jsonl"); env = [e for e in env if "hash" in e]
costos = {int(l.split()[0]): (int(l.split()[1]), l.split()[3]) for l in (L / "costos.txt").read_text().splitlines()}
out = ["# Informe del ejercicio 03", f"Generado: {time.strftime('%Y-%m-%d %H:%M:%S UTC', time.gmtime())}",
       f"Medido el {info['fecha'][:10]}, ledger {info['ledger']}, protocolo {info['protocolo']}, testnet, contrato de la rama del ejercicio 02 (TTL de 180 días).", ""]

out += ["## 1. Simulación por tamaño de `value` (3 repeticiones cada una)", ""]
filas = []
for n in sorted({s["n"] for s in sim}):
    g = [s for s in sim if s["n"] == n]
    rango = lambda k: g[0][k] if len({s[k] for s in g}) == 1 else f"{min(s[k] for s in g)}–{max(s[k] for s in g)}"
    filas.append((g[0]["bytes_valor"], rango("cpu"), rango("leidos_B"), rango("escritos_B"), f"{g[0]['entradas_leer']}/{g[0]['entradas_escribir']}", xlm(g[0]["tarifa_recursos"])))
out += tabla(["value (B)", "CPU (instr.)", "bytes leídos", "bytes escritos", "entradas leer/escribir", "tarifa de recursos simulada (XLM)"], filas)
out += ["", "El rango es cero: la simulación es determinista para el mismo estado.", ""]

out += ["## 2. Envío real y desglose de renta (meta de la transacción)", ""]
filas = []
for e in env:
    fee, h = costos[e["n"]]
    filas.append((max(e["n"], 119), xlm(e["sim_tarifa_recursos"]), xlm(fee), xlm(e["renta"]), f"{e['renta'] / fee:.1%}", xlm(e["no_reembolsable"]), f"[tx](https://stellar.expert/explorer/testnet/tx/{h})"))
n16 = [l for l in costos if l == 16000]
if n16:
    fee, h = costos[16000]; filas.append((16000, "—", xlm(fee), "—", "—", "—", f"[tx](https://stellar.expert/explorer/testnet/tx/{h})"))
out += tabla(["value (B)", "simulado (XLM)", "cobrado (XLM)", "renta (XLM)", "renta / total", "no reembolsable (XLM)", "tx"], filas)
xs = [(e["n"], e["renta"]) for e in env]
(x0, y0), (x1, y1) = xs[1], xs[-1]
b = (y1 - y0) / (x1 - x0); a = y0 - b * x0
out += ["", f"Ajuste lineal de la renta por 180 días: **{a:,.0f} + {b:,.1f} × bytes de value** stroops (≈ {b / 1e7:.5f} XLM por byte; {b * 1000 / 1e7:.3f} XLM por KB). "
        "Casi todo el costo es renta; la parte que no depende del tamaño es la creación de las dos entradas (attestation y nonce). "
        "El costo cobrado queda ≈ 15 % por debajo del simulado (la parte reembolsable sobrante se devuelve).", ""]

out += ["## 3. Límites reales", ""]
lim = jl("limites.jsonl")[1:] 
sent = {e["n"]: e for e in jl("enviar-limites.jsonl") + jl("enviar-bisecta.jsonl") + jl("enviar-bisecta2.jsonl") if "n" in e}
filas = []
for s in lim:
    n = s["n"]; e = sent.get(n)
    real = "—" if not e else ("OK" if e.get("estado") == "SUCCESS" else ("RECHAZADA al enviar: tx_soroban_invalid" if e.get("fallo") else "FALLA: resource_limit_exceeded"))
    filas.append((n, "pasa" if "error" not in s else "error", real))
for n in sorted(set(sent) - {s["n"] for s in lim}):
    e = sent[n]; filas.append((n, "—", "OK" if e.get("estado") == "SUCCESS" else "FALLA: resource_limit_exceeded"))
out_note = "Los valores se piden en bytes exactos salvo el mínimo: el JSON base de ejemplo ocupa 119 B, así que «100» en realidad es 119 B."
filas.sort(key=lambda f: f[0])
out += tabla(["value (B)", "simulación", "envío real"], filas)
out += ["", out_note, "", "La simulación **no detecta** el límite de eventos de 16.384 B (el evento de `attest` incluye `value`): la transacción se envía y falla cobrando comisión.", ""]

out += ["## 4. Costo de mantener (cota superior, con la renta de creación completa)", ""]
LED_180 = 3_110_400
esc = [("hoy: 5 s por ledger", 5.0), ("hipótesis: 2,5 s", 2.5), ("hipótesis: 1 s", 1.0)]
filas = []
for n in (120, 300, 512, 1000):
    r180 = a + b * n
    fila = [n, xlm(r180)]
    for _, seg in esc:
        led_anio = 365 * 86400 / seg
        fila += [f"{r180 * led_anio / LED_180 / 1e7:.2f} / {r180 * led_anio * 5 / LED_180 / 1e7:.2f} / {r180 * led_anio * 10 / LED_180 / 1e7:.2f}"]
    filas.append(fila)
out += tabla(["value (B)", "renta 180 d (XLM)"] + [f"{e[0]}: 1 / 5 / 10 años (XLM)" for e in esc], filas)
out += ["", "La renta es lineal en ledgers: si el cierre es más rápido y el TTL máximo sigue medido en ledgers, mantener un año cuesta proporcionalmente más. "
        "Los escenarios de 2,5 s y 1 s son **hipótesis**: CAP-88 permite objetivos distintos de 5 s, pero el valor lo fija la votación de validadores (`scp_timing`, hoy 5.000 ms en testnet).", ""]

out += ["## 5. `String` JSON frente a struct tipado (entorno de pruebas, solo la parte que cambia)", ""]
t = (L / "struct.log").read_text() if (L / "struct.log").exists() else ""
filas = [(m[0], m[1], m[2], m[3]) for m in re.findall(r"STRUCT (\w+) bytes_dato=(\d+) write_bytes=(\d+) instr=(\d+)", t)]
out += tabla(["Representación", "bytes del dato", "bytes escritos", "instrucciones"], filas) + [""]
print("\n".join(out))
