# Informe del ejercicio 02
Generado: 2026-11-12 13:53:40 UTC

## 1. TTL reales en testnet

**Contrato del ejercicio 01 (sin extend_ttl), ~16 h después de crearse** (ledger 5693305):

| Entrada | Vive hasta | Ledgers restantes | Días |
| --- | --- | --- | --- |
| instancia del contrato (incluye los schemas) | 5802229 | 108924 | 6.3 |
| código Wasm | 5802176 | 108871 | 6.3 |
| schema (clave propia, solo si estuviera en persistent) | — | — | — |
| attestation | 5802245 | 108940 | 6.3 |
| nonce del emisor | 5802245 | 108940 | 6.3 |

**Rama con extend_ttl, justo después de emitir** (ledger 5693411):

| Entrada | Vive hasta | Ledgers restantes | Días |
| --- | --- | --- | --- |
| instancia del contrato (incluye los schemas) | 8803407 | 3109996 | 180.0 |
| código Wasm | 8803407 | 3109996 | 180.0 |
| schema (clave propia, solo si estuviera en persistent) | — | — | — |
| attestation | 8803410 | 3109999 | 180.0 |
| nonce del emisor | 8803410 | 3109999 | 180.0 |

**Contrato del ejercicio 01 tras `stellar contract extend` de UNA attestation (500.000 ledgers)** (ledger 5693420):

| Entrada | Vive hasta | Ledgers restantes | Días |
| --- | --- | --- | --- |
| instancia del contrato (incluye los schemas) | 5802229 | 108809 | 6.3 |
| código Wasm | 5802176 | 108756 | 6.3 |
| schema (clave propia, solo si estuviera en persistent) | — | — | — |
| attestation | 6193420 | 500000 | 28.9 |
| nonce del emisor | 5802245 | 108825 | 6.3 |

Lectura: sin `extend_ttl`, instancia, Wasm, attestation y nonce nacen con el mínimo de red (120.960 ledgers ≈ 7 días). El schema **no** es una entrada propia: vive dentro de la instancia. En la rama, `instance().extend_ttl` sube la instancia **y el Wasm** a la vez.

## 2. Comisión real cobrada (Horizon, testnet P30)

| Operación | Ledger | XLM | Transacción |
| --- | --- | --- | --- |
| initialize (rama) | 5693405 | 0.0011 | [tx](https://stellar.expert/explorer/testnet/tx/ff768b8314e45684db3aab4ae622f61afefe300d57725ba7e4b728d076d5d893) |
| registrar 1.er schema (RAMA: extiende instancia + Wasm a 180 días) | 5693407 | 37.0894 | [tx](https://stellar.expert/explorer/testnet/tx/4fa8ce08c0bed0f4ea21615c66c210ac7bd107a4c81631f781738076bcf4e7f2) |
| emitir (RAMA: attestation y nonce a 180 días) | 5693410 | 0.1819 | [tx](https://stellar.expert/explorer/testnet/tx/65118b8fc4a34d4aa19261d4698885dbb9c2d37a1c32690956d29d1629adea9c) |
| emitir (BASE, 7 días) el mismo día | 5693415 | 0.0064 | [tx](https://stellar.expert/explorer/testnet/tx/b6b549851f169defbe65648bc90514917c030cec1e4a83005c84e4245b061c3c) |
| `stellar contract extend` de 1 attestation, 500.000 ledgers (paga emisorB) | 5693420 | 0.0201 | [tx](https://stellar.expert/explorer/testnet/tx/79a3e140fdf0acab8c885e3b944358ac436898ff87ccebe6d75fefde1a8a4baf) |
| emitir con la instancia casi llena (64.552 B, contrato base) | 5693521 | 0.0080 | [tx](https://stellar.expert/explorer/testnet/tx/8beb96082db4dd7bf47d7927c152c88fa88504190b62cf957853767410602bf9) |

`35-renovar-sin-necesidad`: el CLI la trata como solo lectura (no envía transacción) porque el TTL ya está alto: **no cuesta**.

## 3. Techo de `instance` (contrato base nuevo, schemas de ~2 KB)

- Schemas registrados con éxito: **29**. Comisión del 1.º: 0.0235 XLM; del 29.º: 0.0262 XLM (cada registro reescribe toda la instancia).
- El schema siguiente falla: *ContractData size exceeds network config maximum size* (66780 > 65536 bytes).
- Con la instancia a 64.552 bytes todavía se pudo registrar un schema corto y emitir; el techo bloquea el crecimiento, no las llamadas.

## 4. Pruebas unitarias (Rust)

| Árbol | Pruebas propias | Pasan | Fallan |
| --- | --- | --- | --- |
| base (c0c4529) | lab_ttl_base | 6 | 0 |
| rama (lab/ttl) | lab_ttl_base + lab_ttl_rama | 11 | 0 |

Suite completa en la rama: 90 pasan, 0 fallan (las 79 originales siguen verdes).

- TTL inicial (base): `TTL_INICIAL instancia=120959 attestation=120959 nonce=120959 (mínimo de red 120960)`
- Paso del tiempo: `TIEMPO ttl: inicial=120959 +100 ledgers=120859 +1100 ledgers=119859 secuencia=2100`
- Archivo en el entorno de pruebas: `ARCHIVO get_ttl_directo_tras_vencer(sin invocar)=Some(120959) (secuencia 121970)`
- Archivo en el entorno de pruebas: `ARCHIVO antes_de_vencer_lee_ok=true`
- Archivo en el entorno de pruebas: `ARCHIVO tras_vencer_resultado=Ok("Ok(attestation)")`
- Archivo en el entorno de pruebas: `ARCHIVO get_ttl_tras_vencer=Some(120959) (secuencia actual 121970 frente a live_until)`
- Rama tras emitir: `RAMA_TTL_TRAS_EMITIR instancia=3110000 attestation=3110000 nonce=3110000`
- Rama tras 7 y 97 días: `RAMA_TRAS_7_DIAS ttl=2989030`
- Rama tras 7 y 97 días: `RAMA_TRAS_97_DIAS ttl=1433830`
- Rama: renovar: `RAMA_RENOVAR antes=400000 despues=3110000 renta_persistente=3426531834 fee_total=3426531874`
- Rama: renovar: `RAMA_RENOVAR_INNECESARIO renta_persistente=0 fee_total=36`
- Rama: UID inexistente: `RAMA_UID_INEXISTENTE resultado=Err(Ok(AttestationNotFound))`

Crecimiento de la instancia (bytes escritos al registrar el schema n, definiciones de ~100 B):

| n schemas | bytes escritos |
| --- | --- |
| 1 | 564 |
| 10 | 3408 |
| 50 | 16048 |
| 100 | 31848 |
| 200 | 63448 |

CPU y memoria de `attest` según el nº de schemas (cada llamada carga la instancia completa):

| n schemas | instrucciones | mem_bytes | fee (entorno de pruebas) |
| --- | --- | --- | --- |
| 1 | 127013 | 20680 | 1918747 |
| 50 | 931838 | 192278 | 1919311 |
| 100 | 1742514 | 367378 | 1919878 |
| 200 | 3366040 | 717578 | 1921015 |

