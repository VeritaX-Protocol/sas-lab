# Plan de ejercicios: laboratorio SAS (Soroban + Attest Protocol)

## 1. Contexto del laboratorio (léelo siempre)

`sas-lab` es un **laboratorio conceptual** de la organización VeritaX-Protocol. **No es código de producto.** Son ejercicios cortos y **desechables** para entender cómo se comporta Soroban (Stellar) y el contrato de Attest Protocol (Daccred, MIT) antes del Sprint 1 (inicio 2026-11-16), y así evitar sorpresas al construir el motor propio de VeritaX. Lo explorado aquí puede diferir del diseño final.

Cubre solo Stellar/Soroban: toolchain, contrato heredado en testnet, almacenamiento con TTL, costos por tamaño y autorización de emisores con actualización del contrato. EAS ya se cubrió en `eas-lab`. Aquí no hay Arweave, PDF/QR, cifrado de datos ni interfaces web, y **no se hace el fork limpio** del contrato (eso es del sprint).

### Decisiones del laboratorio (no del producto)

| Tema | Decisión |
|---|---|
| Red | Stellar testnet (`Test SDF Network ; September 2015`). Nunca mainnet |
| Código base | `daccred/attestprotocol`, commit `c0c4529` (2026-09-11), carpeta `contracts/stellar` |
| Modo de trabajo | **Modo A**: Claude Code escribe y explica; el usuario lee, ejecuta y responde las preguntas |
| Lenguaje | Rust para contratos y pruebas (`cargo test`) y `stellar` CLI. TypeScript solo en el ejercicio 03 (`simulateTransaction` con `@stellar/stellar-sdk`) |
| Gas / fees | Cada identidad firma y paga lo suyo |
| Configuración | Red, RPC y IDs de contrato vienen de configuración o de `deployments.json`, nunca fijos en el código |
| Idioma | Explicaciones en español; código y nombres técnicos en inglés |

## 2. Fuente de verdad

> **La documentación de attest.so no es fuente de verdad. El código del contrato y la testnet sí.**

Contradicciones ya detectadas en docs.attest.so (cada ejercicio las verifica y las anota):

- El SDK expone `subject?` en `attest`, pero el contrato fuerza `subject = attester` (`contracts/stellar/protocol/src/instructions/attestation.rs`, línea 167 en `c0c4529`).
- El resolver por defecto rechaza `attester == recipient` (`contracts/stellar/resolvers/src/default.rs`, línea 20), lo que haría fallar siempre la emisión directa con ese resolver. **Hipótesis a confirmar en el ejercicio 01.**
- Unidades de `expiration_time`: segundos en unas páginas y milisegundos en otras.
- Sintaxis de `definition` del schema: aparecen tres formatos distintos.
- Tamaño de la firma BLS: 48 o 96 bytes según la página.
- La página overview de Stellar muestra una dirección testnet que parece de relleno. Usar `contracts/stellar/deployments.json`.
- Los esquemas se guardan en `instance()` storage (`protocol/src/instructions/schema.rs`, líneas 22, 95 y 106). No se encontró ningún `extend_ttl` (a confirmar con grep en el ejercicio 00).

`attest.org` es **EAS** (Ethereum Attestation Service), otro proyecto, sin relación con Stellar.

## 3. Principios del laboratorio

1. Ningún dato personal en la cadena. Jamás.
2. Todo certificado es revocable.
3. La verificación distingue estados; "no encontrado" no significa "falso".
4. **Solo testnet e identidades de prueba.** Nunca mainnet, nunca claves reales.
5. Todo número medido lleva **fecha, ledger, versión de protocolo y de CLI/SDK** (la red cambia: Protocolo 30 vota en mainnet el 2026-11-23 y trae cierre de ledger en milisegundos, CAP-88).
6. Testnet no es durable (se reinicia). No dependas de contratos ni de estado ya desplegado: despliega el tuyo y anota hashes el mismo día.
7. El código de los spikes es desechable. No se reutiliza como producto.
8. Cada enunciado cita el archivo y la línea del código que verifica.

## 4. Reglas para Claude Code

Antes de empezar un ejercicio, lee este archivo y el archivo del ejercicio pedido. Luego:

1. **No adelantes ejercicios.** Haz solo el que se pide y detente al terminar.
2. **Pasos pequeños.** Antes de cada bloque, explica en 2 a 4 líneas qué vas a hacer y por qué. Comentarios en español.
3. **No instales dependencias que no estén listadas** sin preguntar. Anota la versión de cada una.
4. **No confíes en tu memoria** para nombres de la API de `soroban-sdk`, del CLI de `stellar` ni de `@stellar/stellar-sdk`: cambian entre protocolos. Verifica contra el código instalado, `stellar <cmd> --help` y developers.stellar.org. Si un nombre difiere del enunciado, usa el real y anótalo.
5. **Seguridad:** nunca imprimas una clave secreta, nunca la subas a git, nunca uses mainnet.
6. **Si algo falla, no lo parches en silencio.** Explica error, causa y cambio.
7. **Ante una duda de diseño, pregunta** en vez de decidir.
8. **Al terminar:** ejecuta el criterio de éxito, escribe `README.md` (cómo correrlo) y `NOTA.md` (qué se aprendió) en la carpeta del ejercicio, muestra un resumen "Qué aprendí" y **detente a esperar** la revisión.

### Prompt sugerido para iniciar un ejercicio

> Lee `LEEME.md` y `ejercicio-NN-nombre.md`. Ejecuta solo ese ejercicio en modo A, siguiendo las reglas. Explica cada paso, escribe la nota en `resultados/NN-nombre/NOTA.md` y detente al terminar.

## 5. Preparación inicial (una sola vez)

Ya instalado según el usuario; el ejercicio 00 lo **verifica** y anota versiones (no instala nada):

- `rustc` y `cargo`, target `wasm32v1-none`.
- `stellar` CLI (puede ser v30.x; el contrato heredado usa `soroban-sdk 27.0.6`).
- `git`, `gh` (solo lectura) y Node 22+ (solo para el ejercicio 03).
- Fondos: friendbot de testnet.

### Identidades de prueba (se crean en el ejercicio 00)

| Alias | Para qué |
|---|---|
| `admin` | Administra el contrato, los emisores y el upgrade |
| `emisorA` | Entidad autorizada |
| `emisorB` | Entidad NO autorizada (pruebas negativas) |

Con `stellar keys generate <alias> --network testnet --fund` (verifica la sintaxis con `--help`). Las claves viven en el almacén del CLI, no en el repo.

## 6. Estructura: un ejercicio, un proyecto autocontenido

Cada ejercicio vive en `resultados/NN-nombre/` con su `README.md` (cómo correrlo) y `NOTA.md` (qué se aprendió).

Reglas:

1. Todo dentro de la carpeta del ejercicio: clon, código, datos, pruebas, informes y notas. Los comandos se ejecutan desde ahí.
2. **Nada se importa de otro ejercicio.** Si se necesita algo de uno anterior, se **copia** y se anota el origen en `NOTA.md`. Se admite duplicar.
3. Datos que arrastra un ejercicio (ID de contrato, UID de schema, hashes de despliegue) se copian a un archivo propio (por ejemplo `datos-entrada.json`) anotando el ejercicio de origen.
4. El clon de `daccred/attestprotocol` se hace **por ejercicio** que lo necesite, fijado en `c0c4529`. Si se modifica, se trabaja en una rama local del clon y se anota el diff en `NOTA.md`.
5. Las carpetas se crean al empezar cada ejercicio, no antes.

## 7. Tabla de contenido

| # | Archivo | Tema | Depende de |
|---|---|---|---|
| 00 | `ejercicios/ejercicio-00-toolchain.md` | Toolchain, línea base, auditorías, red | – |
| 01 | `ejercicios/ejercicio-01-attest-protocol-testnet.md` | Contrato heredado en testnet | 00 |
| 02 | `ejercicios/ejercicio-02-almacenamiento-ttl.md` | Almacenamiento, TTL y restauración | 00, 01 |
| 03 | `ejercicios/ejercicio-03-costos-tamano.md` | Costos por tamaño y topes | 01, 02 |
| 04 | `ejercicios/ejercicio-04-autorizacion-emisores-upgrade.md` | Autorización, emisores y upgrade | 01, 02 |
| 99 | `ejercicios/99-cierre.md` | Resumen y decisiones | 00–04 |

## 8. Plantilla de nota (`NOTA.md` dentro de la carpeta del ejercicio)

```
# Nota del ejercicio NN
Fecha y hora UTC:
Protocolo de la red (testnet / mainnet) y ledger de la medición:
Versiones usadas (rustc, stellar CLI, soroban-sdk, Node si aplica):
Commit de attestprotocol usado:
Código o datos copiados de otros ejercicios (y de cuál):
Qué hice:
Qué funcionó:
Qué falló o me sorprendió:
Nombres de la API (SDK/CLI) que difirieron del enunciado:
Documentación que contradijo al código:
Decisión para la especificación:
Costos o tiempos medidos (con fecha, ledger y tiempo de cierre de ledger):
Preguntas abiertas:
```

## 9. Glosario mínimo

- **Soroban:** plataforma de contratos inteligentes de Stellar (Wasm, Rust).
- **Ledger / ledger entry:** bloque de estado de la red / unidad de almacenamiento (par clave-valor).
- **TTL:** vida de una entrada en ledgers. Al llegar a 0, `persistent` e `instance` se **archivan** (restaurables) y `temporary` se **borra**.
- **Rent (renta):** pago por mantener una entrada viva y por crecerla o extender su TTL.
- **Footprint:** entradas que una transacción declara que leerá o escribirá.
- **Instance storage:** una sola entrada compartida con la instancia del contrato; un único TTL; techo por tamaño de entrada (64 KiB).
- **`simulateTransaction`:** método RPC que estima recursos, fee y footprint sin enviar.
- **`mock_auths` / `mock_all_auths`:** modos de prueba para simular firmas; el segundo puede ocultar `require_auth` ausentes.
- **Resolver:** contrato que valida `onattest`/`onrevoke` de un schema.
- **Subject / attester:** destinatario / quien emite la attestation.
- **BLS / delegación:** emisión firmada fuera de la cadena y enviada por un tercero. Se deja fuera del laboratorio.
- **Protocolo 30 "Bell":** actualización con CAP-84 (direcciones contrato muxed), CAP-87 (ML-DSA) y CAP-88 (cierre de ledger en milisegundos). Votos: testnet 2026-11-03, mainnet 2026-11-23.
