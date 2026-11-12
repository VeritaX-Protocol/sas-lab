# Ejercicio 04: autorización, emisores y upgrade

Prueba quién puede emitir, qué pasa con los certificados de un emisor retirado, quién puede revocar y cómo se actualiza el contrato sin perder estado. Compara una lista de emisores en el núcleo con un resolver aparte.

- Enunciado: [../../ejercicios/ejercicio-04-autorizacion-emisores-upgrade.md](../../ejercicios/ejercicio-04-autorizacion-emisores-upgrade.md)
- Lo aprendido y las decisiones: [NOTA.md](NOTA.md)
- Resumen de resultados: [informe.md](informe.md)
- Cambios en el contrato: [cambios-emisores.patch](cambios-emisores.patch)

## Requisitos previos

- Ejercicios 00, 01 y 02 hechos (identidades `admin`, `emisorA`, `emisorB` con fondos; clon del 02 con `cambios-ttl.patch`).
- Worktree `attestprotocol-emisores/` (rama `lab/emisores` sobre `c0c4529` + `../02-almacenamiento-ttl/cambios-ttl.patch` + `cambios-emisores.patch`); ignorado por git.
- `stellar` CLI, `cargo`, `python3`, `curl`. Sin `.env.local`.

## Forma rápida: scripts

```bash
cd resultados/04-autorizacion-emisores-upgrade
scripts/ejecutar.sh              # todo (varios minutos; ≈ 90 XLM de testnet)
scripts/ejecutar.sh pruebas      # 1. pruebas Rust: 9 propias en v1 y v2 + suite completa
scripts/ejecutar.sh wasm         # 2. compila v1, v2 y el resolver (hashes en wasm/SHA256.txt)
scripts/ejecutar.sh testnet      # 3. despliega v1, emite, retira, sube v2, upgrade y revoca
scripts/ejecutar.sh informe      # 4. genera informe.md
```

- Cada paso escribe en `logs/`; los costos reales (Horizon) quedan en `logs/costos.txt` y los datos del despliegue en `datos-04.env`.
- **`testnet` despliega un contrato nuevo y gasta ≈ 90 XLM de testnet** (dos veces la renta del Wasm de 38 KB a 180 días). Repetirlo no pisa nada: crea otro contrato.
- v2 se compila con `--features v2` (el admin puede revocar y `version()` devuelve 2).

## Qué hace cada pieza

| Pieza | Qué hace |
|---|---|
| `pruebas/lab_emisores.rs` | 9 pruebas: `mock_auths`, `emisorB` sin lista, `initialize`, lista de emisores, quién cambia la lista, revocar, upgrade por tercero, costo núcleo vs resolver, migración de un tipo guardado |
| `cambios-emisores.patch` | Diff: `issuers.rs` (núcleo), `IssuerResolver`, `upgrade`, `version`, `IssuerNotActive #30`, revocación del admin en v2 |
| `scripts/ejecutar.sh` | Orquesta los pasos |
| `scripts/informe.py` | Genera `informe.md` desde `logs/` |

## Salida esperada

- 9/9 pruebas propias en v1 y en v2; suite completa 88 pasan en v1 y 87 pasan + 1 falla en v2 (esa prueba original asume que el admin no revoca).
- `emisorB` recibe `#30` (no listado) y `#6` (no autorizado); `emisorA` retirado recibe `#30`.
- `version()` pasa de 1 a 2; v2 lee los registros de v1.
- Wasm: v1 38.449 B, v2 38.494 B, resolver 4.190 B.

## Casos negativos probados

- `emisorB` emite en un schema con lista → `#30`; `emisorA` retirado → `#30`.
- `emisorB` se añade a la lista → `#6`; `emisorB` revoca un registro ajeno → `#6`.
- `emisorB` dispara `upgrade` → el CLI se niega (falta la firma del admin); en Rust, `Abort`.
- `initialize` por segunda vez → `AlreadyInitialized`; un tercero que llega primero se queda con el contrato.

## Problemas frecuentes

| Síntoma | Causa probable | Qué hacer |
|---|---|---|
| `no method named add_issuer` | `CARGO_TARGET_DIR` compartido con otro ejercicio | Usa un `target` por ejercicio (el script ya lo hace) |
| `Error(Contract, #30)` al emitir | El schema tiene lista y el emisor no está activo | `add_issuer` primero |
| La primera emisión tras el upgrade cuesta ≈ 43 XLM | El Wasm nuevo es otra entrada sin TTL extendido | Extender el Wasm nuevo tras actualizar |
| `contract not found` | Testnet se reinició | Repite el script `testnet` |

## Seguridad

Solo claves públicas en `datos-04.env`. El prototipo es para aprender: **no es el contrato del sprint**, y no se prueba delegación BLS.
