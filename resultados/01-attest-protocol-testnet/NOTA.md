# Nota del ejercicio 01

Fecha y hora UTC: 2026-11-11, entre 20:40 y 20:50 UTC.

Protocolo de la red y ledger de la medición: testnet, **Protocolo 30**, ledgers 5.681.274 a 5.681.297 (cierre de ledger de 5 s; CAP-88 aún no activo).

Versiones usadas: stellar CLI 30.0.1; contrato `soroban-sdk 27.0.6` (Wasm compilado en el ejercicio 00); Python 3 y curl para el informe.

Commit de attestprotocol usado: `c0c4529`. Los `.wasm` desplegados son los del ejercicio 00, con sus hashes en [wasm/SHA256.txt](wasm/SHA256.txt) (`protocol.wasm` `a3b2dfce…`, `resolvers-default.wasm` `33da5f8a…`).

Código o datos copiados de otros ejercicios: del 00, los dos `.wasm` y las tres identidades de testnet (`admin`, `emisorA`, `emisorB`, solo por alias; no se copiaron claves). El clon `attestprotocol/` es un clon local del del 00 fijado en `c0c4529`.

## Qué hice

Desplegué el protocolo y el resolver por defecto con `admin`, inicialicé el protocolo, y ejecuté con `scripts/ejecutar.sh` el ciclo completo: 5 schemas, 7 emisiones, 3 consultas, 4 revocaciones y la lectura de eventos. Cada operación queda en [evidencia.md](evidencia.md) con su hash y enlace a stellar.expert, y el resumen en [informe.md](informe.md).

Contratos del despliegue de referencia (testnet):
- Protocolo: `CBVXDFQGP7EO7ZQOXAOWFNMFB5DALX7Y5OGGGWVBVQ6ZUBSCD5GNRASO`
- Resolver por defecto: `CDAEYUDIW44R4VWX4VJVIVWXJJ7NV3OR6AKD3IOVOJWOSOD4CCDYFUAI`

(Hubo antes un primer despliegue de prueba, `CB7ROIUU…ZHLZ`, que se abandonó porque mi primer script tenía un error con el argumento `resolver`. No forma parte de la evidencia.)

## Qué funcionó

- **Ciclo completo sin resolver:** registrar, emitir, consultar y revocar funcionan. Los 17 casos probados coinciden con lo que predice el código.
- **Eventos:** 12 en total, uno por operación exitosa: `CONTRACT/INIT` (1), `SCHEMA/REGISTER` (5), `ATTEST/CREATE` (5) y `ATTEST/REVOKE` (1). Las operaciones que fallan no emiten eventos.
- **Guardias:** `initialize` repetido falla (#13); registrar un schema duplicado falla (#28); consultar un UID inexistente da #5; revocar con otra cuenta da #6; revocar dos veces da #29; revocar en un schema no revocable da #15.

## Hipótesis a verificar (todas resueltas)

| Hipótesis | Veredicto | Evidencia |
|---|---|---|
| La emisión directa con el resolver por defecto siempre falla | **Confirmada** | `32-attest-con-resolver`: error **#24 ResolverCallFailed**. El diagnóstico muestra que el resolver respondió **#7 ValidationFailed** en `onattest`: la regla `attester == recipient` de `resolvers/src/default.rs:20`, y en emisión directa `recipient` es siempre el emisor. Sin resolver, el mismo `attest` pasa (`31`) |
| `subject` siempre es el emisor | **Confirmada** | `get_attestation` devuelve `subject == attester` (`attestation.rs:167`) |
| Qué unidad usa `expiration_time` | **Segundos Unix** | Se compara con `env.ledger().timestamp()`. Una expiración en **milisegundos se acepta en silencio** y equivale a ≈ el año 58.833 |
| Una expiración en el pasado se rechaza | **Sí** | `35`: #23 InvalidDeadline |
| Cualquier cuenta puede emitir si no hay resolver | **Sí** | `37`: `emisorB`, no autorizado, emitió sin problema |

## Qué falló o me sorprendió

1. **El contrato no valida `definition`.** `schema.rs` no tiene ninguna comprobación de longitud ni de formato (el error `InvalidSchemaDefinition` #16 existe pero no se usa en `schema.rs`). Se aceptaron las tres sintaxis de la documentación (`curso:string,asistio:bool`, `struct Cert { ... }` y `string curso, bool asistio`) y cualquier otro texto. **El contrato no distingue entre ellas**: son solo texto que se guarda y se hashea para el UID. La "sintaxis aceptada" depende de quien lea el schema (SDK o verificador), no del contrato.
2. **El resolver por defecto es inutilizable para emisión directa.** Con él, solo funcionaría la ruta delegada (BLS), que VeritaX deja fuera. Para el motor propio no sirve como resolver.
3. **La expiración en milisegundos no da error.** Es una trampa silenciosa: un certificado "con vencimiento" puede quedar sin vencimiento efectivo.
4. **Mi script falló dos veces por el CLI, no por el contrato:** `Option<Address>` debe pasarse entre comillas JSON (`--resolver "\"C…\""`). Anotado en "Nombres de la API".
5. **Los errores no se envían:** las operaciones que fallan lo hacen en la simulación, antes de enviarse, así que no gastan comisión ni dejan hash.

## Contrato publicado en `deployments.json`

El contrato testnet `CA2QET2K…RAUCD` **sigue vivo hoy** (responde `get_schema` con #3 SchemaNotFound para un UID de ceros). Aun así, testnet no es durable, así que no se depende de él.

## Nombres de la API (SDK/CLI) que difirieron del enunciado

- `stellar contract invoke ... -- <fn> --<arg> <valor>`: los nombres de argumento son los del contrato (`--attester`, `--schema_uid`, `--attestation_uid`, `--expiration_time`, `--schema_definition`, `--revocable`).
- **`Option<Address>` exige comillas JSON**; `Option<u64>` se omite para `None`.
- La función de registro se llama **`register`**, no `register_schema`.
- Los errores se ven como `Error(Contract, #N)`; el nombre se obtiene de `protocol/src/errors.rs` (mapa en `scripts/ejecutar.sh`).
- `stellar events --output plain` da una salida legible sin colores.

## Documentación que contradijo al código

- **La doc dice que `attest` acepta `subject` en el SDK**; el contrato no lo recibe (firma: `attester, schema_uid, value, expiration_time`) y lo fija al emisor.
- **La doc muestra `expiration_time` en milisegundos** en un ejemplo de la guía de Stellar; el contrato espera segundos y no avisa.
- **La doc ofrece tres sintaxis de `definition`**; el contrato no valida ninguna.

## Decisión para la especificación

- **`subject`:** en emisión directa es siempre el emisor. El dato de la persona certificada debe ir **dentro del registro** (sin datos personales en claro: por ejemplo un `holder_hash` con sal), no como `subject`.
- **Resolver:** no usar el resolver por defecto. Para VeritaX, el control de emisores va en el núcleo (ejercicio 04) y se descarta un resolver que impida emitir en directo.
- **Validación en el contrato propio:** exigir formato y tope de tamaño de `definition` y del `value`; rechazar `expiration_time` fuera de un rango razonable (para atrapar milisegundos); unidad documentada: **segundos**.
- **Revocación:** hoy solo revoca el emisor original (#6 para los demás). Decidir en el ejercicio 04 si `admin` también puede.
- **Consulta:** el verificador debe traducir los errores (`#5` es "no encontrado", no "falso").

## Costos o tiempos medidos (testnet, P30, 2026-11-11)

Comisión real cobrada (Horizon), en XLM:

| Operación | Comisión (XLM) | Comisión (stroops) |
|---|---|---|
| Registrar schema | 0,0029 – 0,0034 | ≈ 28.600 – 33.500 |
| Emitir (sin expiración) | 0,0085 | ≈ 84.600 |
| Emitir (con expiración) | 0,0069 – 0,0070 | ≈ 69.000 – 69.800 |
| Revocar | 0,00054 | ≈ 5.400 |

Total de las 11 transacciones enviadas: 0,0533 XLM. Son costos de **emisión**; no incluyen mantener el registro vivo (ejercicio 02/03). El costo mayor de emitir sin expiración frente a con expiración llama la atención y no lo investigué aquí: **no se debe concluir nada** sin repetirlo en el ejercicio 03.

## Preguntas abiertas

1. ¿Por qué emitir sin expiración cuesta más que con expiración? (Medir en el ejercicio 03 con simulaciones repetidas.)
2. ¿Qué rol cumple `subject` en la ruta delegada? Se ve en `delegation.rs` pero no se probó (BLS está fuera del laboratorio).
3. ¿La revocación con un schema con resolver pasa por `onrevoke`? No se pudo probar porque la emisión con resolver falla.
4. ¿Cuál es el tamaño de `value` a partir del cual falla? (Ejercicio 03.)

## Respuestas a las preguntas de comprensión

1. Si `subject == attester` siempre en emisión directa, el campo existe porque en la **ruta delegada** el emisor y el sujeto pueden ser distintos (`attest_by_delegation`, con `H-CONTRACT-4` exigiendo que el sujeto coincida al revocar). En el uso directo del laboratorio no aporta nada.
2. Que el resolver por defecto rechace la emisión directa significa que **no se puede usar tal cual**: para emitir con él habría que usar la delegación BLS, que VeritaX descarta. El motor propio necesita su propio control de emisores.
3. El contrato no tiene función para cambiar el schema ni su resolver (las únicas funciones son `register` y `get_schema`). Si el resolver deja de servir o cambia la política, hay que **registrar un schema nuevo** con otro UID; las attestations del anterior siguen apuntando al schema viejo.
