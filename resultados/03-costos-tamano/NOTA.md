# Nota del ejercicio 03

Fecha y hora UTC: 2026-11-12, 20:49 a 20:55 UTC.

Protocolo de la red y ledger de la medición: testnet, **Protocolo 30**, ledgers 5.698.583 a 5.698.630. `scp_timing.ledger_target_close_time_milliseconds` = **5.000** (ya existe el ajuste de CAP-88, pero el objetivo sigue en 5 s).

Versiones usadas: stellar CLI 30.0.1, `@stellar/stellar-sdk` **17.4.0**, tsx 4.23.15, Node 26.13, `soroban-sdk 27.0.6`. Ajustes de red completos: [ajustes-testnet.json](ajustes-testnet.json).

Código o datos copiados de otros ejercicios: del 02, `datos-rama.env` (contrato de la rama con `extend_ttl`, schema sin resolver) y el clon `attestprotocol-rama`; del 00/01, las identidades. Se usó la **rama** (TTL de 180 días) porque el contrato heredado emite con TTL de 7 días y su renta no representa lo que costará mantener un certificado.

## Qué hice

1. Simulé `attest` con `value` de 119, 300, 600 y 1.000 bytes (3 veces cada uno) con `@stellar/stellar-sdk`: CPU, bytes, entradas y tarifa de recursos.
2. Envié cada tamaño de verdad y leí el desglose de renta del meta de la transacción (`rentFeeCharged`).
3. Busqué el tamaño máximo simulando de 2 KB a 130 KB y enviando los tamaños relevantes.
4. Calculé el costo de mantener a 1, 5 y 10 años con tres tiempos de ledger.
5. Comparé `String` JSON con struct tipado en el entorno de pruebas Rust.

Cómo repetirlo: [README.md](README.md). Resultados: [informe.md](informe.md).

## Resultados clave

| value (B) | cobrado (XLM) | de ese total, renta (XLM) | CPU | bytes escritos |
|---|---|---|---|---|
| 119 | 0,1658 | 0,1651 | 924.073 | 808 |
| 300 | 0,2110 | 0,2101 | 936.175 | 988 |
| 600 | 0,2862 | 0,2851 | 957.079 | 1.288 |
| 1.000 | 0,3864 | 0,3851 | 984.951 | 1.688 |
| 16.000 | 4,1468 | — | 2.059.230 (a 16 KB) | 16.688 |

- **El 99,6 % del costo es renta.** La comisión no reembolsable (CPU, ancho de banda) es de 0,0006 a 0,0010 XLM.
- **La renta es lineal:** `1.351.098 + 2.499,7 × bytes` stroops por 180 días, es decir ≈ **0,25 XLM por KB por 180 días**, más ≈ 0,135 XLM fijos por crear la attestation y el nonce.
- **La CPU casi no crece** (924 mil → 985 mil instrucciones de 119 a 1.000 B; el límite es 400 millones). El tamaño solo importa por la renta.
- **La simulación no cambia entre repeticiones** (rango 0) y **sobrestima ≈ 15 %** lo cobrado (la parte reembolsable sobrante se devuelve). Para presupuestar sirve como cota superior.
- **Footprint:** 2 entradas de lectura y 2 de escritura, 0 bytes leídos de disco (todo en memoria).

## Límites reales

- **Chocó primero un límite de recursos que la simulación no ve.** `value` de 16.000 B funciona; desde 16.050 B la transacción se envía y falla con `resource_limit_exceeded` (cobra ≈ 0,008–0,03 XLM de comisión). La causa más probable es el tope de eventos por transacción (**16.384 B**), porque el evento de `attest` incluye `value` (`events.rs:20`) y el resto del evento suma unos 380 B. **No lo confirmé aislando el límite**: es una inferencia por el tamaño.
- Las simulaciones de 32 KB a 130 KB pasan sin error y son inútiles: el envío falla igual.
- 70.000 y 130.000 B se rechazan al enviar con `tx_soroban_invalid` (no se cobran). No investigué la causa exacta.
- Otros topes de red (de `stellar network settings`): entrada ≤ 65.536 B, clave ≤ 250 B, transacción ≤ 132.096 B y 200 entradas por transacción. No fueron los primeros en chocar.
- **En la práctica:** sin tope en el contrato, un emisor puede mandar hasta ≈ 16 KB por certificado y pagar ≈ 4,1 XLM de renta por 180 días. El tope debe imponerlo VeritaX.

## Costo de mantener (cota superior: renta completa de creación)

Con el ajuste lineal y el TTL máximo de 180 días (renovando antes de vencer):

| value | hoy (5 s): 1 / 5 / 10 años | hipótesis 2,5 s | hipótesis 1 s |
|---|---|---|---|
| 300 B | 0,43 / 2,13 / 4,26 XLM | 0,85 / 4,26 / 8,52 | 2,13 / 10,65 / 21,30 |
| 512 B | 0,53 / 2,67 / 5,33 XLM | 1,07 / 5,33 / 10,67 | 2,67 / 13,34 / 26,67 |
| 1.000 B | 0,78 / 3,90 / 7,81 XLM | 1,56 / 7,81 / 15,62 | 3,90 / 19,52 / 39,04 |

- Suposición: la renta es proporcional a los ledgers (verificado en el ejercicio 02) y los ledgers por año son `31.536.000 / segundos por ledger`. Si el cierre se acorta, mantener un año cuesta proporcionalmente más.
- **Los escenarios de 2,5 s y 1 s son hipótesis mías.** CAP-88 (estado "Implemented") permite objetivos que no son segundos enteros, pero no fija el valor: lo fija la votación de validadores. No sé qué valor adoptará el Protocolo 30 en mainnet.
- Es cota superior: renovar cuesta menos porque no vuelve a pagar la creación del nonce (en el ejercicio 02, renovar una attestation pequeña 29 días costó 0,0201 XLM ≈ 0,25 XLM/año).
- No incluye el costo fijo de mantener vivo el Wasm y la instancia (≈ 37 XLM por 180 días, ejercicio 02), compartido por todos los certificados.
- La tarifa por KB (`rent_fee1_kb_soroban_state_size_*`) depende del tamaño total del estado de la red y puede cambiar.

## `String` JSON frente a struct tipado

Medido en el entorno de pruebas (bytes y CPU son fiables; la tarifa no, ver ejercicio 02). Solo cambia el campo `value`:

| Representación | bytes del dato | bytes escritos | instrucciones |
|---|---|---|---|
| JSON con claves de 1 letra | 110 | 212 | 21.628 |
| JSON con nombres legibles | 130 | 232 | 21.634 |
| struct con campos (`cert_hash`, `issued_at`, `course_code`) | 50 | 236 | 26.531 |
| struct de tupla (sin nombres de campo) | 50 | 176 | 24.143 |

- **Mi suposición era que el struct ahorraba bytes. Es falsa:** un `#[contracttype]` con campos guarda los **nombres de los campos** en el registro y ocupa más que el JSON compacto.
- La tupla ahorra 36 B (JSON compacto) a 56 B (JSON legible) por registro ≈ **0,009–0,014 XLM por 180 días**. Es despreciable frente a los 0,2 XLM de un registro normal.
- Cuesta ≈ 12–23 % más CPU, también despreciable (≈ 0,007 % del límite de 400 millones).
- **El argumento a favor de tipar no es el costo, es la validación:** el contrato no puede comprobar que un `String` sea JSON válido ni acotar sus campos. Cambiar `value: String` por un struct cambia la ABI del contrato (es del fork, fuera de este laboratorio).

## Propuesta de topes iniciales

| Tope | Valor propuesto | Justificación |
|---|---|---|
| Tamaño total de `value` | **≤ 512 B** (límite duro 1.024 B) | 0,26 XLM de renta por 180 días; un hash de 64 caracteres más pocos campos caben de sobra |
| Número de campos | ≤ 8 | Lo que cabe en 512 B con claves cortas |
| Tamaño por campo | ≤ 128 B, el hash exactamente 64 B (hex) | Evita que un campo consuma todo el presupuesto |
| `definition` del schema | ≤ 1 KB | Vive en la instancia (techo de ≈ 64 KiB en total, ejercicio 02) |
| Costo máximo de emisión por certificado | **≈ 0,39 XLM (1.024 B), con margen ×2 → presupuestar 0,8 XLM** | Cubre una subida de tarifas del doble |
| Mantener 10 años (512 B, hoy) | ≈ 5,3 XLM; con cierre de 1 s ≈ 27 XLM | Tabla de arriba |

- **Los topes deben validarse antes de enviar:** la simulación no detecta el límite de eventos (≈ 16 KB), así que el motor tiene que comprobar el tamaño por su cuenta o pagar una transacción fallida.
- Estos números son una foto de la testnet del 2026-11-12 con las tarifas de hoy. **No son cifras para el SOW** (mainnet no se midió; Project Thruput y SLP-0007 pueden cambiarlas).

## Qué falló o me sorprendió

1. **La simulación acepta lo que la red rechaza.** Es el hallazgo más útil del ejercicio: simulaciones de 48 KB y 130 KB pasan sin error.
2. **El struct tipado ocupa más, no menos** (ver arriba).
3. **Cambió la API del SDK 17:** `simulateTransaction` devuelve `transactionData` como objeto plano (`resources.instructions`, `diskReadBytes`, `writeBytes`, `footprint`), no con métodos; `r.cost` no existe; y el meta (`resultMetaXdr`) también es un objeto plano con `v4.operations`… Se tradujo con `Object` y no con las funciones `.instructions()` que usa el enunciado.
4. **Falta `"type": "module"` en `package.json`** para `await` de nivel superior con tsx.
5. **El valor de 100 B no se puede enviar:** el JSON base ocupa 119 B; se anotó como 119.

## Preguntas abiertas

1. ¿Qué límite exacto dispara `resource_limit_exceeded` a ≈ 16.000 B? (Probar con un contrato de prueba que emita eventos de tamaño conocido.)
2. ¿Cuál es el cierre de ledger de mainnet tras el voto del 2026-11-23? Re-medir la renta por ledger ese día (ejercicio 99).
3. ¿Cuánto cuesta renovar (no crear) un registro de 512 B en una medición directa? Aquí se usó la cota superior.
4. ¿Se puede validar el tamaño en un resolver, en vez de en el núcleo? (Ejercicio 04.)

## Respuestas a las preguntas de comprensión

1. **Crece con el tamaño la renta** (≈ 0,25 XLM por KB por 180 días); no crece la parte fija (≈ 0,135 XLM por crear las dos entradas) ni la CPU ni la comisión base (< 0,001 XLM).
2. **Porque emitir paga la renta de un solo periodo.** El costo de emitir (≈ 0,2 XLM) cubre 180 días; mantener un certificado años exige renovarlo, y el precio depende del tiempo de ledger y de las tarifas futuras.
3. **Tope de 512 B (duro 1.024 B)** y presupuesto de 0,8 XLM por certificado, el doble del máximo medido, para absorber una subida de tarifas. Si las tarifas bajan, el tope sigue siendo útil porque limita tamaño, no precio.
