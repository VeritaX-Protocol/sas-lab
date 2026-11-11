# Ejercicio 02: almacenamiento y TTL

**Bloque:** consola + Rust | **Dificultad:** alta | **Tiempo:** 1 d | **Depende de:** 00, 01

## Objetivo

Saber cuánto vive un certificado en Soroban, cómo se evita que se archive y qué cuesta restaurarlo. Decidir dónde viven los schemas y los registros y quién paga la renta.

## Qué vas a entender

- Los tres tipos de almacenamiento: `persistent` (archivado, restaurable), `instance` (una sola entrada con TTL único, compartida con el contrato, techo de **64 KiB** por entrada) y `temporary` (se borra para siempre).
- El contrato heredado guarda los schemas en `instance()` (`schema.rs`, líneas 22, 95 y 106) y los registros en `persistent()`, y no tiene `extend_ttl` (a confirmar con el grep del ejercicio 00).
- Restaurar casi siempre es **automático**: al invocar vía `InvokeHostFunction` el simulador añade la restauración al footprint y se paga. La operación manual `RestoreFootprintOp` es la vía rara.
- El TTL se mide en **ledgers**. Con Protocolo 30 (CAP-88, cierre en milisegundos; voto de mainnet 2026-11-23) un ledger dura menos, así que el mismo TTL dura menos tiempo real.

## Instrucciones para Claude Code

Carpeta: `resultados/02-almacenamiento-ttl/`. Copiar el clon y los IDs del ejercicio 01 (anotar origen). Trabajar en una rama local del clon.

1. **Leer TTL reales en testnet:** con `stellar` CLI o RPC (`getLedgerEntries`) leer `liveUntilLedgerSeq` de: la instancia del contrato, el Wasm, un schema, una attestation y el contador de nonce del emisor. Calcular ledgers restantes frente al ledger actual y convertirlos a días con el tiempo de cierre medido (anotar cuántos segundos dura hoy un ledger).
2. **TTL por defecto de lo que crea el contrato:** anotar el TTL con el que nace cada tipo de entrada y los valores de red `min/max entry TTL` (ejercicio 00).
3. **Prueba unitaria de archivo:** en el clon, escribir una prueba (`cargo test`) que registre un schema y una attestation, avance el ledger con `env.ledger().with_mut(...)` más allá del TTL y muestre qué pasa al leer. Usar `get_ttl` desde `soroban_sdk::testutils::storage::Persistent` (trait de testutils) para asertar el TTL antes y después. Nombres exactos: verificar contra el SDK instalado.
4. **`extend_ttl` dentro del contrato:** añadir, solo en la rama local, `extend_ttl` al escribir y al leer (bump-on-access) en `attest`, `get_attestation` y `register`, con un umbral y una extensión razonables. Mostrar con una prueba que el TTL sube y que no se paga extensión innecesaria cuando ya está alto. Anotar el costo extra de la escritura.
5. **Extender desde fuera:** `stellar contract extend` sobre una attestation concreta (verificar flags con `--help`). Anotar el ledger resultante y el costo. Confirmar que **cualquier cuenta** puede extender (el que paga la renta no tiene que ser el emisor).
6. **Restauración:** dejar vencer (en testnet suele ser largo; usar la prueba unitaria o una entrada con TTL mínimo si la red lo permite) y comprobar los dos caminos: (a) invocación normal con restauración automática añadida por `simulateTransaction`; (b) `RestoreFootprintOp` manual. Anotar el costo adicional de restaurar. Si no se puede esperar al vencimiento real, documentarlo y apoyarse en la prueba unitaria.
7. **Techo de `instance`:** en la rama local, registrar N schemas (10, 50, 100, hasta fallar o hasta un tope razonable) y medir cómo crece la entrada de instancia y el costo por llamada. Anotar con cuántos schemas falla (límite de 64 KiB o de footprint).
8. **Decisión:** escribir en la nota una propuesta para: dónde van los schemas (se espera `persistent`, con una clave por schema), dónde los registros, quién paga la renta, con qué periodicidad se renueva y quién la dispara (bump-on-access, tarea periódica, ambos). Incluir qué pasa si nadie renueva.

## Criterio de éxito

- Tabla de TTL reales (en ledgers, en días y con el tiempo de cierre medido) para instancia, Wasm, schema y attestation.
- Prueba unitaria que demuestra el archivo y otra que demuestra `extend_ttl` dentro del contrato.
- `stellar contract extend` ejecutado, con ledger y costo anotados.
- Costo de restaurar medido (o justificadamente estimado) en los dos caminos.
- Límite de schemas en `instance` medido.
- Decisión escrita: `persistent` para schemas y registros, con estrategia de renovación.

## Preguntas de comprensión

1. ¿Por qué cada schema añadido en `instance` encarece todas las llamadas, no solo las que lo usan?
2. ¿Por qué "bump-on-access" no basta para un certificado que nadie consulta durante años?
3. ¿Cómo cambia la renovación en tiempo real si el ledger pasa de ~5 s a milisegundos?

## Qué anotar

Valores de TTL, costos de extensión y restauración, ledger y tiempo de cierre, límite de schemas, diff de las modificaciones locales, la decisión y los números que la sostienen.

## Advertencias

- No hay TTL "para siempre": toda vigencia es una promesa de renovar. Esto entra en las condiciones de los pilotos y en el Entregable 3.
- CAP-0077 (Protocolo 26) permite a la red congelar entradas por configuración; riesgo remoto, anótalo en las preguntas abiertas.
- Lo medido en testnet no es representativo de mainnet.
