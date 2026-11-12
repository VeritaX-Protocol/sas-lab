# Informe del ejercicio 03
Generado: 2026-11-12 20:55:16 UTC
Medido el 2026-11-12, ledger 5698588, protocolo 30, testnet, contrato de la rama del ejercicio 02 (TTL de 180 días).

## 1. Simulación por tamaño de `value` (3 repeticiones cada una)

| value (B) | CPU (instr.) | bytes leídos | bytes escritos | entradas leer/escribir | tarifa de recursos simulada (XLM) |
| --- | --- | --- | --- | --- | --- |
| 119 | 924073 | 0 | 808 | 2/2 | 0.1911 |
| 300 | 936175 | 0 | 988 | 2/2 | 0.2430 |
| 600 | 957079 | 0 | 1288 | 2/2 | 0.3294 |
| 1000 | 984951 | 0 | 1688 | 2/2 | 0.4447 |

El rango es cero: la simulación es determinista para el mismo estado.

## 2. Envío real y desglose de renta (meta de la transacción)

| value (B) | simulado (XLM) | cobrado (XLM) | renta (XLM) | renta / total | no reembolsable (XLM) | tx |
| --- | --- | --- | --- | --- | --- | --- |
| 119 | 0.1911 | 0.1658 | 0.1651 | 99.6% | 0.0006 | [tx](https://stellar.expert/explorer/testnet/tx/1c3f2b5eb865254a22f10712427a68789f859e224c2e5f213359b82ac4641faa) |
| 300 | 0.2430 | 0.2110 | 0.2101 | 99.6% | 0.0007 | [tx](https://stellar.expert/explorer/testnet/tx/18eaf8e95537077f07522489e44ea363db04e207ca1a5b65e6f97d51617ae066) |
| 600 | 0.3294 | 0.2862 | 0.2851 | 99.6% | 0.0008 | [tx](https://stellar.expert/explorer/testnet/tx/ef0ec0768c961c1a8c10393d66d74dce60b2a980a1f7ce5ed3cc71a3a46fdafe) |
| 1000 | 0.4447 | 0.3864 | 0.3851 | 99.6% | 0.0010 | [tx](https://stellar.expert/explorer/testnet/tx/a5328de1e4aaf1dfa44cefe3d68c0160bd68431c5183932c02f09d4cfe57a875) |
| 16000 | — | 4.1468 | — | — | — | [tx](https://stellar.expert/explorer/testnet/tx/79b6c8871df32d2683852addb3aab49d8db197c5cedf797dd895e9ab9ac828cb) |

Ajuste lineal de la renta por 180 días: **1,351,098 + 2,499.7 × bytes de value** stroops (≈ 0.00025 XLM por byte; 0.250 XLM por KB). Casi todo el costo es renta; la parte que no depende del tamaño es la creación de las dos entradas (attestation y nonce). El costo cobrado queda ≈ 15 % por debajo del simulado (la parte reembolsable sobrante se devuelve).

## 3. Límites reales

| value (B) | simulación | envío real |
| --- | --- | --- |
| 2000 | pasa | — |
| 4000 | pasa | — |
| 8000 | pasa | — |
| 16000 | pasa | OK |
| 16050 | — | FALLA: resource_limit_exceeded |
| 16100 | — | FALLA: resource_limit_exceeded |
| 16150 | — | FALLA: resource_limit_exceeded |
| 16200 | — | FALLA: resource_limit_exceeded |
| 16300 | — | FALLA: resource_limit_exceeded |
| 16340 | — | FALLA: resource_limit_exceeded |
| 16360 | — | FALLA: resource_limit_exceeded |
| 16400 | — | FALLA: resource_limit_exceeded |
| 20000 | — | FALLA: resource_limit_exceeded |
| 32000 | pasa | — |
| 48000 | pasa | FALLA: resource_limit_exceeded |
| 60000 | pasa | — |
| 65000 | pasa | FALLA: resource_limit_exceeded |
| 65400 | pasa | — |
| 65536 | pasa | FALLA: resource_limit_exceeded |
| 70000 | pasa | RECHAZADA al enviar: tx_soroban_invalid |
| 100000 | pasa | — |
| 130000 | pasa | RECHAZADA al enviar: tx_soroban_invalid |

Los valores se piden en bytes exactos salvo el mínimo: el JSON base de ejemplo ocupa 119 B, así que «100» en realidad es 119 B.

La simulación **no detecta** el límite de eventos de 16.384 B (el evento de `attest` incluye `value`): la transacción se envía y falla cobrando comisión.

## 4. Costo de mantener (cota superior, con la renta de creación completa)

| value (B) | renta 180 d (XLM) | hoy: 5 s por ledger: 1 / 5 / 10 años (XLM) | hipótesis: 2,5 s: 1 / 5 / 10 años (XLM) | hipótesis: 1 s: 1 / 5 / 10 años (XLM) |
| --- | --- | --- | --- | --- |
| 120 | 0.1651 | 0.33 / 1.67 / 3.35 | 0.67 / 3.35 / 6.70 | 1.67 / 8.37 / 16.74 |
| 300 | 0.2101 | 0.43 / 2.13 / 4.26 | 0.85 / 4.26 / 8.52 | 2.13 / 10.65 / 21.30 |
| 512 | 0.2631 | 0.53 / 2.67 / 5.33 | 1.07 / 5.33 / 10.67 | 2.67 / 13.34 / 26.67 |
| 1000 | 0.3851 | 0.78 / 3.90 / 7.81 | 1.56 / 7.81 / 15.62 | 3.90 / 19.52 / 39.04 |

La renta es lineal en ledgers: si el cierre es más rápido y el TTL máximo sigue medido en ledgers, mantener un año cuesta proporcionalmente más. Los escenarios de 2,5 s y 1 s son **hipótesis**: CAP-88 permite objetivos distintos de 5 s, pero el valor lo fija la votación de validadores (`scp_timing`, hoy 5.000 ms en testnet).

## 5. `String` JSON frente a struct tipado (entorno de pruebas, solo la parte que cambia)

| Representación | bytes del dato | bytes escritos | instrucciones |
| --- | --- | --- | --- |
| json_compacto | 110 | 212 | 21628 |
| json_nombres_largos | 130 | 232 | 21634 |
| struct_con_campos | 50 | 236 | 26531 |
| struct_tupla | 50 | 176 | 24143 |

