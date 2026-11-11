# Ejercicio 00: toolchain y línea base

Comprueba que esta máquina compila y prueba el contrato heredado de Attest Protocol, fija versiones y límites de la red, y revisa qué respaldo real tienen las "auditorías".

- Enunciado: [../../ejercicios/ejercicio-00-toolchain.md](../../ejercicios/ejercicio-00-toolchain.md)
- Lo aprendido: [NOTA.md](NOTA.md)

## Requisitos previos

| Herramienta | Para qué | Cómo comprobar |
|---|---|---|
| `rustc` y `cargo` | Compilar y probar | `rustc -V` y `cargo -V` |
| Target `wasm32v1-none` | Generar el Wasm | `rustup target list --installed` |
| `stellar` CLI | Compilar contratos, red y claves | `stellar --version` |
| `git`, `curl`, `python3` | Clonar, consultar la red, extraer límites | `git --version` |
| `pdftotext` y `pdftoppm` | Leer los PDF de auditoría | `pdftotext -v` |
| Internet | Testnet, crates.io, GitHub | — |

No hay `.env.local` ni claves en esta carpeta. Si falta algo de la tabla, detente y pregunta: este ejercicio **verifica** el entorno, no lo instala.

## Forma rápida: scripts

```bash
cd resultados/00-toolchain
scripts/ejecutar.sh                    # todos los pasos y genera informe.md (~4 min la primera vez)
scripts/ejecutar.sh pruebas wasm       # solo algunos pasos
scripts/ejecutar.sh informe            # solo reconstruir informe.md desde los logs
```

Pasos disponibles: `versiones`, `clon`, `pruebas`, `wasm`, `red`, `identidades`, `auditoria`, `sdk29`, `informe`.

- Cada paso escribe su log en esta carpeta y el paso `informe` los resume en [informe.md](informe.md): tablas de pruebas, tamaño del Wasm, red y límites (con "coincide / DIFIERE / nuevo" frente al análisis previo), uso de storage del contrato e identidades.
- El script es repetible: no regenera identidades que ya existen y la micro-prueba de SDK 29 usa un `git worktree` temporal, así que el clon queda siempre en `c0c4529`.
- Para reutilizar una compilación de SDK 29 ya hecha: `SAS_TARGET_SDK29=/ruta/target scripts/ejecutar.sh sdk29` (por defecto `~/.cache/sas-lab/t29`).
- Los pasos de abajo explican qué hace cada uno por si prefieres ejecutarlos a mano.

## Cómo repetirlo, paso a paso

Todos los comandos se ejecutan desde `sas-lab/resultados/00-toolchain/`, salvo que se indique otra carpeta. Anota la fecha y hora UTC al empezar: la red cambia.

### Paso 1. Verificar versiones

```bash
cd resultados/00-toolchain
{ rustc -V; cargo -V; rustup target list --installed; stellar --version | head -1; node -v; git --version; } | tee versiones.txt
```

- **Qué hace:** deja registradas las versiones con las que se mide todo.
- **Esperado:** `wasm32v1-none` aparece en la lista de targets. Si falta, no instales nada: pregunta.

### Paso 2. Clonar el contrato y fijar el commit

```bash
git clone https://github.com/daccred/attestprotocol
git -C attestprotocol checkout c0c4529
git -C attestprotocol log -1 --format='%h %ci %s'
```

- **Qué hace:** trae el código de Attest Protocol y lo deja en el commit del laboratorio (2026-09-11).
- **Esperado:** la última línea empieza por `c0c4529`.
- **Nota:** el clon queda ignorado por git (`resultados/*/attestprotocol/` en `.gitignore`); no se sube al repo.

### Paso 3. Ejecutar las pruebas del contrato tal cual

```bash
cd attestprotocol/contracts/stellar
cargo test --workspace --no-fail-fast 2>&1 | tee ../../../test-heredado.log
```

- **Qué hace:** corre todas las pruebas con `soroban-sdk 27.0.6`.
- **Tarda:** unos 3 minutos la primera vez (descarga y compila dependencias).
- **Esperado:** 79 pruebas pasan, 0 fallan, 7 ignoradas. Para contarlas: `grep "^test result" ../../../test-heredado.log`.
- Un fallo **no es un error del ejercicio**: es un hallazgo que va a `NOTA.md`.

### Paso 4. Compilar a Wasm y medir el tamaño

```bash
(cd protocol  && make build)
(cd resolvers && make build)
ls -l target/wasm32v1-none/release/*.wasm
```

- **Qué hace:** `make build` llama a `stellar contract build`, la forma correcta desde `soroban-sdk` 28.
- **Esperado:** `protocol.wasm` ≈ 34.287 bytes y `resolvers.wasm` ≈ 3.542 bytes. El máximo de la red es 131.072 bytes.

### Paso 5. Grep de línea base

```bash
for k in 'extend_ttl' 'instance()' 'persistent()' 'temporary()' 'mock_all_auths' 'mock_auths' 'update_current_contract_wasm' '__constructor'; do
  echo "== $k"; grep -rnF "$k" protocol/src resolvers/src --include=*.rs
  echo "  (tests: $(grep -rlF "$k" protocol/tests resolvers/tests --include=*.rs | wc -l) archivos)"
done | tee ../../../grep.txt
```

- **Qué hace:** cuenta dónde usa el contrato cada tipo de almacenamiento y de autorización.
- **Esperado:** `extend_ttl`, `temporary()`, `update_current_contract_wasm` y `__constructor` salen en 0. Los schemas están en `instance()` (`schema.rs`).

### Paso 6. Leer los límites y el protocolo de la red

```bash
cd ../../..   # vuelve a resultados/00-toolchain
stellar network settings --network testnet --output json-formatted > ajustes-testnet.json
curl -s -X POST https://soroban-testnet.stellar.org -H 'content-type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getVersionInfo"}' > version-testnet.json
curl -s -X POST https://soroban-testnet.stellar.org -H 'content-type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getLatestLedger"}' > ledger-testnet.json
curl -s https://horizon.stellar.org/ | python3 -c "import sys,json;d=json.load(sys.stdin);print({k:d.get(k) for k in ('current_protocol_version','core_supported_protocol_version','history_latest_ledger','history_latest_ledger_closed_at')})" | tee version-mainnet.txt
```

- **Qué hace:** guarda los límites de testnet y el protocolo de testnet y de mainnet.
- **Esperado hoy (2026-11-11):** testnet en protocolo 30, mainnet en 29.
- **Mainnet:** `stellar network settings --network mainnet` falla porque exige un RPC propio ("Bring Your Own"); por eso el protocolo de mainnet se lee por Horizon.
- **Campos clave de `ajustes-testnet.json`:** `contract_max_size_bytes`, `tx_max_footprint_entries`, `tx_max_write_ledger_entries`, `tx_max_write_bytes`, `tx_max_instructions`, `max_entry_ttl`, `contract_data_entry_size_bytes`.

### Paso 7. Crear las tres identidades de prueba

```bash
stellar keys ls                                   # comprueba que no existan ya
for a in admin emisorA emisorB; do stellar keys generate "$a" --network testnet --fund; done
for a in admin emisorA emisorB; do echo "$a $(stellar keys address $a)"; done | tee identidades-publicas.txt
```

- **Qué hace:** crea las cuentas y las fondea con friendbot (solo testnet).
- **Esperado:** tres mensajes "Account ... funded".
- **Seguridad:** guarda solo las claves **públicas** (`identidades-publicas.txt`). Las secretas quedan en el almacén del CLI. No ejecutes `stellar keys secret` ni pegues su salida en ningún archivo.

### Paso 8. Revisar las auditorías

```bash
cd attestprotocol/contracts/stellar/audit
ls -l
pdftotext -layout scout-attest-protocol-auditv1.pdf - | head -30     # Scout: 1 página con texto
pdftoppm -r 70 -png "Almanax Security Report-2025-30-11.pdf" /tmp/alm   # Almanax: solo imágenes; ábrelas para leerlas
```

- **Qué hace:** identifica qué es cada informe, de qué fecha y sobre qué código.
- **Esperado:** los de Scout y Almanax son **análisis automáticos**, no auditorías manuales. El de Almanax apunta al commit `287e2ed` (2025-12-01). Comprueba cuánto cambió el código desde entonces:

```bash
cd ../..   # raíz del clon, attestprotocol/
git rev-list --count 287e2ed..c0c4529 -- contracts/stellar/protocol/src contracts/stellar/resolvers/src
git diff --shortstat 287e2ed c0c4529 -- contracts/stellar/protocol/src contracts/stellar/resolvers/src
```

- **Esperado:** 30 commits y 14 archivos cambiados. Las conclusiones están en [NOTA.md](NOTA.md), sección "Auditorías".

### Paso 9. Micro-prueba con `soroban-sdk 29` (sin migrar nada)

```bash
cd attestprotocol
git checkout -b lab/sdk29
sed -i 's/soroban-sdk = { version = "27.0.6" }/soroban-sdk = { version = "29.0.1" }/' contracts/stellar/Cargo.toml
cd contracts/stellar
export CARGO_TARGET_DIR=/tmp/sas-lab-t29               # directorio aparte para no mezclar compilaciones
cargo test --workspace --no-fail-fast 2>&1 | tee ../../../sdk29-test.log
```

- **Qué hace:** comprueba si el contrato compila y pasa pruebas con el SDK vigente.
- **Esperado:** compila sin errores y fallan 9 pruebas con el mensaje `ledger protocol version too old for host`, porque tres tests fijan `protocol_version: 27`.
- **Para ver las causas:** `grep -A4 "^---- .* stdout" ../../../sdk29-test.log | head -30`.
- **Limpieza obligatoria al terminar** (el clon debe quedar en `c0c4529`):

```bash
unset CARGO_TARGET_DIR
cd ../..
git checkout -- . && git checkout -q c0c4529 && git branch -D lab/sdk29
git status --short        # no debe mostrar nada
```

### Paso 10. Escribir la nota

Completa [NOTA.md](NOTA.md) con la plantilla del [LEEME](../../LEEME.md#8-plantilla-de-nota-notamd-dentro-de-la-carpeta-del-ejercicio): fecha, protocolo y ledger, versiones, qué funcionó, qué falló y las decisiones.

## Archivos que genera este ejercicio

| Archivo | Contenido | Paso |
|---|---|---|
| `versiones.txt` | rustc, cargo, target, stellar CLI, node, git | 1 |
| `test-heredado.log` | Pruebas con `soroban-sdk 27.0.6` | 3 |
| `grep.txt` | Uso de `extend_ttl`, `instance()`, `persistent()`... | 5 |
| `ajustes-testnet.json` | Límites de la red (protocolo 30) | 6 |
| `version-testnet.json`, `ledger-testnet.json`, `version-mainnet.txt` | Protocolo y ledger de cada red | 6 |
| `identidades-publicas.txt` | Solo claves públicas | 7 |
| `informe.md`, `auditoria.txt`, `build-*.log` | Resumen legible y datos de apoyo (scripts) | — |
| `sdk29-test.log` | Micro-prueba con `soroban-sdk 29.0.1` | 9 |

## Casos negativos probados

- `stellar network settings --network mainnet` falla (pide RPC propio); se usa Horizon.
- Con `soroban-sdk 29.0.1` fallan 9 pruebas por una causa concreta y acotada (paso 9).

## Problemas frecuentes

| Síntoma | Causa probable | Qué hacer |
|---|---|---|
| `cargo test` parece colgado en "Updating crates.io index" | Primera descarga de dependencias | Espera unos minutos; no lo canceles |
| `stellar keys generate` dice que el alias existe | Ya creaste esa identidad | Reutilízala; no la regeneres |
| `git checkout c0c4529` falla | Clon incompleto | `git -C attestprotocol fetch --all` y repite |
| El friendbot no fondea | Límite de uso o red caída | Espera unos minutos y repite solo ese paso |
