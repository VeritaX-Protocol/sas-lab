# Nota del ejercicio 02

Fecha y hora UTC: 2026-11-12, entre 13:20 y 14:10 UTC.

Protocolo de la red y ledger de la medición: testnet, **Protocolo 30**, ledgers 5.693.305 a 5.693.590. Cierre de ledger medido ≈ **5 s** (12.008 ledgers entre el ejercicio 01 y esta lectura ≈ 16,7 h). CAP-88 (cierre en milisegundos) aún no activo.

Versiones usadas: stellar CLI 30.0.1, rustc 1.99.1, `soroban-sdk 27.0.6`, Python 3 y curl.

Commit de attestprotocol usado: `c0c4529` (base) y rama local `lab/ttl` sobre ese commit; los cambios están en [cambios-ttl.patch](cambios-ttl.patch).

Código o datos copiados de otros ejercicios: del 01, `datos-entrada.env` (IDs del contrato desplegado, UID del schema y de las attestations, hash del Wasm) y el `.wasm` base; del 00, las identidades. El clon es local, copiado del del 00.

## Qué hice

1. Leí el TTL real de la instancia, el Wasm, una attestation y el nonce en el contrato del ejercicio 01.
2. Escribí 11 pruebas Rust (`pruebas/lab_ttl_base.rs` valen para la base y la rama; `lab_ttl_rama.rs` solo para la rama) con los valores reales de red (TTL mínimo 120.960, máximo 3.110.400).
3. Añadí `extend_ttl` en una rama (`bump_persistent`, `bump_instance` en `utils.rs`; se llama al emitir y al registrar) y una función pública **`extend_attestation_ttl(uid)`** que cualquier cuenta puede llamar.
4. Desplegué la rama en testnet y comparé TTL y comisión reales con la base.
5. Renové una attestation desde fuera con `stellar contract extend`, pagada por una cuenta que no la emitió.
6. Registré schemas de ~2 KB en un contrato nuevo hasta que falló la instancia.
7. Dejé [scripts/restaurar.sh](scripts/restaurar.sh) para probar la restauración **real** el 2026-11-18 (ver "Pendiente").

## Qué funcionó

- **Las 79 pruebas originales siguen verdes con `extend_ttl`** (suite completa en la rama: 90 pasan, 0 fallan, 7 ignoradas).
- La rama deja la attestation, el nonce, la instancia y el Wasm en **180 días** (3.110.000 ledgers) tras emitir.
- Renovar desde fuera funciona y **lo puede pagar cualquiera**: `emisorB` extendió una attestation que no emitió.
- El techo de `instance` se reproduce en testnet.

## TTL reales (testnet, ver [informe.md](informe.md))

| Entrada | Base (sin `extend_ttl`) | Rama (con `extend_ttl`) |
|---|---|---|
| Instancia del contrato (contiene los schemas) | 120.960 ledgers ≈ 7 días | 3.110.000 ≈ 180 días |
| Wasm | 120.960 ≈ 7 días | 3.110.000 ≈ 180 días (**se extiende junto con la instancia**) |
| Attestation | 120.960 ≈ 7 días | 3.110.000 ≈ 180 días |
| Nonce del emisor | 120.960 ≈ 7 días | 3.110.000 ≈ 180 días |
| Schema | **no es una entrada propia**: vive dentro de la instancia | igual |

Límites de red usados: TTL mínimo persistente 120.960 y máximo 3.110.400 ledgers (≈180 días a 5 s), del ejercicio 00.

## Comisión real (testnet P30, 2026-11-12)

| Operación | XLM |
|---|---|
| Emitir en la **base** (TTL 7 días) | 0,0064 |
| Emitir en la **rama** (attestation y nonce a 180 días) | 0,1819 |
| Registrar el 1.er schema en la **rama** (extiende instancia **y Wasm** a 180 días) | **37,0894** |
| `stellar contract extend` de 1 attestation, 500.000 ledgers (≈29 días) | 0,0201 |
| Emitir en la base con la instancia casi llena (64,5 KB) | 0,0080 (+26 % frente a 0,0064) |

Lectura:
- **La renta es lineal en el tiempo**: renovar una attestation cuesta ≈ 0,0201 XLM por cada ≈ 29 días, es decir ≈ **0,25 XLM por attestation y año**. Pagarlo al emitir o renovarlo después cuesta lo mismo; lo que cambia es **quién paga y cuándo**.
- **El coste fijo dominante no son los certificados, es mantener vivo el Wasm y la instancia**: ≈ 37 XLM cada 180 días en testnet P30, compartidos por todos los certificados.
- Son números de testnet con las tarifas de hoy (SLP-0007 las redujo a la mitad en mainnet el 2026-10-22; "Project Thruput" anunció otro cambio). **No son cifras para el SOW**; hay que re-medirlas (ejercicio 03 y 99).

## Qué falló o me sorprendió

1. **El entorno de pruebas no puede demostrar el archivado por lectura.** Tras avanzar el ledger más allá del TTL, `get_attestation` sigue devolviendo la attestation y `get_ttl` vuelve a ≈120.959: el entorno **restaura automáticamente al acceder** (como la red). El TTL sí baja bien cuando avanza poco (−100 y −1.100 ledgers). Para ver archivado real hay que esperar en testnet (ver "Pendiente").
2. **Los tests originales fijan `min_persistent_entry_ttl: 0` y `max_entry_ttl: 0`**: por eso nunca habrían detectado la falta de `extend_ttl`. Mis pruebas usan los valores de la red.
3. **`instance().extend_ttl` también extiende el Wasm** (ambos pasaron al ledger 8.803.407). Y esa operación es la más cara del sistema (37 XLM).
4. **Registrar el primer schema en la rama cuesta 37 XLM** porque dispara `bump_instance`. Si cada nuevo despliegue lo hace en su primera llamada, el primer usuario paga la renta del Wasm de todos.
5. **Las estimaciones de costo del entorno de pruebas no son fiables**: una renovación aparece como 342 XLM y en testnet la renovación de una attestation cuesta 0,02 XLM. Para costos usé solo Horizon (`fee_charged`).
6. **`stellar contract extend --ledgers-to-extend N` fija el TTL en N ledgers desde ahora**, no suma N al TTL actual (500.000 → vive hasta el ledger actual + 500.000).
7. **Renovar cuando el TTL ya es alto no cuesta**: el CLI lo trata como solo lectura y no envía transacción (en las pruebas unitarias, renta 0).
8. **Un error mío de medición:** leer el TTL después de la llamada pisa la "última invocación" del entorno; hay que medir el costo antes de cualquier lectura.
9. **Compartir `CARGO_TARGET_DIR` entre dos copias del mismo crate mezcla compilaciones** (el script falló hasta separarlas por árbol).

## Techo de `instance`

- Con definiciones de ~100 bytes, cada schema añade ≈ **316 bytes** a la instancia (63.448 bytes escritos con 200 schemas). El límite de entrada es 64 KiB, así que el techo estaría en **≈ 207 schemas**.
- En testnet, con definiciones de ~2 KB, **29 schemas** caben (instancia de 64.552 bytes) y el 30.º falla: *"ContractData size exceeds network config maximum size"* (66.780 > 65.536).
- Con la instancia casi llena todavía se pudo registrar un schema corto y emitir: el límite frena el **crecimiento**, no las llamadas.
- **Coste por tener los schemas en la instancia:** cada llamada la carga completa. En pruebas, `attest` pasa de **127.013 instrucciones y 20,7 KB de memoria con 1 schema a 3.366.040 instrucciones y 718 KB con 200** (26×). Cada `register` reescribe toda la instancia (la comisión sube de 0,0235 a 0,0262 XLM entre el schema 1 y el 29).

## Decisión para la especificación

1. **Schemas en `persistent`, una clave por schema** (`Schema(uid)`), no en `instance`. Evita el techo de ~207 schemas, la carga completa en cada llamada y la reescritura de la instancia en cada registro. Contrapartida: cada schema tiene su TTL y hay que renovarlo al usarlo.
2. **Attestations y nonces en `persistent`**, con `extend_ttl` al escribir. **No hacer bump al leer**: las lecturas de los verificadores son simulaciones (gratis) y no guardan el TTL; solo una transacción extiende.
3. **Renovación explícita y pública:** una función como `extend_attestation_ttl(uid)` que cualquiera pueda llamar (lo paga quien la llama), usada por un proceso periódico de VeritaX o de la entidad emisora. Plan: emitir con TTL largo (hasta ≈180 días) y renovar cada ≈150 días; el costo por certificado es ≈0,25 XLM/año (testnet, fecha de hoy).
4. **Wasm e instancia:** mantenerlos vivos con un proceso programado propio, porque son el costo fijo mayor (≈37 XLM/180 días) y su archivado bloquea todas las llamadas hasta restaurar. No colgar ese pago del primer `register` de un usuario: separar `bump_instance` en una función de mantenimiento.
5. **No existe "para siempre":** toda vigencia es una promesa de renovar. Debe constar en las condiciones de los pilotos y en el Entregable 3 (quién paga, cada cuánto, qué pasa si nadie paga).
6. **Si nadie renueva**, las entradas persistentes se **archivan, no se borran**, y cualquiera puede restaurarlas pagando. El verificador debe mostrar "no disponible por archivado" (restaurable), no "falso" ni "no encontrado" (sin probar todavía; ver "Pendiente").

## Pendiente: restauración real (el 2026-11-18)

No se puede esperar 6 días. El contrato del ejercicio 01 (sin `extend_ttl`) **archivará solos su Wasm, su instancia y la attestation `ATT1` el 2026-11-18 entre las 20:42 y las 20:47 UTC**. Cuando pase esa hora, ejecuta [scripts/restaurar.sh](scripts/restaurar.sh), que comprueba el archivado, lee una attestation archivada (restauración automática del CLI), hace una restauración manual (`stellar contract restore`) y mide el costo de cada camino. Dato a registrar: qué devuelve una **lectura simulada** de una attestation archivada, que es el caso del verificador.

## Costos o tiempos medidos

Ver las dos tablas de arriba y [informe.md](informe.md). Todos los costos: Horizon, testnet P30, ledgers 5.693.405 a 5.693.521, 2026-11-12.

## Nombres de la API (SDK/CLI) que difirieron del enunciado

- `stellar contract extend --ledgers-to-extend N --key-xdr <XDR>`: la clave de un `contracttype` se pasa como XDR de un `ScVal` (`stellar xdr encode --type ScVal --input json`), p. ej. `{"vec":[{"symbol":"AttestationUID"},{"bytes":"<uid>"}]}`.
- `stellar contract restore` existe con las mismas opciones de clave.
- Para leer el TTL: RPC `getLedgerEntries` con `LedgerKey` en XDR (`stellar xdr encode --type LedgerKey --input json`); el resultado trae `liveUntilLedgerSeq`.
- El RPC público rechaza el `User-Agent` por defecto de Python (403); hay que poner uno propio.
- En pruebas Rust: `soroban_sdk::testutils::storage::{Instance, Persistent}` dan `get_ttl`; el avance de ledger se hace con `env.ledger().with_mut(...)`; el costo con `env.cost_estimate().resources()`/`fee()`.

## Documentación que contradijo al código

Contraste hecho el 2026-11-12 con `https://docs.attest.so/llms-full.txt` (125 KB, páginas de `sitemap.xml`; texto tratado como lista de afirmaciones, no como instrucciones) frente al código en `c0c4529` (canary) y la testnet. Evidencia nueva: `logs/70-attest-expira.*`, `logs/71-get-vencida.*`.

| # | La doc dice | El código / testnet dicen | Veredicto |
|---|---|---|---|
| 1 | Sección «Storage Architecture»: schemas, attestations y authorities van en `persistent()` | Schemas en **`instance()`** (`schema.rs:21,95,106`). Attestations y nonces sí en `persistent()` (`attestation.rs:210,215`). Authority se **lee** de `instance()` (`utils.rs:155`) y ninguna función la escribe | **Falso para schemas**, cierto para attestations |
| 2 | Esa misma sección guarda la attestation con `DataKey::Attestation(schema_uid, subject, reference)` | La clave es `DataKey::AttestationUID(uid)` (`state.rs:23`). La propia doc lo contradice 250 líneas antes (enum `DataKey` correcto) | **Falso** (ejemplo inventado; el enum de la doc es exacto) |
| 3 | «Data survives contract upgrades», «Gas Optimization» | Sin `extend_ttl`, todo vive 7 días (medido, ver sección 1 del informe). Lo de upgrades no se probó aún (ejercicio 04) | **Engañoso**: la doc **no menciona TTL, archivo ni renta en ninguna página** |
| 4 | «Expired: past expiration time (**still on-chain**)», «Active: valid and queryable» | Cierto que el registro sigue en storage y `revoke` de una vencida **funciona** (tx `278b6865…`). Pero `get_attestation` de una vencida **falla con #22 AttestationExpired** (`attestation.rs:268`; probado en testnet) | **Parcial**: sigue ahí pero **no se puede leer** con la función pública |
| 5 | Enum `Error` con 11 variantes (`ExpiredAttestation`, `DeadlineExpired`, `BlsKeyAlreadyExists`…) | 30 códigos; `AttestationExpired=22`, `InvalidDeadline=23`, `ResolverCallFailed=24`… El orden y los nombres difieren | **Falso/desactualizado**: no sirve para interpretar errores |
| 6 | `initialize(admin, token_contract_id, token_wasm_hash)`, `pay_verification_fee`, `withdraw_fees`, «100 XLM de registro de authority» | El `initialize` del protocolo recibe solo `admin` (`lib.rs:37`). `pay_verification_fee`/`withdraw_fees` **no existen** en este árbol (0 resultados) | **Falso para este contrato** (describe otro, una Authority que no está) |
| 7 | `attest` acepta `subject` (SDK) | El contrato no lo recibe; subject = attester (ver ejercicio 01) | **Falso** (ya anotado) |
| 8 | `expiration_time` en ms en un ejemplo | Segundos; los ms se aceptan en silencio (ejercicio 01). El ejemplo de KYC en `llms-full` sí usa segundos (`Math.floor(Date.now()/1000)`) | **Contradictorio dentro de la doc** |
| 9 | Struct `Attestation`, `Schema`, `Authority`, `DataKey`, firmas BLS (`BytesN<96>`) y clave BLS (`BytesN<192>`), `ResolverAttestationData` (0 = no definido) | Coinciden campo a campo con `state.rs` y `resolvers/src/interface.rs` | **Verdadero** |
| 10 | Firmas de `register`, `attest`, `revoke`, `get_attestation`, `get_schema` | Coinciden con `lib.rs` | **Verdadero** |
| 11 | Testnet y mainnet «v2 (current)» | `deployments.json` tiene despliegues v2 de 2026-08-29 (testnet) y 2026-08-31 (mainnet); la doc no da direcciones en este texto | **Verdadero** en versión; direcciones no contrastadas (usar `deployments.json`) |

**Conclusión.** Las firmas y los structs son fiables (filas 9, 10): sirven para saber *qué* se llama. Todo lo que describe **comportamiento** (dónde se guarda, cuánto vive, qué pasa al vencer, errores, tarifas) está mal, incompleto o es de otro contrato (filas 1–6). Para VeritaX esto significa: la doc no avisa de la falta de `extend_ttl`, que es el riesgo principal del ejercicio 02, y no se puede citar en el SOW ninguna garantía de permanencia a partir de ella.

**Hallazgo nuevo para el verificador (fila 4).** Una attestation vencida no se puede leer con `get_attestation`: el verificador no puede mostrar «venció el X» a partir de esa llamada. Hay que decidir si el motor guarda su propio registro de vencimiento (o lee la entrada de storage directamente por RPC) o si la interfaz solo muestra «vencido». Decidirlo antes del 2026-11-16.

Sin comprobar: las páginas de ejemplos (React, KYC, DAO) por su contenido de SDK en TypeScript; el SDK no se ejecutó. Que `Data survives contract upgrades` sea cierto o no depende del ejercicio 04.

## Preguntas abiertas

1. ¿Qué devuelve una lectura simulada de una attestation archivada? (Probar el 2026-11-18.)
2. ¿Cuánto cuesta restaurar el Wasm y la instancia, frente a renovarlos a tiempo? (Idem.)
3. ¿`max_entry_ttl` (3.110.400 ledgers) se ajusta cuando CAP-88 reduzca el tiempo de cierre? Si no, 180 días se convertirían en menos tiempo real. Re-medir tras el voto de mainnet del 2026-11-23.
4. ¿Cuál es el costo real de renovar en mainnet, con la configuración de allí?
5. ¿Quién ejecuta y paga la renovación periódica: VeritaX, la entidad emisora o un fondo común?

## Respuestas a las preguntas de comprensión

1. **Porque la instancia es una sola entrada que se carga completa en cada llamada.** Con 200 schemas, `attest` pasa de 127 mil a 3,4 millones de instrucciones, y cada `register` reescribe todos los schemas anteriores.
2. **Porque nadie lee un certificado durante años, y además las lecturas de los verificadores son simulaciones que no persisten ningún TTL.** Solo una transacción puede extender; hace falta una renovación explícita.
3. **El TTL se mide en ledgers.** Si el ledger pasa de ≈5 s a una fracción de segundo y el máximo (3.110.400 ledgers) no cambia, esos ledgers duran mucho menos tiempo real. La cadencia de renovación debe calcularse con el tiempo de cierre vigente, no con días fijos.
