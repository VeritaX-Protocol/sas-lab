# Resumen del laboratorio sas-lab

Cierre de los ejercicios 00 a 04. Insumo del documento de decisiones de diseño del Entregable 2 y del borrador del Entregable 3. Escrito el 2026-11-12, cuatro días antes del inicio del Sprint 1 (2026-11-16).

**Cómo leerlo.** No repite las notas: cada decisión remite a su `NOTA.md`. Todas las cifras son de **testnet, Protocolo 30, cierre de ledger de 5 s**, medidas entre el 2026-11-11 y el 2026-11-12 (ledgers 5.680.335 a 5.699.263); en cada fila va la nota donde está la fecha y el ledger exactos. **Nada se midió en mainnet** (hoy en Protocolo 29). Base de código: `daccred/attestprotocol` en `c0c4529`, `soroban-sdk 27.0.6`, stellar CLI 30.0.1.

## 1. Una línea por ejercicio

| # | Qué se probó | Conclusión | Nota |
|---|---|---|---|
| 00 | Toolchain, línea base y respaldo de auditoría | Compila y pasa 79 pruebas con el toolchain actual; **no hay auditoría de terceros sobre el código desplegado**; sin `extend_ttl` ni función de upgrade | [00](00-toolchain/NOTA.md) |
| 01 | Ciclo completo en testnet y 5 hipótesis | Funciona sin resolver; **el resolver por defecto impide emitir en directo**; subject = emisor; cualquiera emite; `definition` sin validar | [01](01-attest-protocol-testnet/NOTA.md) |
| 02 | TTL real, renta, techo de `instance` | **Todo vive 7 días sin `extend_ttl`**; con él, 180 días; el costo fijo grande es el Wasm (≈ 37 XLM por 180 días); schemas en `instance` tienen techo de 29 a ≈ 207 | [02](02-almacenamiento-ttl/NOTA.md) |
| 03 | Costo por tamaño de `value` | **99,6 % del costo es renta** (≈ 0,25 XLM por KB por 180 días); la simulación no ve el límite real de ≈ 16 KB | [03](03-costos-tamano/NOTA.md) |
| 04 | Autorización, lista de emisores, revocación, upgrade | Lista en el núcleo (+10 % CPU, frente a +62 % con resolver); upgrade v1 → v2 funciona; **el contrato heredado no se puede actualizar** | [04](04-autorizacion-emisores-upgrade/NOTA.md) |

## 2. Decisiones para la especificación

| Tema | Decisión propuesta | Evidencia |
|---|---|---|
| Dónde van schemas y registros | **Todo en `persistent`, una clave por schema.** Nada de schemas en `instance` | 02: techo de 29 schemas de 2 KB; `attest` 26× más CPU con 200 schemas |
| Renovación | `extend_ttl` al escribir; **función pública `extend_attestation_ttl`**; renovar cada ≈ 150 días; sin bump al leer (las lecturas son simulaciones) | 02: renovar 29 días cuesta 0,0201 XLM ≈ 0,25 XLM por año |
| Quién paga | **Sin decidir.** Opciones: VeritaX, la entidad emisora o un fondo común. Hay que fijarlo antes de los pilotos | 02 (pregunta abierta 5) |
| Wasm e instancia | Mantenimiento programado y separado del primer `register` de un usuario | 02: ≈ 37 XLM por 180 días; 04: el Wasm nuevo tras un upgrade cuesta ≈ 43 XLM extender |
| Lista de emisores | **En el núcleo**, por schema, **cerrada por defecto**, la autoridad entra como primer emisor al registrar | 04: +0,0011 XLM por emisión; el resolver aparte +62 % CPU |
| Quién revoca | **El emisor original y la autoridad del schema**; el admin solo retira emisores. Revocación universal del admin queda descartada (una llave invalidaría todo) | 04 (no implementado; el prototipo v2 da la revocación al admin) |
| Forma de `value` | **`String` JSON compacto** con claves cortas; tipar no abarata (el struct con campos ocupa más); la tupla ahorra ≈ 0,01 XLM | 03 |
| Destinatario | `holder_hash = sha256(documento ‖ sal)` dentro de `value`; sin datos personales en la cadena | 01 y 04 |
| Topes iniciales | `value` ≤ 512 B (duro 1.024 B), ≤ 8 campos, ≤ 128 B por campo, `definition` ≤ 1 KB; presupuesto ≈ 0,8 XLM por emisión | 03 |
| Validaciones | `expiration_time` en segundos y dentro de un rango (los ms pasan en silencio); tope de `schema_definition` | 01, 00 |
| Upgrade | **Incluir `upgrade` desde v1** (el heredado no la tiene), `admin` como cuenta multisig, claves de enum nuevas **al final** y errores sin renumerar; no tocar structs guardados (crear clave `V2`) | 04 |
| `initialize` | Atómico con el despliegue (`__constructor`): hoy el primero que llama se queda con el contrato | 04 (probado en Rust; el constructor no se probó) |
| Versión del SDK | Decidir en el Sprint 1 si el fork nace en `soroban-sdk 29`: compila; las pruebas fijan `protocol_version: 27` | 00 |

## 3. Qué se toma, de dónde y qué se deja fuera

| Fuente | Se toma | Evidencia |
|---|---|---|
| **Attest Protocol** | Estructura `no_std`, errores tipados, eventos, guardia de `initialize`, `checked_add`, generación de UID, lógica de revocación, `testutils.rs`, perfil `release` | 00 (79 pruebas verdes), 01 (17 casos coinciden con el código) |
| **EAS** (`eas-lab`) | `refUID` para enlazar versiones de schema; `revocable = true` siempre; el verificador traduce errores; "no encontrado" no equivale a "falso" | `eas-lab/resultados/07-emision-directa/NOTA.md`, `03-lectura-verificacion/NOTA.md`. **No re-verificado aquí**; en Soroban "no encontrado" es el error #5 (01) |
| **Se deja fuera** | Delegación BLS, nonces de revocador, contratos de Solana, SDK y apps, fork limpio (es del sprint) | LEEME sección 1 |

## 4. Hallazgos que contradicen la documentación o el análisis previo

| Qué se decía | Qué es | Dónde |
|---|---|---|
| El SDK de la doc acepta `subject` en `attest` | El contrato lo fija al emisor | `attestation.rs:167`; [01](01-attest-protocol-testnet/NOTA.md) |
| La emisión directa con resolver funciona | El resolver por defecto la rechaza (`default.rs:20`): #24 con #7 dentro | 01, `32-attest-con-resolver` |
| Schemas, attestations y authorities en `persistent` (doc) | **Schemas en `instance`** (`schema.rs:21,95,106`) | [02](02-almacenamiento-ttl/NOTA.md), tabla de 11 filas |
| «Data survives contract upgrades», sin mención de TTL | Sin `extend_ttl`, todo vive 7 días; **la doc no menciona TTL, archivado ni renta** | 02 |
| Una attestation vencida «sigue consultable» | `get_attestation` falla con #22 (probado en testnet); sigue en storage y se puede revocar | 02 |
| Error enum de 11 variantes, `pay_verification_fee`, 100 XLM | ≈ 30 códigos con otros nombres; esas funciones no existen en este contrato | 02 |
| `expiration_time` en ms (ejemplo) | Segundos; los ms se aceptan y no vencen nunca | 01 |
| El análisis decía que Scout y Halborn eran auditorías | Escáneres automáticos; **no hay informe de Halborn en el repo** | [00](00-toolchain/NOTA.md) |
| La restauración de entradas archivadas es manual | Es casi siempre automática (CAP-66) | 02; **la prueba real queda para el 2026-11-18** |
| Límites del análisis (128 KB, 400/200 entradas, 132.096 B) | Coinciden con testnet | 00 |

Lo que sí es fiable en la doc: structs, campos, firmas de funciones y tamaños BLS (02, filas 9 y 10).

## 5. Qué se puede afirmar en el SOW sobre auditorías

- **No escribir «contrato auditado».**
- Sí, con evidencia: *«base de código abierto (MIT), mantenida, con escaneos automáticos publicados (Almanax, CoinFabrik Scout), correcciones posteriores referenciadas a hallazgos de una revisión externa cuyo informe no está en el repositorio, y desplegada en mainnet»* (00).
- Los informes son de 2025-11-07 y 2025-12-01; el v2 se desplegó en mainnet el 2026-08-31, después de todos ellos; entre el commit escaneado y `c0c4529` hay 30 commits.
- Para citar una auditoría hay que **pedir a Daccred el informe** detrás de `HAL-01..08`.

## 6. Riesgos abiertos

| Riesgo | Estado |
|---|---|
| **TTL máximo y quién renueva** | Máximo 3.110.400 ledgers (≈ 180 días). «Para siempre» no existe: es una promesa de renovar. Falta decidir quién paga y cada cuánto (02) |
| **Llave de emisor perdida** | Hoy nadie puede revocar por ese emisor; propuesta: la autoridad del schema revoca (04) |
| **Llave de admin robada** | Con `upgrade` quien la tenga sube cualquier Wasm. Mitigación: multisig, hardware y timelock; **sin implementar** (04) |
| **Protocolo 30 y el TTL** | Si el cierre se acorta y el TTL máximo sigue en ledgers, dura menos tiempo real y mantener cuesta más por año. El ajuste existe (`scp_timing`, hoy 5.000 ms); los escenarios 2,5 s y 1 s del 03 son **hipótesis mías** |
| **Project Thruput y tarifas** | Los costos son una foto de hoy; SLP-0007 ya bajó tarifas en mainnet el 2026-10-22. **No usar las cifras en el SOW** (03) |
| **Testnet no durable** | El contrato de `deployments.json` sigue vivo hoy, pero no se depende de él; la evidencia se regenera al final |
| **Archivado del Wasm** | Si vence el Wasm o la instancia se bloquean todas las llamadas hasta restaurar; sin medir el costo real de restaurar (02, pendiente) |
| **CAP-0077 (congelar entradas por configuración)** | Riesgo remoto citado por la revisión previa; **no se verificó** en el laboratorio |
| **Límite de eventos** | `value` > ≈ 16 KB falla al enviar aunque la simulación pase (03) |

## 7. Re-medición pendiente

| Cuándo | Qué | Cómo |
|---|---|---|
| **2026-11-18, después de las 20:50 UTC** | Restauración real: qué devuelve la lectura de una attestation archivada y cuánto cuesta restaurar | `02-almacenamiento-ttl/scripts/restaurar.sh` |
| **2026-11-23, después de las 17:00 UTC** | Repetir con mainnet en P30: TTL de las entradas, costo de emitir y renovar, `scp_timing`, `max_entry_ttl`. Anotar diferencias | `02/scripts/ejecutar.sh rama extender` y `03/scripts/ejecutar.sh sim enviar informe` |
| Cuando haya RPC propio | `stellar network settings --network mainnet` (el CLI público no lo permite) | 00 |

Sin esa re-medición, **ninguna cifra de este resumen debe pasar al SOW como definitiva**.

## 8. Preguntas abiertas para el sprint

1. ¿Quién paga la renovación: VeritaX, la entidad o un fondo común? (02)
2. ¿Qué devuelve una lectura de una attestation archivada y cuánto cuesta restaurarla? (02, 18-nov)
3. ¿Qué límite exacto dispara el fallo de ≈ 16 KB? ¿Es el de eventos? (03)
4. ¿Por qué emitir sin expiración cuesta más que con ella (0,0085 frente a 0,0069 XLM)? No se investigó (01)
5. ¿`__constructor` evita el secuestro de `initialize`? ¿`stellar contract extend --wasm-hash` extiende el Wasm tras el upgrade? (04)
6. ¿Cómo se organiza el admin real (multisig, hardware) y quién guarda las llaves? ¿Hace falta timelock? (04)
7. ¿Cuántos emisores caben por schema y cuánto cuesta `attest` con cientos? (04)
8. ¿El fork nace en `soroban-sdk 29`? (00)
9. ¿Existe el informe externo detrás de `HAL-01..08`? (00)
10. ¿Cuál es el cierre de ledger de mainnet tras el voto del 2026-11-23? (00, 03)
11. ¿La revocación con un resolver pasa por `onrevoke`? No se pudo probar porque emitir con resolver falla (01)

## 9. Acciones para el Día 1 del sprint (2026-11-16)

1. **Pedir a Daccred el informe externo** y decidir cómo se redacta lo de auditoría en el SOW.
2. **Empezar el fork con estas piezas desde la primera versión:** `upgrade` con admin multisig, `__constructor`, lista de emisores cerrada por defecto en el núcleo, schemas y registros en `persistent` con `extend_ttl`, función pública de renovación, topes de tamaño y rango de `expiration_time`, errores y variantes nuevas solo al final.
3. **Fijar la política de renovación** (quién paga, cada cuánto) y el proceso que mantiene vivos el Wasm y la instancia.
4. **Decidir la política de revocación** (autoridad del schema, no admin global).
5. **Decidir el SDK** (27 o 29) y arreglar el `protocol_version` fijo de las pruebas si se sube.
6. **Poner en el calendario** las dos re-mediciones (18 y 23 de noviembre) y conseguir un RPC propio para leer los ajustes de mainnet.
7. **Probar lo que quedó sin probar:** `__constructor`, `stellar contract extend --wasm-hash` y el tamaño máximo de la lista de emisores (media jornada).

## Dónde está cada cosa

- Reglas y plan: [../LEEME.md](../LEEME.md). Enunciados: [../ejercicios/](../ejercicios/). Estado: [../README.md](../README.md).
- Informes con tablas completas: `NN-*/informe.md`. Evidencia (hashes de transacción): en cada informe.
- El laboratorio es **conceptual**; los contratos de `attestprotocol-*` son prototipos para medir, no el contrato del sprint.
