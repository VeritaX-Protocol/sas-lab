# Evidencia del ejercicio 01 (testnet)

Generado: 2026-11-11 20:46:58 UTC  |  protocolo `CBVXDFQGP7EO7ZQOXAOWFNMFB5DALX7Y5OGGGWVBVQ6ZUBSCD5GNRASO`  |  resolver `CDAEYUDIW44R4VWX4VJVIVWXJJ7NV3OR6AKD3IOVOJWOSOD4CCDYFUAI`

Despliegue (admin):

- 10-deploy-protocol: [tx](https://stellar.expert/explorer/testnet/tx/770a2867ce6ede9704938a803c31191546fe76e4869a7ee992ee5f88f39358b2)
- 11-deploy-resolver: [tx](https://stellar.expert/explorer/testnet/tx/e2b9f8dbc4775aeeb61dccb2dcbbd7d331e8cab666aeb33ca6d8fb3e5e3a4fdc)
- 12-init: [tx](https://stellar.expert/explorer/testnet/tx/ea4a186e1dfbbe87589df3590218299b97e7c7a9e12f9b1412ec75787eebfca4)

| Operación | Resultado | Salida | Transacción |
| --- | --- | --- | --- |
| 21-schema-sin-resolver-sintaxis2 | OK | `"06c0f98170415fd62552b20476d1fa2b8c6836011354d5d9d6315e052dfad8b2"` | [tx](https://stellar.expert/explorer/testnet/tx/989f384dc2ec3349b612f23e2cbe126cb3881ed0037a88e35edfb4d50a0e826c) |
| 22-schema-struct-sintaxis1 | OK | `"4b3dcabec3d2877af6eccdad6c6ac1b1c6f7b25a7f2b25b6decff69eb8b9d001"` | [tx](https://stellar.expert/explorer/testnet/tx/976c3e9c20756aa0aa95661cb8eb8a815cebe49789533cbc578df09dd409ddaa) |
| 23-schema-tipos-sintaxis3 | OK | `"b191702e92203835a0bd725f27cb322135950e6a3d4350a94a3cdf0679602643"` | [tx](https://stellar.expert/explorer/testnet/tx/d021f4a746bc12d12954eb8df2be79fd409fa0d2b441310088b31ea592a6939c) |
| 24-schema-con-resolver | OK | `"e5efa808afae73d9039c234dcde60c17e156e90035f6fcf7b33d4892b85cea3c"` | [tx](https://stellar.expert/explorer/testnet/tx/9eda82620b2bf9a20a8bdd545d2cab74a8106df6258109e56b298b8ce3d934ba) |
| 25-schema-no-revocable | OK | `"f528fef163b45c05bac40673eb5512246277b0d53bb1f408dcaae868f73ca351"` | [tx](https://stellar.expert/explorer/testnet/tx/ffcd08e2513a0b3929373cadad57c48f366d23533a638b555dc78b167906b07a) |
| 26-schema-duplicado | ERROR #28 SchemaAlreadyExists | `` |  |
| 27-get-schema | OK | `{"authority":"GCWRIINQVVBD2OMMAIGLL64Z5IZ4DVWGQFINJZ7OUFW4EPLVASR7` |  |
| 31-attest-sin-resolver | OK | `"7269af0c087d6078ed42b5cae2b7bd6b07fc1a55316f8e71099198aadd2f0e1b"` | [tx](https://stellar.expert/explorer/testnet/tx/a41ef03c2923a3177a6e977acc6d452278630807fc7c08e59819a1cbead06ea4) |
| 32-attest-con-resolver | ERROR #24 ResolverCallFailed | `` |  |
| 33-exp-segundos-futuro | OK | `"9ceea715b816e201269fd1f4b51864c2073ef840a3cd987936da4cba3a916dbb"` | [tx](https://stellar.expert/explorer/testnet/tx/ad29ce6c4426fd8b21538c959b9dc1edf1e97f1f322fc75a242a357d34895b1a) |
| 34-exp-milisegundos | OK | `"dab5afd2e5490b7690ef89075cae29338dfb7891d5c57f6725e609b11a6619da"` | [tx](https://stellar.expert/explorer/testnet/tx/3445e5a17ab0085686014f3dd2780e8a578409512c31a694bd4f1afb5d1515f6) |
| 35-exp-pasado | ERROR #23 InvalidDeadline | `` |  |
| 36-attest-no-revocable | OK | `"ead448b66d0501f0041476aeab1da13a66a408b52bc4a850ba736248ccf8a298"` | [tx](https://stellar.expert/explorer/testnet/tx/426da002d5986bfbab5cc8680c649e8894db62cfb2058ac10af7dde63e4ce3e0) |
| 37-emisorB-emite-sin-lista | OK | `"f64540a21e4244f747a5ac1cee2ff06e4e848d59b5f3eed3e75f5a6bd13d7f8d"` | [tx](https://stellar.expert/explorer/testnet/tx/e41e5d85387d957c0306fd591be59fda122b34e6242f5b8cb4160c84a0cabd38) |
| 41-get-attestation | OK | `{"attester":"GCWRIINQVVBD2OMMAIGLL64Z5IZ4DVWGQFINJZ7OUFW4EPLVASR7S` |  |
| 42-get-uid-inexistente | ERROR #5 AttestationNotFound | `` |  |
| 43-get-exp-ms | OK | `{"attester":"GCWRIINQVVBD2OMMAIGLL64Z5IZ4DVWGQFINJZ7OUFW4EPLVASR7S` |  |
| 51-revoca-emisorB | ERROR #6 NotAuthorized | `` |  |
| 52-revoca-emisorA | OK | `null` | [tx](https://stellar.expert/explorer/testnet/tx/5874fdbe21a67f2cf55b682f7559180d4a12360a781785cf9654eb83881c411c) |
| 53-revoca-dos-veces | ERROR #29 AlreadyRevoked | `` |  |
| 54-revoca-no-revocable | ERROR #15 AttestationNotRevocable | `` |  |
| 55-get-tras-revocar | OK | `{"attester":"GCWRIINQVVBD2OMMAIGLL64Z5IZ4DVWGQFINJZ7OUFW4EPLVASR7S` |  |
