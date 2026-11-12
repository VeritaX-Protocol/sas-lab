# Informe del ejercicio 04
Generado: 2026-11-12 21:48:30 UTC

## 1. Pruebas Rust

| Conjunto | Pasan | Fallan |
| --- | --- | --- |
| lab_emisores (v1) | 9 | 0 |
| lab_emisores (v2) | 9 | 0 |
| suite completa (v1) | 88 | 0 |
| suite completa (v2) | 87 | 1 |

En v2 falla `test_revocation_by_unauthorized_parties`: esa prueba original da por hecho que el admin **no** puede revocar, que es justo lo que v2 cambia.

- Autorización: `AUTHS_A n=1 firmante_es_A=true fn=attest`
- Autorización: `AUTH_B_POR_A error=Some(Err(Abort))`
- Autorización: `SIN_FIRMA error=Some(Err(Abort))`
- Autorización: `UPGRADE_POR_B error=Some(Err(Abort))`
- Hallazgo heredado: `HALLAZGO emisorB emite sin lista: si`
- Hallazgo heredado: `INIT_SECUESTRO intruso_primero=ok admin_legitimo=Some(Ok(AlreadyInitialized))`
- Lista de emisores: `B_RECHAZADO IssuerNotActive`
- Lista de emisores: `RETIRADO_CONSERVA revoked=false attester_es_A=true`
- Lista de emisores: `TERCERO_ADD Some(Ok(NotAuthorized))`
- Revocar: `ADMIN_REVOCA v1 Some(Ok(NotAuthorized))`
- Revocar: `ADMIN_REVOCA v2 ok=true`
- Migración de un tipo guardado: `MIGRACION mismo_tipo=true campo_nuevo_obligatorio=false campo_nuevo_Option=false`

## 2. Costo de `attest`: núcleo frente a resolver (entorno de pruebas)

| Variante | instrucciones | mem (B) | bytes escritos | bytes leídos |
| --- | --- | --- | --- | --- |
| base_sin_lista | 172826 | 26228 | 760 | 0 |
| lista_en_nucleo | 190265 | 28574 | 760 | 0 |
| resolver_aparte | 279349 | 47564 | 760 | 0 |

Lista en el núcleo: +17,439 instrucciones (+10%). Resolver aparte: +106,523 (+62%).

## 3. Tamaño de Wasm (límite de red: 131.072 B)

| Wasm | bytes |
| --- | --- |
| Heredado + TTL (ejercicio 02) | 34740 |
| v1: + lista de emisores + upgrade + version | 38449 |
| v2: v1 + admin revoca | 38494 |
| Resolver de emisores (contrato aparte) | 4190 |

## 4. Testnet: lo que pasó

| Paso | Resultado | Comisión (XLM) | Transacción |
| --- | --- | --- | --- |
| admin registra el schema (1.er `register`: renta del Wasm v1 + instancia, 180 días) | OK | 42.8069 | [tx](https://stellar.expert/explorer/testnet/tx/d3559b1b9e9120ad360e1ed2a4e64da73fc26fc6eabf9e11fc6f117c80798cbd) |
| emisorB emite en schema sin lista (heredado) | OK | 0.1779 | [tx](https://stellar.expert/explorer/testnet/tx/82b3e9b89e786128bc44c09c20452755901105488732ae411496a4753dfced1b) |
| emisorB se añade a sí mismo a la lista | error #6 | — | — |
| admin añade a emisorA | OK → null | 0.0958 | [tx](https://stellar.expert/explorer/testnet/tx/57e5510292cfeffa7dbe854312e5181b1b280bec292e732c8b40eae84685a6de) |
| emisorA activo emite | OK | 0.1790 | [tx](https://stellar.expert/explorer/testnet/tx/6dc34fe1d0b17de0f501d64038be39757ccd0840f0ba7dedc2e7a36f1d84bcc6) |
| emisorB (no listado) emite | error #30 | — | — |
| admin retira a emisorA | OK → null | 0.0004 | [tx](https://stellar.expert/explorer/testnet/tx/3a0e665623c5d637eb8164c910b5069ee4e73a0ee4e16f47adf7c89d241aae3e) |
| emisorA retirado emite | error #30 | — | — |
| estado de emisorA | OK → "Retired" | — | — |
| version() en v1 | OK → 1 | — | — |
| emisorB dispara upgrade | rechazado: falta la firma del admin | — | — |
| version() tras el intento | OK → 1 | — | — |
| admin dispara upgrade | OK → null | 0.0004 | [tx](https://stellar.expert/explorer/testnet/tx/b639182fe1b33e9f31e8a3f22aee5eaef2d01f036a9265eaf8edaf2f3c2f46d7) |
| version() en v2 | OK → 2 | — | — |
| v2: emisorB emite (error no renumerado) | error #30 | — | — |
| v2: emisorA emite (1.ª tras el upgrade: paga la renta del Wasm nuevo) | OK | 42.9904 | [tx](https://stellar.expert/explorer/testnet/tx/94854a2e19dddb93b4a03601d5bdd2d7a4677ed8c13b815ba2d4d747ee624915) |
| v2: emisorB revoca registro ajeno | error #6 | — | — |
| v2: admin revoca | OK → null | 0.0025 | [tx](https://stellar.expert/explorer/testnet/tx/886063a47406c7b13097d05f239f731d82f583dffa5f2725a61904bb433ce9b5) |
| v2: emisorA revoca la suya | OK → null | 0.0025 | [tx](https://stellar.expert/explorer/testnet/tx/453af1ad885b204f30fad7f2aa58636ec1993613a1d3e52c289dd75e6988ec46) |

- Subida del Wasm v2 (`stellar contract upload`): [tx](https://stellar.expert/explorer/testnet/tx/d9feca9034d74ef2aa31b047f56b03c772701a315bd534f6e5d9decab8dd3a4a)
- Lectura en v1 del registro de emisorA tras retirarlo: `revoked=False`, `attester=…R7S4LI`
- Lectura en v2 del registro hecho en v1: `revoked=False`, `attester=…R7S4LI`
- Lectura del registro revocado por el admin: `revoked=True`, `attester=…R7S4LI`
- ID: `CBUG6M3ARCVTLH2RNLZSKKQVJNQHF2QTJ6IC43ZBHRLND25QFDIBXDD7`
- H1: `27e653f3341cefeeccd3d0a30f085bc62e2bccb6e8079facede0401be64a27fd`
- H2: `df6a750077b12d065019012e860bea5a4bacc1f2a72ce857321297651e4bb3b9`
