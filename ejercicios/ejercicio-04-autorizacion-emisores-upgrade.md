# Ejercicio 04: autorización, emisores y upgrade

**Bloque:** Rust + consola | **Dificultad:** alta | **Tiempo:** 1 d | **Depende de:** 01, 02 | **Cuándo:** puede hacerse en la semana 1 del sprint (coincide con "autorización de emisores")

## Objetivo

Probar cómo se restringe quién emite, qué pasa con los certificados de un emisor retirado y cómo se actualiza el contrato sin perder estado. Decidir si la lista de emisores va en el núcleo o en un resolver.

## Qué vas a entender

- `require_auth()` es opt-in: olvidarlo es el fallo típico. `mock_all_auths()` lo oculta; hay que probar con `mock_auths` y asertar `env.auths()`.
- El contrato heredado no tiene lista de emisores: el resolver por defecto deja emitir a cualquiera (salvo la regla `attester == recipient`).
- El upgrade en Soroban es `env.deployer().update_current_contract_wasm(hash)`: conserva el estado y cambia el código. No existe `delegatecall` ni proxies.
- `__constructor` corre solo al crear, no en upgrade. El contrato heredado usa `initialize` con guardia.

## Instrucciones para Claude Code

Carpeta: `resultados/04-autorizacion-emisores-upgrade/`. Copiar el clon (rama local) y los IDs de 01/02. Identidades: `admin`, `emisorA`, `emisorB`.

**A. Autorización con pruebas negativas (Rust, `cargo test`)**

1. Escribir una prueba que, **sin `mock_all_auths`**, use `mock_auths` con `MockAuth`/`MockAuthInvoke` para una llamada concreta y aserte con `env.auths()` quién autorizó qué.
2. Mostrar que `emisorB` puede emitir en el contrato heredado (el hallazgo): sin lista, nadie lo frena.
3. Probar `initialize` dos veces (debe fallar con `AlreadyInitialized`) y `initialize` por un tercero antes que `admin` (documentar el riesgo si no hay constructor).

**B. Lista de emisores en el núcleo (rama local, mínimo)**

4. Añadir en el contrato núcleo, por esquema, 5 funciones aproximadas: `add_issuer(schema_uid, issuer)`, `retire_issuer(schema_uid, issuer)`, `is_active_issuer(schema_uid, issuer)`, `issuer_status(schema_uid, issuer)` y `list_issuers(schema_uid)`. Solo `admin` o la autoridad del schema pueden cambiarla. Guardar el estado en `persistent` con TTL (ver ejercicio 02).
5. `attest` rechaza a un emisor no activo. Pruebas: `emisorA` activo emite; `emisorB` es rechazado; `emisorA` retirado ya no emite **pero sus certificados anteriores siguen válidos y consultables**.
6. Medir el costo extra de `attest` con la lista en el núcleo (CPU, bytes, entradas) frente a la alternativa de un **resolver aparte** que consulta la lista (una llamada entre contratos). Comparar tamaño del Wasm, superficie de validación entre contratos y número de despliegues. Anotar cuál recomiendas y por qué (el análisis previo recomienda el núcleo; ahora hay números).

**C. Quién puede revocar**

7. Hoy solo revoca el emisor original (`attestation.attester != revoker` → error). Probar la variante en que `admin` también puede revocar y anotar el riesgo de abuso. Esto responde la pregunta abierta de la llave de emisor perdida.

**D. Upgrade sin perder estado**

8. Desplegar v1 (contrato con la lista), registrar schema y emitir. Compilar v2 con un cambio visible (un campo o una función nueva), instalar su Wasm y llamar a una función de upgrade gateada por `admin` que ejecute `update_current_contract_wasm`. Comprobar que: v2 lee los registros de v1; `emisorB` no puede disparar el upgrade; los errores no se renumeran.
9. Rehearsal con `stellar contract fetch` del Wasm desplegado y registrar v1 y v2 en una prueba para comparar comportamiento.
10. Decidir si hace falta migración de datos al cambiar el formato de un tipo guardado y cómo se versiona (`DataKey` compatibles entre versiones).

**E. Destinatario**

11. Con base en 01: el `subject` es siempre el emisor. Definir en la nota cómo se identifica a la persona certificada (campos dentro de `value` o `holder_hash` con sal) y qué tendría que cambiar en el contrato si se quisiera un `subject` distinto en emisión directa.

## Criterio de éxito

- Pruebas con `mock_auths` (no `mock_all_auths`) que fallan para `emisorB` y pasan para `emisorA`.
- Emisor retirado: no emite, sus certificados siguen válidos.
- Upgrade ejecutado en testnet por `admin`, con v2 leyendo registros de v1.
- Tabla comparativa núcleo vs resolver con costos y tamaño de Wasm.
- Decisión escrita sobre quién puede revocar y sobre el destinatario.

## Preguntas de comprensión

1. ¿Qué fallo oculta `mock_all_auths` que `mock_auths` hace visible?
2. ¿Qué pasa con un certificado si el contrato nuevo cambia la forma de la lista de emisores?
3. ¿Qué te protege de que una llave de `admin` robada reemplace el Wasm? ¿Qué mitigación propones para producción (multisig, timelock)?

## Qué anotar

Diff de la rama local, resultados de pruebas, costos, hash de Wasm v1 y v2, hashes de transacción del upgrade, decisiones y supuestos.

## Advertencias

- Es un prototipo para aprender, no el contrato del sprint (el fork limpio se hace en el Sprint 1).
- No se prueba delegación BLS.
- Tras el upgrade, el estado de testnet puede reiniciarse: guardar la evidencia el mismo día.
