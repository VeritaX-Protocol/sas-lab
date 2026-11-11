# Ejercicio 01: Attest Protocol tal cual en testnet

**Bloque:** consola | **Dificultad:** media | **Tiempo:** 1 d | **Depende de:** 00

## Objetivo

Desplegar el contrato heredado y su resolver por defecto en testnet, recorrer el ciclo registrar schema, emitir, consultar y revocar, y **confirmar o descartar** que la emisión directa falla con el resolver por defecto. Ensayar la recolección de evidencia (hashes y enlaces de explorador) del Entregable 1.

## Qué vas a entender

- Qué hace realmente `attest()` directo: el contrato fija `subject = attester` (`protocol/src/instructions/attestation.rs`, línea 167).
- Qué hace el resolver por defecto: rechaza `attester == recipient` (`resolvers/src/default.rs`, línea 20). Si la hipótesis es cierta, `attest()` directo con ese resolver siempre falla.
- Qué acepta el campo `definition` del schema y en qué unidades va `expiration_time` (la documentación se contradice).
- Qué eventos emite el contrato y cómo leerlos.

## Instrucciones para Claude Code

Carpeta: `resultados/01-attest-protocol-testnet/`. Copiar el clon del ejercicio 00 (o clonar de nuevo en `c0c4529`) y las identidades `admin`, `emisorA`, `emisorB` (mismas del 00; no regenerar).

1. **Desplegar el tuyo.** Testnet no es durable: no depender del contrato de `deployments.json`. Desplegar `protocol` y `resolvers` (puede usarse `deploy.sh` como referencia, pero verificar que funciona con tu CLI; si no, `stellar contract deploy`). Llamar a `initialize` con `admin`. Anotar IDs y hashes de Wasm. Comprobar también que **un segundo `initialize` falla** (guardia `AlreadyInitialized`).
2. **(Opcional, solo lectura)** Llamar `get_schema` contra el contrato publicado en `deployments.json` para confirmar que responde, y anotar si el ID sigue activo hoy.
3. **Registrar schemas** con `register(caller, schema_definition, resolver, revocable)`: uno **sin resolver** y otro **con el resolver por defecto**, ambos con `revocable = true`. Probar al menos dos sintaxis de `definition` (las tres de la documentación) y anotar cuál acepta el contrato (si el contrato solo guarda el texto, anotarlo). Intentar registrar el mismo schema dos veces y anotar el error.
4. **Emitir con `emisorA`:** `attest(attester, schema_uid, value, expiration_time)` en ambos schemas.
   - Caso esperado según el código: con el resolver por defecto, **falla**; sin resolver, pasa. Anotar el error exacto y compararlo con la hipótesis.
   - Probar `expiration_time` en segundos y en milisegundos; anotar cómo se interpreta (¿rechazo? ¿vencida de inmediato? ¿vigente por siglos?).
5. **Consultar:** `get_attestation(uid)`. Anotar campos devueltos, en particular `subject` frente a `attester`. Consultar un UID inexistente y anotar la respuesta (`AttestationNotFound`). Esto fija el principio "no encontrado ≠ falso".
6. **Revocar:** con `emisorA` (éxito), con `emisorB` (debe fallar), doble revocación (debe fallar) y en el schema creado con `revocable = false` (solo si se registra uno; opcional).
7. **Eventos:** leer los eventos `schema_registered`, `attestation_created` y `attestation_revoked` (`stellar events` o RPC `getEvents`) y anotar sus temas y datos.
8. **Evidencia:** para cada operación, guardar en `evidencia.md` el hash de la transacción, el ledger y el enlace en un explorador de testnet (por ejemplo stellar.expert).
9. **Destinatario sin cuenta Stellar:** escribir en la nota qué pasa hoy con una persona sin cuenta: `subject` siempre es el emisor, así que el dato de la persona tendría que ir dentro de `value`. Proponer, sin implementarlo, cómo se vería ese `value` (sin datos personales en claro; ver principio 1).

## Criterio de éxito

- Contrato y resolver desplegados en testnet con IDs anotados.
- Hipótesis de la emisión directa **confirmada o descartada** con el error literal anotado.
- Ciclo completo (registrar, emitir, consultar, revocar) con hashes y enlaces en `evidencia.md`.
- Se anota qué sintaxis de `definition` y qué unidad de `expiration_time` funcionan.
- Respuestas ante UID inexistente, doble `initialize` y revocación por no autorizado.

## Preguntas de comprensión

1. Si `subject == attester` siempre, ¿para qué existe el campo `subject`? ¿Qué rol cumple en la ruta delegada?
2. ¿Qué implica para VeritaX que el resolver por defecto rechace la emisión directa?
3. ¿Qué pasa con la attestation si el schema deja de existir o cambia el resolver? (El resolver no se puede cambiar tras registrar.)

## Qué anotar

IDs, hashes de Wasm, errores literales, sintaxis aceptada, unidad de `expiration_time`, eventos, costo en XLM de cada operación (la tarifa que reporta el CLI o el explorador) con fecha y ledger, y todo desajuste entre la documentación de attest.so y el comportamiento observado.

## Advertencias

- No se prueba la delegación BLS (`attest_by_delegation`): queda fuera del laboratorio.
- No depender de estado de testnet para ejercicios posteriores: copiar IDs a un archivo de datos propio y re-desplegar si se reinició.
- Nunca imprimir claves secretas.
