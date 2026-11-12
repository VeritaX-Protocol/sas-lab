#!/usr/bin/env python3
"""Resume los logs del ejercicio 04 en informe.md (sin red)."""
import re, sys, time
from pathlib import Path

R = Path(sys.argv[1]); L = R / "logs"
txt = lambda n: (L / n).read_text(errors="replace") if (L / n).exists() else ""
tabla = lambda cab, filas: ["| " + " | ".join(cab) + " |", "| " + " | ".join(["---"] * len(cab)) + " |"] + ["| " + " | ".join(str(x) for x in f) + " |" for f in filas]
xlm = lambda s: f"{int(s) / 1e7:.4f}"
out = ["# Informe del ejercicio 04", f"Generado: {time.strftime('%Y-%m-%d %H:%M:%S UTC', time.gmtime())}", ""]

out += ["## 1. Pruebas Rust", ""]
def suma(t, k): return sum(int(x) for x in re.findall(rf"(\d+) {k}", t))
filas = [(n, suma(txt(f), "passed"), suma(txt(f), "failed")) for n, f in
         (("lab_emisores (v1)", "pruebas-v1.log"), ("lab_emisores (v2)", "pruebas-v2.log"), ("suite completa (v1)", "suite-completa-v1.log"), ("suite completa (v2)", "suite-completa-v2.log"))]
out += tabla(["Conjunto", "Pasan", "Fallan"], filas) + [""]
f2 = re.search(r"^test (\w+) \.\.\. FAILED", txt("suite-completa-v2.log"), re.M)
if f2:
    out += [f"En v2 falla `{f2[1]}`: esa prueba original da por hecho que el admin **no** puede revocar, que es justo lo que v2 cambia.", ""]
for etiqueta, patron in (("Autorización", r"(AUTHS_A.*|AUTH_B_POR_A.*|SIN_FIRMA.*|UPGRADE_POR_B.*)"), ("Hallazgo heredado", r"(HALLAZGO.*|INIT_SECUESTRO.*)"),
                         ("Lista de emisores", r"(B_RECHAZADO.*|RETIRADO_CONSERVA.*|TERCERO_ADD.*)"), ("Revocar", r"(ADMIN_REVOCA.*)"), ("Migración de un tipo guardado", r"(MIGRACION.*)")):
    for m in dict.fromkeys(re.findall(patron, txt("pruebas-v1.log") + "\n" + txt("pruebas-v2.log"))):
        out.append(f"- {etiqueta}: `{m.strip()}`")
out += [""]

out += ["## 2. Costo de `attest`: núcleo frente a resolver (entorno de pruebas)", ""]
filas = [m for m in re.findall(r"COSTO (\w+) instr=(\d+) mem=(\d+) write=(\d+) read=(\d+)", txt("pruebas-v1.log"))]
out += tabla(["Variante", "instrucciones", "mem (B)", "bytes escritos", "bytes leídos"], filas)
if len(filas) == 3:
    b, n, r = (int(f[1]) for f in filas)
    out += ["", f"Lista en el núcleo: +{n - b:,} instrucciones (+{(n - b) / b:.0%}). Resolver aparte: +{r - b:,} (+{(r - b) / b:.0%}).", ""]

out += ["## 3. Tamaño de Wasm (límite de red: 131.072 B)", ""]
tam = lambda p: (R / "wasm" / p).stat().st_size if (R / "wasm" / p).exists() else 0
ttl = R.resolve().parent / "02-almacenamiento-ttl" / "wasm" / "protocol-rama.wasm"
filas = [("Heredado + TTL (ejercicio 02)", ttl.stat().st_size if ttl.exists() else "—"), ("v1: + lista de emisores + upgrade + version", tam("protocol-v1.wasm")),
         ("v2: v1 + admin revoca", tam("protocol-v2.wasm")), ("Resolver de emisores (contrato aparte)", tam("resolver-emisores.wasm"))]
out += tabla(["Wasm", "bytes"], filas) + [""]

out += ["## 4. Testnet: lo que pasó", ""]
costos = {l.split()[0]: l.split() for l in txt("costos.txt").splitlines() if l.strip()}
def res(n):
    o = (L / f"{n}.out"); e = (L / f"{n}.err")
    ee = e.read_text(errors="replace") if e.exists() else ""
    m = re.search(r"Error\(Contract, #(\d+)\)", ee)
    if m: return f"error #{m[1]}"
    if "Missing signing key" in ee: return "rechazado: falta la firma del admin"
    if "Auth" in ee and "error" in ee.lower(): return "rechazado: " + (re.search(r"Error\((Auth[^)]*)\)", ee) or [None, "autorización"])[1]
    if "error" in ee.lower() and not o.exists(): return "error"
    return "OK" + (f" → {o.read_text().strip()[:60]}" if o.exists() and o.stat().st_size and n[:2] not in ("32", "33", "36", "58") else "")
nombres = [("32-registrar", "admin registra el schema (1.er `register`: renta del Wasm v1 + instancia, 180 días)"), ("33-b-sin-lista", "emisorB emite en schema sin lista (heredado)"), ("34-b-se-autoañade", "emisorB se añade a sí mismo a la lista"), ("35-admin-añade-a", "admin añade a emisorA"),
           ("36-a-emite", "emisorA activo emite"), ("37-b-rechazado", "emisorB (no listado) emite"), ("38-retira-a", "admin retira a emisorA"), ("39-a-retirado", "emisorA retirado emite"),
           ("41-estado-a", "estado de emisorA"), ("44-version-v1", "version() en v1"), ("51-upgrade-por-b", "emisorB dispara upgrade"), ("52-version-sigue-1", "version() tras el intento"),
           ("53-upgrade-admin", "admin dispara upgrade"), ("54-version-v2", "version() en v2"), ("57-v2-b-rechazado", "v2: emisorB emite (error no renumerado)"),
           ("58-v2-a-emite", "v2: emisorA emite (1.ª tras el upgrade: paga la renta del Wasm nuevo)"), ("59-b-revoca", "v2: emisorB revoca registro ajeno"), ("60-admin-revoca", "v2: admin revoca"), ("62-a-revoca-la-suya", "v2: emisorA revoca la suya")]
filas = []
for n, d in nombres:
    c = costos.get(n)
    filas.append((d, res(n), xlm(c[1]) if c else "—", f"[tx](https://stellar.expert/explorer/testnet/tx/{c[3]})" if c else "—"))
out += tabla(["Paso", "Resultado", "Comisión (XLM)", "Transacción"], filas) + [""]
h = re.search(r"tx/([0-9a-f]{64})", txt("50-upload-v2.err"))
if h: out.append(f"- Subida del Wasm v2 (`stellar contract upload`): [tx](https://stellar.expert/explorer/testnet/tx/{h[1]})")
for n, d in (("40-lee-anterior", "Lectura en v1 del registro de emisorA tras retirarlo"), ("55-v2-lee-att1", "Lectura en v2 del registro hecho en v1"), ("61-lee-revocada", "Lectura del registro revocado por el admin")):
    p = L / f"{n}.out"
    if p.exists():
        j = p.read_text()
        out.append(f"- {d}: `revoked={'true' in re.search(r'\"revoked\":(true|false)', j)[0]}`, `attester=…{re.search(r'\"attester\":\"G\w+(\w{6})\"', j)[1]}`")
datos = (R / "datos-04.env").read_text() if (R / "datos-04.env").exists() else ""
for k in ("ID", "H1", "H2"):
    m = re.search(rf"^{k}=(\S+)", datos, re.M)
    if m: out.append(f"- {k}: `{m[1]}`")
print("\n".join(out))
