#!/usr/bin/env python3
"""Resume evidencia.md en informe.md: resultado esperado vs observado, costos y veredicto de las hipótesis."""
import json, re, sys, time, urllib.request
from pathlib import Path

R = Path(sys.argv[1])
ev = (R / "evidencia.md").read_text() if (R / "evidencia.md").exists() else ""
filas = {}
for m in re.finditer(r"^\| (\d\d-[\w-]+) \| (OK|ERROR[^|]*?)\s*\| `([^`]*)` \| (?:\[tx\]\(https://stellar\.expert/explorer/testnet/tx/([0-9a-f]{64})\))?", ev, re.M):
    filas[m[1]] = (m[2].strip(), m[3], m[4])


def horizon(h):
    try:
        with urllib.request.urlopen(f"https://horizon-testnet.stellar.org/transactions/{h}", timeout=20) as r:
            d = json.load(r)
        return int(d["fee_charged"]), d["ledger"]
    except Exception:
        return None, None


# nombre, qué se prueba, resultado esperado según el código
casos = [
    ("21-schema-sin-resolver-sintaxis2", "Registrar schema `a:string,b:bool` (sintaxis 2)", "OK"),
    ("22-schema-struct-sintaxis1", "Registrar schema `struct X { ... }` (sintaxis 1)", "OK"),
    ("23-schema-tipos-sintaxis3", "Registrar schema `string a, bool b` (sintaxis 3)", "OK"),
    ("24-schema-con-resolver", "Registrar schema con resolver por defecto", "OK"),
    ("25-schema-no-revocable", "Registrar schema con revocable=false", "OK"),
    ("26-schema-duplicado", "Registrar el mismo schema otra vez", "ERROR #28"),
    ("31-attest-sin-resolver", "Emitir (emisorA) sin resolver", "OK"),
    ("32-attest-con-resolver", "Emitir (emisorA) con resolver por defecto", "ERROR #24"),
    ("33-exp-segundos-futuro", "Expiración en segundos (+1 año)", "OK"),
    ("34-exp-milisegundos", "Expiración en milisegundos", "(a observar)"),
    ("35-exp-pasado", "Expiración en el pasado", "ERROR #23"),
    ("37-emisorB-emite-sin-lista", "emisorB (no autorizado) emite", "(a observar)"),
    ("42-get-uid-inexistente", "Consultar un UID inexistente", "ERROR #5"),
    ("51-revoca-emisorB", "Revocar con otra cuenta (emisorB)", "ERROR #6"),
    ("52-revoca-emisorA", "Revocar con el emisor original", "OK"),
    ("53-revoca-dos-veces", "Revocar dos veces", "ERROR #29"),
    ("54-revoca-no-revocable", "Revocar en schema revocable=false", "ERROR #15"),
]

out = ["# Informe del ejercicio 01", f"Generado: {time.strftime('%Y-%m-%d %H:%M:%S UTC', time.gmtime())}", ""]
datos = (R / "datos.env").read_text() if (R / "datos.env").exists() else ""
out += ["Contratos desplegados (testnet):", "", "```", datos.strip(), "```", ""]

out += ["## Esperado vs observado", "", "| Prueba | Esperado | Observado | Coincide |", "| --- | --- | --- | --- |"]
for n, desc, esp in casos:
    obs = filas.get(n, ("sin datos",))[0]
    ok = "—" if esp.startswith("(") else ("sí" if obs.startswith(esp) else "**NO**")
    out.append(f"| {desc} | {esp} | {obs} | {ok} |")
out.append("")

# costos de las transacciones enviadas
out += ["## Costo real de las transacciones enviadas", "", "| Operación | Ledger | Comisión (XLM) |", "| --- | --- | --- |"]
total = 0
for n, (est, sal, h) in sorted(filas.items()):
    if h:
        fee, led = horizon(h)
        if fee is not None:
            total += fee
            out.append(f"| {n} | {led} | {fee / 1e7:.7f} |")
out += ["", f"Total de las operaciones listadas: {total / 1e7:.7f} XLM.", "",
        "Las operaciones que fallan lo hacen en la simulación, antes de enviarse, así que no tienen transacción ni cuestan comisión.", ""]

# veredictos
def est(n):
    return filas.get(n, ("",))[0]


def valor(n, campo):
    try:
        return json.load(open(R / "logs" / f"{n}.out"))[campo]
    except Exception:
        return None


v = []
v.append(("Emisión directa con el resolver por defecto falla",
          "CONFIRMADA" if est("32-attest-con-resolver").startswith("ERROR #24") and est("31-attest-sin-resolver") == "OK" else "NO CONFIRMADA",
          "sin resolver pasa; con el resolver falla con #24 (ResolverCallFailed), causado por `ValidationFailed` (#7) de `onattest`"))
sub, att = valor("41-get-attestation", "subject"), valor("41-get-attestation", "attester")
v.append(("`subject` siempre es el emisor", "CONFIRMADA" if sub and sub == att else "NO CONFIRMADA", f"subject == attester: {sub == att}"))
exp = valor("43-get-exp-ms", "expiration_time")
v.append(("Expiración en milisegundos", "ACEPTADA EN SILENCIO" if est("34-exp-milisegundos") == "OK" else "RECHAZADA",
          f"expiration_time={exp} se interpreta como segundos (año ≈{1970 + (exp or 0) / 31556952:.0f})"))
v.append(("emisorB puede emitir sin lista de emisores", "SÍ" if est("37-emisorB-emite-sin-lista") == "OK" else "NO", "no hay control de emisores en el núcleo"))
out += ["## Veredicto de las hipótesis", "", "| Hipótesis | Veredicto | Detalle |", "| --- | --- | --- |"] + [f"| {a} | **{b}** | {c} |" for a, b, c in v]
print("\n".join(out))
