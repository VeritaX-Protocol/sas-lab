# Informe del ejercicio 00
Generado: 2026-11-11 20:29:14 UTC

## 1. Versiones
```
rustc 1.99.1 (58cf8f9c3 2026-10-13)
cargo 1.99.1 (5f94df478 2026-08-27)
wasm32v1-none
x86_64-unknown-linux-gnu
stellar 30.0.1 (f2a7b74175c34585f3b30a1abf42a2d41cbcc390)
v26.13.0
git version 2.43.0
```

## 2. Pruebas del contrato

| Versión | Pasan | Fallan | Ignoradas | Estado |
| --- | --- | --- | --- | --- |
| soroban-sdk 27.0.6 (tal cual) | 79 | 0 | 7 | OK |
| soroban-sdk 29.0.1 (micro-prueba) | 70 | 9 | 7 | 9 fallos |

Fallos con SDK 29 (9):
- `test_accept_valid_attestation`
- `test_allow_revocable_attestation_revocation`
- `test_attestation_and_expiration`
- `test_handling_expired_attestations`
- `test_metadata`
- `test_reject_expired_attestation`
- `test_reject_non_revocable_attestation_revocation`
- `test_reject_self_attestation`
- `test_revocation_hooks`

Causa(s) reportada(s) por el host:
- ledger protocol version too old for host (versión en el test: 27)

## 3. Tamaño del Wasm

| Archivo | Bytes | % del máximo (131.072 B) |
| --- | --- | --- |
| protocol.wasm | 34.287 | 26 % |
| resolvers.wasm | 3.542 | 3 % |

## 4. Red

| Red | Protocolo | Ledger | Cierre |
| --- | --- | --- | --- |
| testnet | 30 | 5681057 | 2026-11-11 20:28:48 UTC |
| mainnet | 29 (soporta 30) | 65428578 | 2026-11-11T20:28:52Z |

Límites de testnet frente al análisis previo:

| Límite | Testnet hoy | Análisis previo |
| --- | --- | --- |
| Tamaño máx. de Wasm (bytes) | 131072 | coincide |
| Entradas en el footprint por tx | 400 | coincide |
| Entradas escritas por tx | 200 | coincide |
| Bytes escritos por tx | 132096 | coincide |
| Instrucciones de CPU por tx | 400000000 | coincide |
| Entradas leídas de disco por tx | 200 | nuevo |
| Clave de ledger (bytes) | 250 | nuevo |
| Entrada de contract-data (bytes) | 65536 | nuevo |
| TTL máximo (ledgers) | 3110400 | nuevo |
| TTL mínimo persistente (ledgers) | 120960 | nuevo |
| Cierre objetivo de ledger (ms) | 5000 | nuevo |

## 5. Qué usa el contrato (grep de línea base)

| Término | Usos en src | Archivos de test |
| --- | --- | --- |
| `extend_ttl` | 0 | 0 |
| `instance()` | 7 | 2 |
| `persistent()` | 19 | 2 |
| `temporary()` | 0 | 0 |
| `mock_all_auths` | 0 | 10 |
| `mock_auths` | 0 | 4 |
| `update_current_contract_wasm` | 0 | 0 |
| `__constructor` | 0 | 0 |

## 6. Desde el commit que escaneó Almanax

```
commits: 30
 14 files changed, 691 insertions(+), 955 deletions(-)
despliegue mainnet v2: c67f1af 2026-08-31 18:28:43 +0000
```

## 7. Identidades de prueba (solo claves públicas)

```
admin GCOATQG2S4D6WO5MQX3OSXSTHFFEOLUI7TFTWFJJQMXRORN55XQYL6Q6
emisorA GCWRIINQVVBD2OMMAIGLL64Z5IZ4DVWGQFINJZ7OUFW4EPLVASR7S4LI
emisorB GDWGKG6HRWEUJODF733QP3XFPC4WSQE422NZ7EHJSIQYVYJSQPM2WIZX
```
