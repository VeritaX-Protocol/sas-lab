# Ejercicio 00: toolchain y línea base

**Bloque:** consola | **Dificultad:** baja | **Tiempo:** 0,5 d | **Depende de:** –

## Objetivo

Comprobar que esta máquina compila y prueba el contrato heredado de Attest Protocol, dejar fijadas las versiones y los límites reales de la red, y detectar desajustes de versión antes del sprint.

## Qué vas a entender

- Qué versión de protocolo corre cada red hoy (mainnet: P29 desde 2026-10-01; testnet: posiblemente P30 tras el voto del 2026-11-03).
- El contrato usa `soroban-sdk 27.0.6`; el SDK vigente es 29.x y desde `soroban-sdk` 28 un `cargo build` directo a Wasm falla: hay que usar `stellar contract build`.
- Qué respaldo real tiene la frase "contrato auditado".

## Instrucciones para Claude Code

Carpeta: `resultados/00-toolchain/` (clon del repo en `resultados/00-toolchain/attestprotocol/`, fijado en el commit `c0c4529`).

1. **Verificar, no instalar:** `rustc -V`, `cargo -V`, `rustup target list --installed` (debe incluir `wasm32v1-none`), `stellar --version`, `node -v`. Si algo falta, detente y pregunta.
2. **Clonar y fijar commit:** `git clone https://github.com/daccred/attestprotocol` y `git checkout c0c4529`. Anotar `rust-toolchain.toml` y `Cargo.toml` (`soroban-sdk`, perfil `release`).
3. **Pruebas tal cual:** en `contracts/stellar`, `cargo test` (protocolo y resolvers). Anotar cuántas pasan, cuáles fallan y el tiempo. Un fallo no es un error del ejercicio: es un hallazgo.
4. **Compilar de dos formas:** (a) la del repo (`make build` en `protocol/`, ver `protocol/Makefile`); (b) `stellar contract build`. Anotar si ambas funcionan con la versión instalada del CLI y del toolchain `stable` actual.
5. **Tamaño del Wasm:** anotar bytes del `.wasm` de protocolo y de resolvers frente al máximo de **128 KB** (verificar el valor con `stellar network settings`).
6. **Red real:** ejecutar `stellar network settings --network testnet` (verificar flags con `--help`) y anotar: límite de tamaño de Wasm, de entradas por transacción (lectura/escritura), de bytes escritos, de instrucciones de CPU y TTL máximo/mínimo. Consultar la versión de protocolo de testnet y de mainnet (RPC `getVersionInfo` o `getNetwork` según disponibilidad). Comparar con los valores del análisis previo (400 entradas en footprint, 200 entradas / 132.096 bytes escritos, 400M instrucciones) y marcar cuáles difieren.
7. **Identidades:** crear `admin`, `emisorA` y `emisorB` en testnet y fondearlas con friendbot. Anotar solo las claves públicas.
8. **Auditorías:** leer `contracts/stellar/audit/ARCHITECTURE.md`, `LOC.md`, `*_STRIDE.md` y las fechas/versiones de los PDF (Almanax 2025-11-30; Scout). Anotar: ¿a qué commit o versión aplican? El protocolo v2 se desplegó en mainnet el 2026-08-29/31, ¿es posterior? El código cita hallazgos `HAL-01`/`HAL-04` (Halborn): ¿hay informe de Halborn en el repo? Concluir qué se puede afirmar en el SOW.
9. **Grep de línea base** (guardar la salida en `grep.txt`): `extend_ttl`, `instance()`, `persistent()`, `temporary()`, `mock_all_auths`, `update_current_contract_wasm`, `__constructor`.
10. **Subir de SDK (micro-prueba, sin migrar):** en una rama local, cambiar `soroban-sdk` a la versión vigente (29.x) y ejecutar `cargo test`. Anotar cuántos errores aparecen y de qué tipo. No arreglar nada.

## Criterio de éxito

- `cargo test` ejecutado y resultado anotado (verde o con hallazgos).
- Tamaño del `.wasm` anotado frente a 128 KB.
- Tabla "valor del análisis vs. valor de la red hoy" con fecha y ledger.
- Tres identidades fondeadas (solo claves públicas en la nota).
- Conclusión escrita sobre qué se puede decir de las auditorías.
- Resultado de la micro-prueba con SDK 29.

## Preguntas de comprensión

1. ¿Por qué el CLI puede ser v30.x y el contrato usar `soroban-sdk 27`? ¿Qué se rompe y qué no?
2. ¿Qué diferencia hay entre compilar con `make build` y con `stellar contract build`?
3. ¿Qué significa que testnet vaya un protocolo por delante de mainnet para este proyecto?

## Qué anotar

Versiones (rustc, cargo, stellar CLI, soroban-sdk, protocolo de cada red), commit, resultados de pruebas, tamaños de Wasm, tabla de límites, conclusiones sobre auditorías, resultado de la micro-prueba de SDK.

## Advertencias

- Solo testnet. Nunca imprimir claves secretas.
- No modificar el clon salvo en la rama local del paso 10.
- Los límites de red cambian por votación de validadores; son una foto fechada.
