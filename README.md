# sas-lab

**Laboratorio conceptual. No es código de producto.**

Ejercicios cortos y desechables para entender cómo se comporta **Soroban (Stellar)** y el contrato de [Attest Protocol](https://github.com/daccred/attestprotocol) (Daccred, MIT) **antes del inicio del Sprint 1 (2026-11-16)** del motor de [VeritaX Protocol](https://github.com/VeritaX-Protocol). Es el equivalente en Stellar de `eas-lab`, que cubrió EAS en Base Sepolia.

- **Red:** Stellar testnet, con identidades de prueba y friendbot. Nunca mainnet.
- **Qué se busca:** evitar sorpresas en la semana 1 del sprint: toolchain, almacenamiento con renta (TTL), costos por tamaño, autorización de emisores y actualización del contrato.
- **Fuente de verdad:** el código del contrato y la testnet. La documentación de attest.so se contradice en varios puntos (ver [LEEME.md](LEEME.md), sección 2) y no es evidencia.
- Reglas, preparación y plantilla de nota: [LEEME.md](LEEME.md). Licencias: [LICENCIAS.md](LICENCIAS.md).

## Ejercicios y estado

| # | Ejercicio | Pregunta que responde | Tiempo | Cuándo | Estado |
|---|---|---|---|---|---|
| 00 | [Toolchain y línea base](ejercicios/ejercicio-00-toolchain.md) | ¿Compila y pasa pruebas el contrato heredado con este toolchain y esta red? | 0,5 d | Antes del 16 | Hecho · [resultado](resultados/00-toolchain/) |
| 01 | [Attest Protocol tal cual en testnet](ejercicios/ejercicio-01-attest-protocol-testnet.md) | ¿Funciona lo heredado y qué se rompe? | 1 d | Antes del 16 | Hecho · [resultado](resultados/01-attest-protocol-testnet/) |
| 02 | [Almacenamiento y TTL](ejercicios/ejercicio-02-almacenamiento-ttl.md) | ¿Cuánto vive un certificado y cómo evito que se archive? | 1 d | Antes del 16 | Hecho (la restauración real queda para el 2026-11-18) · [resultado](resultados/02-almacenamiento-ttl/) |
| 03 | [Costos por tamaño](ejercicios/ejercicio-03-costos-tamano.md) | ¿Qué topes iniciales son razonables? | 1 d | Antes del 16 | Hecho · [resultado](resultados/03-costos-tamano/) |
| 04 | [Autorización, emisores y upgrade](ejercicios/ejercicio-04-autorizacion-emisores-upgrade.md) | ¿Lista de emisores en el núcleo o en un resolver? ¿Cómo actualizo sin perder estado? | 1 d | Puede hacerse en la semana 1 | Pendiente |
| 99 | [Cierre](ejercicios/99-cierre.md) | ¿Qué decisiones salen para el Entregable 2? | 1–2 h | Al terminar | Pendiente |

**Ruta:** 00 → 01 → 02 → 03 → 04 → 99.

## Fechas que condicionan el laboratorio

- **2026-11-16:** inicio del Sprint 1.
- **2026-11-23, 17:00 UTC:** voto de mainnet de **Protocolo 30 "Bell"** (el de testnet fue el 2026-11-03). Cambia el tiempo de cierre de ledger (CAP-88), así que los TTL medidos en ledgers cambian de duración real. Re-medir después de esa fecha.
- Mainnet corre **Protocolo 29** desde 2026-10-01.



## Fuera de este laboratorio

Fork limpio del contrato (sin BLS ni delegación), contratos de Solana, SDK y apps, Arweave, PDF/QR, cifrado de datos e interfaces web.
