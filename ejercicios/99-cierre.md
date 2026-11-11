# Ejercicio 99: cierre

**Bloque:** documento | **Tiempo:** 1 a 2 h | **Depende de:** 00 a 04

## Objetivo

Consolidar lo aprendido en `resultados/RESUMEN.md`, listo para alimentar el documento de decisiones de diseño del Entregable 2 y el borrador del Entregable 3.

## Instrucciones para Claude Code

Cuando los ejercicios 00 a 04 tengan `NOTA.md`, generar `resultados/RESUMEN.md` con:

1. **Una línea por ejercicio:** qué se probó y la conclusión.
2. **Decisiones para la especificación** (copiar de cada nota): ubicación de schemas y registros (`persistent`), estrategia de renovación y quién paga, lista de emisores en núcleo vs resolver, quién puede revocar, forma del registro (`String` vs struct), topes iniciales, estrategia de upgrade.
3. **Qué se toma de Attest Protocol, de EAS y qué se deja fuera:**
   - De Attest Protocol: estructura `no_std`, errores tipados, eventos, guardia de `initialize`, `checked_add`, generación de UID, lógica de revocación, `testutils.rs`, perfil `release`.
   - De EAS (ver `eas-lab`): `refUID` para enlazar versiones de schema, `revocable = true` siempre, errores que el verificador traduce, "no encontrado ≠ falso".
   - Se deja fuera: delegación BLS, nonces de revocador, contratos de Solana, SDK y apps.
4. **Hallazgos que contradicen la documentación o el análisis previo** (con archivo y línea o hash de transacción).
5. **Qué se puede afirmar en el SOW** sobre auditorías y estado del proyecto base, según el ejercicio 00.
6. **Riesgos abiertos:** TTL máximo y quién renueva; llave de emisor perdida; Protocolo 30 y su efecto en TTL y timestamps; Project Thruput y cambios de tarifas; testnet no durable; CAP-0077 (congelar entradas por configuración).
7. **Re-medición pendiente:** repetir las mediciones del 02 y del 03 después del voto de mainnet de Protocolo 30 (2026-11-23, 17:00 UTC) y anotar diferencias.
8. **Preguntas abiertas** para el sprint.

## Criterio de éxito

- `RESUMEN.md` existe, no copia notas enteras y cada decisión remite a su `NOTA.md`.
- Todo número lleva fecha, ledger y versión de protocolo.
- Hay una lista corta de acciones para el Día 1 del sprint.

## Advertencias

- No reabrir ejercicios: si falta un dato, anotarlo como pregunta abierta.
- No afirmar "contrato auditado" sin la conclusión del ejercicio 00, tarea 8.
