# Nota del ejercicio 04

Fecha y hora UTC: 2026-11-12, entre 21:10 y 21:50 UTC.

Protocolo de la red y ledger de la medición: testnet, **Protocolo 30**, ledgers 5.699.226 a 5.699.263 (testnet). Cierre de ledger 5 s.

Versiones usadas: stellar CLI 30.0.1, `soroban-sdk 27.0.6`, rustc 1.99.1.

Commit de attestprotocol usado: `c0c4529` con la rama local `lab/emisores` (worktree `attestprotocol-emisores`, ignorado por git). Incluye los cambios de TTL del ejercicio 02. Diff completo en [cambios-emisores.patch](cambios-emisores.patch) (187 líneas añadidas respecto de `c0c4529`; 28 son del ejercicio 02 y ≈ 160 de este).

Código o datos copiados de otros ejercicios: del 02, `cambios-ttl.patch` (aplicado sobre la rama nueva); del 00, las identidades `admin`, `emisorA`, `emisorB`.

## Qué hice

1. **Pruebas de autorización con `mock_auths`** (no `mock_all_auths`) para la llamada concreta, con `env.auths()`.
2. **Lista de emisores en el núcleo** (5 funciones) con `attest` que rechaza a los no activos; emisor retirado; quién puede cambiar la lista.
3. **Alternativa: resolver aparte** con la misma lista, y comparación de costo y de tamaño de Wasm.
4. **Admin que revoca** como cambio de v2, y **upgrade** v1 → v2 en testnet.
5. Una prueba sobre qué pasa si cambia la forma de un tipo guardado.

Cómo repetirlo: [README.md](README.md). Resultados: [informe.md](informe.md).

## Qué funcionó

- **Autorización:** con `mock_auths`, `emisorA` emite firmando su llamada y `env.auths()` lo registra (1 autorización, firmante A). Si firma solo `emisorB` por la llamada de `emisorA`, o si no firma nadie, la llamada aborta (`Abort`). `mock_all_auths` habría dejado pasar ambos casos.
- **Hallazgo heredado confirmado:** en un schema sin lista, `emisorB` emite sin problema, también en testnet (tx `82b3e9b8…`). Nadie lo frena.
- **Lista de emisores:** `emisorA` activo emite; `emisorB` recibe `#30 IssuerNotActive`; `emisorA` retirado recibe `#30`; **lo emitido antes sigue ahí, consultable y no revocado**; reactivar no duplica la lista. En testnet igual.
- **Quién cambia la lista:** `admin` o la autoridad del schema. Un tercero recibe `#6`. Una firma de B declarando a `admin` falla.
- **Upgrade en testnet (v1 → v2):** subí el Wasm v2 (`df6a7500…`) y `admin` lo aplicó con `upgrade`; `version()` pasó de 1 a 2. **v2 lee el registro hecho en v1, conserva la lista (`NotListed` para B), mantiene `#30` y `#6` sin renumerar, y deja emitir a `emisorA` reactivado.** El Wasm descargado con `stellar contract fetch` coincide con el hash de v2.
- **v2: el admin revoca** (tx `886063a4…`, `revoked=true`); `emisorB` recibe `#6`; el emisor original sigue pudiendo revocar la suya.

## Costos y tamaños medidos

| Cosa | v1 (heredado + TTL) | Lista en el núcleo | Resolver aparte |
|---|---|---|---|
| Instrucciones de `attest` (entorno de pruebas) | 172.826 | 190.265 (**+10 %**) | 279.349 (**+62 %**) |
| Memoria | 26.228 B | 28.574 B | 47.564 B |
| Bytes escritos | 760 | 760 | 760 |
| Tamaño de Wasm | 34.740 B | **38.449 B** (+3.709) | núcleo 34.740 + **4.190 B** en otro contrato |
| Despliegues | 1 | 1 | 2 (y un `admin` más que gestionar) |

- **Testnet, comisión real:** emitir con lista cuesta 0,1790 XLM frente a 0,1779 sin lista (**+0,0011 XLM**, un 0,6 %). Añadir un emisor por primera vez cuesta **0,0958 XLM** (crea dos entradas con 180 días de TTL); retirar, 0,0004 XLM; reactivar, 0,0006 XLM.
- **El Wasm es lo caro y se paga cada 180 días:** el primer `register` costó **42,81 XLM** (renta del Wasm v1 de 38 KB más la instancia) y subir el Wasm v2 con `stellar contract upload` costó 1,75 XLM (TTL mínimo). Orden de magnitud: **≈ 1,1 XLM por KB de Wasm por 180 días**. Por eso 3,7 KB de lista en el núcleo (≈ +4 XLM) y 4,2 KB de un resolver aparte (≈ +4,7 XLM más su instancia) cuestan casi lo mismo de mantener; lo que decide es la CPU y la superficie.
- **El upgrade tiene un costo oculto:** la transacción de `upgrade` cuesta 0,0004 XLM, pero **el Wasm nuevo es otra entrada** y la primera emisión después del upgrade pagó **42,99 XLM** para extenderla (`bump_instance`). Conviene que el admin extienda el Wasm nuevo justo después de actualizar (`stellar contract extend --wasm-hash` existe en el CLI; **no lo probé**). El Wasm v1 antiguo se queda hasta que venza.
- El entorno de pruebas mide bien CPU y bytes; su tarifa no es fiable (ejercicio 02), por eso aquí solo se usan instrucciones y bytes.

## Decisión: lista en el núcleo o en un resolver

**Recomiendo el núcleo.** Con números: +10 % de CPU frente a +62 %, un solo despliegue, una sola llamada, y mantener el Wasm cuesta lo mismo. El resolver aparte tiene sentido solo si se quisiera cambiar la política sin tocar el núcleo (un resolver nuevo por schema); a cambio añade una segunda llamada entre contratos que puede fallar (`ResolverCallFailed #24`), un segundo `admin` y una segunda renta. **El análisis previo se confirma.**

Dos matices del prototipo que hay que decidir en el fork:

1. **Schema sin lista = abierto** (como el original). Así las 79 pruebas originales siguen verdes, pero un schema registrado y no restringido deja emitir a cualquiera. En el fork conviene **cerrado por defecto**, y que `register` añada a la autoridad como primer emisor en la misma transacción.
2. **La lista es un `Vec` en una sola entrada** (más una entrada por emisor). El tope de 64 KiB por entrada admitiría unos cientos o más de emisores por schema; **no lo medí**. Para el piloto sobra.

## Quién puede revocar

- Hoy (v1) solo el emisor original: el admin recibe `#6` (probado).
- **v2: el admin también.** Resuelve la llave de emisor perdida, pero convierte una sola llave de admin en capaz de invalidar **todos** los certificados (la revocación es irreversible). Pasa 9/9 mis pruebas, pero **rompe 1 de las 79 originales** (`test_revocation_by_unauthorized_parties`, que da por hecho que el admin no puede). Hay que cambiarla o reemplazarla a propósito.
- **Propuesta:** no dar la revocación al admin global. Que revoque **la autoridad del schema** (la entidad) y que el admin solo pueda *retirar emisores*. Así se acota el daño y se cubre la llave perdida sin un revocador universal. Esto no está implementado: es una decisión por tomar.

## Upgrade y migración de datos

- **El contrato heredado no tiene función de upgrade.** `update_current_contract_wasm` no se llama en ningún sitio de `c0c4529`. El contrato desplegado en testnet/mainnet por Daccred **no se puede actualizar**; un fork propio debe incluirla **desde v1**: sin ella, no hay corrección de errores posible.
- `upgrade` exige `admin.require_auth()` y acepta **cualquier** hash de Wasm ya subido a la red (lo sube cualquiera). Es control total del contrato.
- **No hizo falta migrar** en este upgrade porque solo añadí variantes al **final** del enum `DataKey` y un valor nuevo en `Error` (sin renumerar). Una variante nueva de enum no afecta a las claves existentes.
- **Cambiar la forma de un struct guardado rompe la lectura, incluso añadiendo un campo `Option`:** en la prueba, leer un `V1 { a }` como `V2 { a, b }` falla, y con `b: Option<u32>` también. Los registros viejos quedarían ilegibles. Regla: **no tocar los structs guardados**; para cambiar uno, crear una clave nueva (`DataKey::AttestationV2(uid)`) y leer ambas (migración perezosa) o migrar todo antes.

## Destinatario

El `subject` es siempre el emisor (ejercicio 01). Propuesta: **identificar a la persona dentro de `value` con `holder_hash = sha256(documento ‖ sal)`**, sin datos personales en la cadena; quien verifica presenta documento y sal y recalcula el hash. Cuenta dentro del tope de 512 B (64 B en hex).

Si se quisiera un `subject` distinto en emisión directa, habría que añadir un parámetro `subject: Address` a `attest`; la fórmula del UID y la regla del resolver por defecto (`attester != recipient`) ya lo prevén. Pero **un destinatario sin cuenta Stellar no tiene dirección que poner**, así que el `holder_hash` hace falta de todos modos.

## Qué falló o me sorprendió

1. **Cualquiera puede quedarse con el contrato al desplegarlo.** `initialize` solo pide la firma del admin que el llamante *declara*: un tercero que llega primero se pone como admin y el legítimo recibe `AlreadyInitialized` (probado en el entorno de pruebas). Mitigación a verificar en el fork: `__constructor` (corre al crear, de forma atómica) o desplegar e inicializar en la misma transacción. **No lo probé.**
2. **El upgrade cuesta 43 XLM después**, no durante (ver arriba).
3. **`emisorB` no pudo ni intentar el upgrade en testnet:** el CLI se negó antes de enviar ("Missing signing key for account" del admin), así que **la prueba real de que B no puede es la de Rust** (`Abort`), no un rechazo de la red.
4. **El resolver aparte pesa 4,2 KB pero cuesta 62 % más de CPU**, más de lo que esperaba por una sola llamada entre contratos.
5. Cambiar un struct guardado rompe la lectura aunque el campo nuevo sea `Option` (esperaba que no).

## Preguntas abiertas

1. ¿Una lista de cientos de emisores en una sola entrada de 64 KiB cabe, y cuánto cuesta `attest`?
2. ¿`stellar contract extend --wasm-hash` extiende el Wasm nuevo tras el upgrade? ¿Lo puede hacer cualquiera, como con las attestations?
3. ¿`__constructor` evita de verdad el secuestro de `initialize`?
4. ¿Cómo se organiza el admin real (multisig de Stellar con pesos, hardware) y quién guarda las llaves?
5. ¿Hace falta un retraso (timelock) en `upgrade`? No existe nativo; habría que programarlo (proponer, esperar N ledgers, ejecutar).

## Respuestas a las preguntas de comprensión

1. **`mock_all_auths` oculta que falte `require_auth` o que firme quien no debe.** Con `mock_all_auths`, `attest` pasa aunque nadie lo haya firmado; con `mock_auths` solo está la firma declarada, y el intento de `emisorB` por `emisorA` y la llamada sin firmas abortan.
2. **Se quedan ilegibles si cambia la forma de un struct guardado**, aunque se añada un `Option`. Añadir variantes al final de un enum de claves sí es seguro. Hay que versionar las claves y migrar.
3. **Nada en el contrato.** Con una sola llave de admin, quien la robe sube un Wasm propio y controla todo. Mitigación propuesta: admin como cuenta multisig de Stellar, llaves en hardware, y un timelock (propuesta + espera + ejecución) con alertas sobre llamadas a `upgrade`. La alternativa extrema es un contrato no actualizable, que no puede corregir errores.

## Sin comprobar

- Costo y comportamiento con cientos de emisores; `stellar contract extend --wasm-hash`; `__constructor`; multisig/timelock; el rehearsal del upgrade se hizo en testnet real, no con v1 y v2 dentro de una prueba unitaria. Tampoco se probó delegación BLS (fuera de alcance).
- Costos de mainnet: no medidos. Los XLM son de testnet con las tarifas de hoy.
