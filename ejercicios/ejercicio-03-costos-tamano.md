# Ejercicio 03: costos por tamaño

**Bloque:** consola + TypeScript | **Dificultad:** media | **Tiempo:** 1 d | **Depende de:** 01, 02

## Objetivo

Medir cuánto cuesta emitir un certificado según el tamaño del registro y proponer topes iniciales por campo y por registro. Es un borrador del Entregable 3.

## Qué vas a entender

- Una transacción Soroban paga **tarifa de inclusión + tarifa de recursos**; la de recursos incluye CPU, lecturas, escrituras, bytes y la **renta** por crear o hacer crecer entradas y por su TTL.
- La renta depende del tamaño de la entrada y de cuánto TTL se compra; no es lo mismo emitir que mantener.
- Límites duros: clave de ledger ≤ 250 bytes y entrada completa ≤ 64 KiB; 200 entradas leídas y 200 escritas por transacción (re-verificar con `stellar network settings`).
- El modelo de tarifas cambia: SLP-0007 (2026-10-22) bajó las tarifas de recursos y SDF anunció "Project Thruput" (2026-10-28, sin comisiones por transacción). Los números son una foto fechada.

## Instrucciones para Claude Code

Carpeta: `resultados/03-costos-tamano/`. Copiar de 01/02 los IDs, el schema sin resolver y las identidades (anotar origen). Lenguaje: TypeScript con `@stellar/stellar-sdk` (verificar versión y nombres contra el paquete instalado; anotar la versión) o `stellar` CLI con `--sim-only` si basta. Pruebas con `node --import tsx --test`.

1. **Simular, no enviar:** usar `simulateTransaction` (RPC `https://soroban-testnet.stellar.org` desde configuración) para `attest` con valores de ~100, 300, 600 y 1.000 bytes. Si el contrato admite `String`, usar texto real de un certificado de ejemplo **sin datos personales** (un hash con sal y campos genéricos).
2. **Tabla por tamaño:** para cada tamaño, anotar instrucciones de CPU, bytes leídos y escritos, número de entradas del footprint, tarifa de recursos, **desglose de renta** y tarifa total en XLM. Repetir 3 veces y reportar rango, no un solo número.
3. **Enviar una vez** para el tamaño de 300 bytes y comparar el costo cobrado con el simulado.
4. **Límites reales:** buscar el tamaño máximo que acepta el contrato antes de fallar (sin tope en `value: String`, el contrato heredado no impone ninguno). Anotar contra qué límite de red choca primero.
5. **Costo de mantener:** del costo de renta calcular cuánto cuesta mantener el registro 1 año, 5 años y 10 años (suponiendo TTL máximo y renovaciones), con el tiempo de cierre de ledger medido hoy y con el escenario de cierre en milisegundos de Protocolo 30. Presentar ambos y aclarar la suposición.
6. **`String` libre vs struct tipado:** en la rama local del clon, comparar el costo de emitir el mismo certificado como `String` JSON y como `#[contracttype]` con campos (por ejemplo `cert_hash: BytesN<32>`, `issued_at: u64`, `course_code: Symbol`). Anotar diferencia de CPU, bytes y renta.
7. **Propuesta de topes:** proponer tope por campo, por número de campos y por tamaño total del registro, justificado con la tabla. Indicar el costo máximo por certificado que resultaría.
8. **Cobertura:** repetir la medición de un caso en el momento de re-medir (después del voto de mainnet de Protocolo 30, 2026-11-23) está previsto en el ejercicio 99.

## Criterio de éxito

- Tabla de costos para ~100, 300, 600 y 1.000 bytes con CPU, bytes, entradas, tarifa total y renta, con fecha, ledger y versión de protocolo.
- Comparación `String` vs struct tipado.
- Estimación de costo de mantenimiento a 1, 5 y 10 años con dos supuestos de tiempo de ledger.
- Topes iniciales propuestos y justificados.
- Una transacción real enviada y comparada con su simulación.

## Preguntas de comprensión

1. ¿Qué parte de la tarifa crece con el tamaño del registro y qué parte no?
2. ¿Por qué el costo de emitir no dice cuánto cuesta que el certificado siga disponible?
3. ¿Qué tope inicial elegirías y qué margen dejarías si las tarifas bajan o suben?

## Qué anotar

Versión del SDK y del CLI, ajustes de red del momento (`stellar network settings` completo guardado como archivo), tabla, diff de la prueba del struct, propuesta de topes y supuestos.

## Advertencias

- Datos reales de personas jamás: solo textos de ejemplo.
- Un solo contrato de prueba; no medir en mainnet.
- La tarifa puede cambiar por votación; no citar estos números como definitivos en el SOW.
