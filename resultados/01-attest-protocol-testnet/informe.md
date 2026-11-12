# Informe del ejercicio 01
Generado: 2026-11-11 20:49:45 UTC

Contratos desplegados (testnet):

```
PROTOCOLO=CBVXDFQGP7EO7ZQOXAOWFNMFB5DALX7Y5OGGGWVBVQ6ZUBSCD5GNRASO
RESOLVER=CDAEYUDIW44R4VWX4VJVIVWXJJ7NV3OR6AKD3IOVOJWOSOD4CCDYFUAI
ADMIN=GCOATQG2S4D6WO5MQX3OSXSTHFFEOLUI7TFTWFJJQMXRORN55XQYL6Q6
EMISOR_A=GCWRIINQVVBD2OMMAIGLL64Z5IZ4DVWGQFINJZ7OUFW4EPLVASR7S4LI
```

## Esperado vs observado

| Prueba | Esperado | Observado | Coincide |
| --- | --- | --- | --- |
| Registrar schema `a:string,b:bool` (sintaxis 2) | OK | OK | sí |
| Registrar schema `struct X { ... }` (sintaxis 1) | OK | OK | sí |
| Registrar schema `string a, bool b` (sintaxis 3) | OK | OK | sí |
| Registrar schema con resolver por defecto | OK | OK | sí |
| Registrar schema con revocable=false | OK | OK | sí |
| Registrar el mismo schema otra vez | ERROR #28 | ERROR #28 SchemaAlreadyExists | sí |
| Emitir (emisorA) sin resolver | OK | OK | sí |
| Emitir (emisorA) con resolver por defecto | ERROR #24 | ERROR #24 ResolverCallFailed | sí |
| Expiración en segundos (+1 año) | OK | OK | sí |
| Expiración en milisegundos | (a observar) | OK | — |
| Expiración en el pasado | ERROR #23 | ERROR #23 InvalidDeadline | sí |
| emisorB (no autorizado) emite | (a observar) | OK | — |
| Consultar un UID inexistente | ERROR #5 | ERROR #5 AttestationNotFound | sí |
| Revocar con otra cuenta (emisorB) | ERROR #6 | ERROR #6 NotAuthorized | sí |
| Revocar con el emisor original | OK | OK | sí |
| Revocar dos veces | ERROR #29 | ERROR #29 AlreadyRevoked | sí |
| Revocar en schema revocable=false | ERROR #15 | ERROR #15 AttestationNotRevocable | sí |

## Costo real de las transacciones enviadas

| Operación | Ledger | Comisión (XLM) |
| --- | --- | --- |
| 21-schema-sin-resolver-sintaxis2 | 5681276 | 0.0028574 |
| 22-schema-struct-sintaxis1 | 5681278 | 0.0030363 |
| 23-schema-tipos-sintaxis3 | 5681280 | 0.0028816 |
| 24-schema-con-resolver | 5681282 | 0.0033531 |
| 25-schema-no-revocable | 5681284 | 0.0028649 |
| 31-attest-sin-resolver | 5681286 | 0.0084599 |
| 33-exp-segundos-futuro | 5681288 | 0.0069761 |
| 34-exp-milisegundos | 5681290 | 0.0069761 |
| 36-attest-no-revocable | 5681292 | 0.0068945 |
| 37-emisorB-emite-sin-lista | 5681294 | 0.0084599 |
| 52-revoca-emisorA | 5681297 | 0.0005445 |

Total de las operaciones listadas: 0.0533043 XLM.

Las operaciones que fallan lo hacen en la simulación, antes de enviarse, así que no tienen transacción ni cuestan comisión.

## Veredicto de las hipótesis

| Hipótesis | Veredicto | Detalle |
| --- | --- | --- |
| Emisión directa con el resolver por defecto falla | **CONFIRMADA** | sin resolver pasa; con el resolver falla con #24 (ResolverCallFailed), causado por `ValidationFailed` (#7) de `onattest` |
| `subject` siempre es el emisor | **CONFIRMADA** | subject == attester: True |
| Expiración en milisegundos | **ACEPTADA EN SILENCIO** | expiration_time=1794430015000 se interpreta como segundos (año ≈58833) |
| emisorB puede emitir sin lista de emisores | **SÍ** | no hay control de emisores en el núcleo |
