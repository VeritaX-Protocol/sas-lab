# Nota del ejercicio 00

Fecha y hora UTC: 2026-11-11, entre 19:26 y 19:40 UTC.

Protocolo de la red y ledger de la medición:
- **Testnet: Protocolo 30**, ledger 5.680.335 (close time 2026-11-11 19:28:38 UTC); stellar-core 30.0.0, RPC `30.0.0`.
- **Mainnet: Protocolo 29** (Horizon `current_protocol_version: 29`, `core_supported_protocol_version: 30`), ledger 65.427.858 (19:28:52 UTC). Aún no vota P30 (voto previsto 2026-11-23).
- Tiempo de cierre objetivo en testnet P30: `ledger_target_close_time_milliseconds = 5000` (5 s). CAP-88 (cierre en milisegundos) **no está activo todavía**.

Versiones usadas: rustc 1.99.1, cargo 1.99.1, target `wasm32v1-none`, stellar CLI 30.0.1 (stellar-xdr 30.0.0), Node v26.13.0, git 2.43.0. Contrato: `soroban-sdk 27.0.6`.

Commit de attestprotocol usado: `c0c4529` (2026-09-11, "fix(deps): patch toml, vitest, fflate and stream-json advisories").

Código o datos copiados de otros ejercicios: ninguno.

## Qué hice

Verifiqué el toolchain (sin instalar), cloné y fijé `c0c4529`, corrí `cargo test`, compilé con `make build`, leí los límites de testnet, creé 3 identidades, revisé los informes de auditoría, hice el grep de línea base y probé el contrato con `soroban-sdk 29.0.1` en una rama local (ya descartada; el clon quedó limpio en `c0c4529`).

## Qué funcionó

- **`cargo test --workspace`: 79 pasan, 0 fallan, 7 ignoradas** (3 min 10 s la primera vez, con descarga de dependencias).
- **El Makefile ya compila con `stellar contract build`** (`protocol/Makefile`, target `build`). La preocupación del plan sobre `cargo build` directo no aplica a este repo.
- **Tamaño del Wasm:** `protocol.wasm` = **34.287 bytes** (26 % del máximo de 131.072); `resolvers.wasm` (resolver por defecto) = **3.542 bytes**.
- 3 identidades creadas y fondeadas con friendbot (`identidades-publicas.txt`).

### Límites de red de testnet vs. el análisis previo

| Dato | Análisis previo | Testnet hoy (P30) | ¿Coincide? |
|---|---|---|---|
| Tamaño máx. de Wasm | 128 KB | 131.072 bytes (`contract_max_size_bytes`) | Sí |
| Entradas en el footprint por tx | 400 | 400 (`tx_max_footprint_entries`) | Sí |
| Entradas escritas por tx | 200 | 200 (`tx_max_write_ledger_entries`) | Sí |
| Bytes escritos por tx | 132.096 | 132.096 (`tx_max_write_bytes`) | Sí |
| Instrucciones de CPU por tx | 400M | 400.000.000 (`tx_max_instructions`) | Sí |
| Entradas leídas de disco por tx | no citado | 200 (`tx_max_disk_read_entries`); 200.000 bytes | nuevo |
| Clave de ledger | no citado | ≤ 250 bytes (`contract_data_key_size_bytes`) | nuevo |
| Entrada de contract-data | no citado | ≤ 65.536 bytes = 64 KiB | nuevo |
| Eventos por tx | no citado | ≤ 16.384 bytes | nuevo |
| TTL máx. de una entrada | no citado | 3.110.400 ledgers (≈180 días a 5 s) | nuevo |
| TTL mín. persistente / temporal | no citado | 120.960 (≈7 días) / 720 (≈1 h) | nuevo |

Mainnet no se pudo leer con el CLI: `stellar network settings --network mainnet` pide un RPC propio ("Bring Your Own"). **Los valores de mainnet quedan sin verificar aquí**; la tabla es de testnet.

## Qué falló o me sorprendió

1. **Con `soroban-sdk 29.0.1` el contrato compila sin errores** (solo 9 avisos de imports no usados) y el Wasm se genera (30.995 bytes), pero **fallan 9 de 86 pruebas** (70 pasan, 7 ignoradas). Causa única: *"ledger protocol version too old for host", 27*. Tres puntos de los tests fijan `protocol_version: 27` al construir `LedgerInfo`: `protocol/tests/protocol_attestation_test.rs:269` y `:781` y `resolvers/tests/default_resolver.rs:17`. No es una incompatibilidad del contrato. Lección para el ejercicio 02: al avanzar el ledger en pruebas, **no copiar un `protocol_version` fijo**; tomarlo del `Env`.
2. **Testnet ya está en P30 y mainnet en P29.** Cualquier prueba en testnet corre un protocolo por delante de producción.
3. **`mock_all_auths` aparece en 10 archivos de tests y `mock_auths` solo en 4**: la cobertura de autorización con firmas específicas es parcial (insumo del ejercicio 04).
4. El análisis previo decía "Scout" y "Halborn" como auditorías. Ver sección siguiente.

## Auditorías: qué respaldo real hay (tarea 8)

| Documento | Qué es realmente | Fecha / versión | Resultado |
|---|---|---|---|
| `Almanax Security Report-2025-30-11.pdf` | **Escáner de seguridad automático** de Almanax ("Security Scanner"), no una auditoría manual | Escaneo 2025-12-01, sobre `daccred/attest.so@287e2ed` (commit existente en este historial, 2025-12-01) | 0 críticos, **1 alto**, 5 medios, 5 bajos, 0 info |
| `scout-attest-protocol-auditv1.pdf` | Análisis **estático automático** (CoinFabrik Scout), 1 página | 2025-11-07 | `protocol`: 0 críticos, 0 medios, 0 menores, 1 mejora (eventos en cambio de almacenamiento) |
| `scout-attest-protocol-resolvers-auditv1.pdf` | Ídem para `resolvers` | 2025-11-07 | 0 hallazgos |
| `scout-experimental-authority-auditv1.pdf` | Ídem para el crate experimental `authority` (no se usa en VeritaX) | 2025-11-07 | 5 críticos, 4 medios, 1 menor, 2 mejoras |
| `ARCHITECTURE.md`, `*_STRIDE.md`, `LOC.md` | Documentos de diseño y modelo de amenazas **escritos por Daccred** (autoevaluación) | — | No son informes de terceros |

Hallazgos de Almanax que importan para VeritaX, y su estado en `c0c4529`:
- **Medio: `schema_definition` sin tope de tamaño** (`protocol/src/instructions/schema.rs`, `register_schema`). **Sigue sin tope**: `schema.rs` no tiene ninguna comprobación de longitud. Confirma la necesidad de topes (ejercicio 03).
- **Medio: `initialize` abierto** (el informe lo describe en `resolvers/src/fee_collection.rs`). El protocolo tiene el mismo patrón: `initialize` exige `admin.require_auth()` y falla si ya está inicializado (`protocol/src/lib.rs:37-48`), **pero cualquiera puede inicializar primero con su propia dirección** si el despliegue y el `initialize` no son atómicos. A probar en el ejercicio 04 (alternativa: `__constructor`).
- **Medio: `revocable: true` fijo en la attestation que ve el resolver**. **Corregido** en `c0c4529` (`create_resolver_attestation` recibe `revocable`).
- **Alto: en `revoke_by_delegation` no se comparaba el `schema_uid` de la solicitud con el de la attestation.** Está en la ruta de **delegación BLS**, que VeritaX deja fuera.
- Medio/bajo restantes: aritmética sin `checked_add` en el resolver de ejemplo, credenciales en `deploy.sh` (las líneas que imprimen la passphrase están hoy comentadas en `deploy.sh:121-122`).

Contexto temporal:
- Entre el commit escaneado (`287e2ed`, 2025-12-01) y `c0c4529` hay **30 commits y 14 archivos cambiados (+691/−955 líneas)** en `protocol/src` y `resolvers/src`.
- Esos commits corrigen hallazgos etiquetados `HAL-01` a `HAL-08`, `C-CONTRACT-1..4` y `H-CONTRACT-2/4` (fusiones del 2026-04-29). **No hay ningún informe de Halborn ni de esa revisión en el repo**; solo quedan las referencias en mensajes de commit y comentarios.
- El **protocolo v2 se desplegó en mainnet el 2026-08-31** (commit `c67f1af`), **después** de todos los informes presentes. Ningún informe del repo cubre el código desplegado.

**Conclusión para el SOW:** no escribir "contrato auditado". Lo que se puede afirmar con evidencia es: *"base de código abierto (MIT), mantenida, con escaneos automáticos publicados (Almanax, CoinFabrik Scout), correcciones posteriores referenciadas a hallazgos de una revisión externa cuyo informe no está en el repositorio, y desplegada en mainnet"*. Para citar una auditoría hay que pedir el informe a Daccred.

## Grep de línea base (`grep.txt`)

| Término | Resultado en `protocol/src` + `resolvers/src` |
|---|---|
| `extend_ttl` | **0**. Confirmado: el contrato no extiende ningún TTL |
| `temporary()` | 0 |
| `update_current_contract_wasm` | 0. Sin función de upgrade |
| `__constructor` | 0. Se usa `initialize` |
| `instance()` | `lib.rs:38,45` (admin), `schema.rs:22,95,106` (**schemas**), `utils.rs:155` (`_get_authority`), `utils.rs:177` (`get_schema`) |
| `persistent()` | attestations (`attestation.rs:210,262,294,347`), nonces, claves BLS |
| `mock_all_auths` / `mock_auths` (tests) | 10 archivos / 4 archivos |

Los schemas se guardan en `instance()` y sin `extend_ttl`; las attestations en `persistent()` y sin `extend_ttl`.

## Nombres de la API (SDK/CLI) que difirieron del enunciado

- `stellar network settings` devuelve JSON XDR (`--output json-formatted`). Los nombres de campo son `tx_max_footprint_entries`, `tx_max_write_ledger_entries`, `contract_max_size_bytes`, etc.
- El enunciado decía `getVersionInfo`/`getNetwork`: ambos existen en el RPC de testnet (`getVersionInfo` devuelve `protocolVersion: 30`).
- `stellar keys generate <alias> --network testnet --fund` funciona tal cual.

## Documentación que contradijo al código

Nada nuevo respecto a [LEEME.md, sección 2](../../LEEME.md). Se añade que los ficheros `audit/*.md` se presentan como "audit" pero son diseño y STRIDE del propio equipo.

## Decisión para la especificación

- No afirmar "auditado" en el SOW (ver arriba).
- Cualquier compilación del sprint debe ser `stellar contract build`; el repo ya lo hace.
- Subir a `soroban-sdk 29.x` es viable en términos de compilación; las pruebas necesitan quitar el `protocol_version: 27` fijo. Decidir en el Sprint 1 si el fork limpio nace directamente en SDK 29.
- Mantener `schema_definition` con tope y `initialize` atómico (o `__constructor`) en el diseño propio.

## Costos o tiempos medidos

- `cargo test --workspace` (primera vez, con descarga): 3 min 10 s reales.
- `protocol.wasm` 34.287 bytes (SDK 27.0.6) y 30.995 bytes (SDK 29.0.1, otro `target`); `resolvers` 3.542 bytes.
- Costos de transacción: no medidos en este ejercicio (friendbot fondeó 3 cuentas).

## Preguntas abiertas

1. ¿Existe el informe externo (Halborn u otro) detrás de `HAL-01..08`? Pedirlo a Daccred antes de hablar de auditoría en el SOW.
2. ¿Cuál es el estado de mainnet (límites)? Hace falta un proveedor RPC propio para `stellar network settings --network mainnet`.
3. ¿El fork limpio del sprint debe nacer en `soroban-sdk 29.x` (P29 vigente en mainnet, P30 ya en testnet)?
4. ¿Cuándo se activa CAP-88 (cierre en milisegundos)? Hoy testnet cierra cada 5 s; afecta la conversión TTL ↔ tiempo en el ejercicio 02.

## Respuestas a las preguntas de comprensión

1. El CLI v30 solo orquesta compilación y despliegue; la compatibilidad de ABI la fija el protocolo y la versión de `soroban-env` con la que se compiló el Wasm. Un Wasm de SDK 27 sigue ejecutándose en una red P29/P30. Lo que se rompe es la reproducibilidad de *pruebas* que fijan versiones de protocolo (ver "Qué falló", punto 1).
2. En este repo no hay diferencia: `make build` llama a `stellar contract build`. Lo que cambia entre SDK <28 y ≥28 es que un `cargo build` directo a Wasm deja de ser válido; el CLI quita entradas de la especificación después de compilar.
3. Que probar en testnet no garantiza lo mismo en mainnet: hoy P30 contra P29. Hay que repetir las mediciones en el protocolo en que se desplegará (por eso la re-medición tras el 2026-11-23 en el ejercicio 99).
