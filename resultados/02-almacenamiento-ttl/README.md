# Ejercicio 02: almacenamiento y TTL

Mide cuánto vive un certificado en Soroban, qué pasa si nadie renueva, cuánto cuesta mantenerlo vivo y dónde conviene guardar schemas y registros.

- Enunciado: [../../ejercicios/ejercicio-02-almacenamiento-ttl.md](../../ejercicios/ejercicio-02-almacenamiento-ttl.md)
- Lo aprendido y las decisiones: [NOTA.md](NOTA.md)
- Resumen de resultados: [informe.md](informe.md)
- Cambios en el contrato: [cambios-ttl.patch](cambios-ttl.patch)

## Requisitos previos

- Ejercicios 00 y 01 hechos (identidades `admin`, `emisorA`, `emisorB` con fondos; contrato del 01 desplegado).
- `datos-entrada.env` (IDs y UID del ejercicio 01, copiados; testnet no es durable: si se reinició, repite el 01).
- `wasm/protocol-base.wasm` y `wasm/protocol-rama.wasm` (hashes en `wasm/SHA256.txt`).
- Clon `attestprotocol/` en `c0c4529` y worktree `attestprotocol-rama/` (rama `lab/ttl`); ambos ignorados por git.
- `stellar` CLI, `cargo`, `python3`, `curl`. Sin `.env.local`.

## Forma rápida: scripts

```bash
cd resultados/02-almacenamiento-ttl
scripts/ejecutar.sh                  # todo menos restaurar (varios minutos; envía unas 40 transacciones a testnet)
scripts/ejecutar.sh ttl-base         # 1. TTL reales del contrato del ejercicio 01 (solo lectura)
scripts/ejecutar.sh unitarias        # 2. pruebas Rust en la base y en la rama
scripts/ejecutar.sh rama             # 3. despliega la rama, mide TTL y comisión
scripts/ejecutar.sh extender         # 4. renueva una attestation con `stellar contract extend`
scripts/ejecutar.sh instancia        # 5. registra schemas de ~2 KB hasta que falle
scripts/ejecutar.sh informe          # 6. genera informe.md
scripts/restaurar.sh                 # SOLO después de 2026-11-18 20:50 UTC (restauración real)
```

- Cada paso escribe en `logs/`. Los costos reales (Horizon) quedan en `logs/costos.txt`.
- **`rama`, `extender` e `instancia` despliegan o escriben en testnet**: repetirlos crea contratos y attestations nuevos y gasta XLM de testnet.
- `scripts/ttl.py CONTRATO WASM_SHA256 SCHEMA_UID ATT_UID G_EMISOR` lee el TTL de cualquier despliegue (solo lectura).

## Qué hace cada pieza

| Pieza | Qué hace |
|---|---|
| `pruebas/lab_ttl_base.rs` | Pruebas Rust que valen para el contrato original y para la rama: TTL inicial, paso del tiempo, archivo, costo y crecimiento de la instancia |
| `pruebas/lab_ttl_rama.rs` | Pruebas solo de la rama: TTL a 180 días, sigue vivo tras 7 y 97 días, renovación por un tercero, renovar sin necesidad, UID inexistente |
| `cambios-ttl.patch` | Diff de la rama: `bump_persistent`/`bump_instance`, `extend_ttl` al emitir y registrar, y `extend_attestation_ttl` |
| `scripts/ttl.py` | Lee `liveUntilLedgerSeq` por RPC de instancia, Wasm, attestation, nonce y schema |
| `scripts/restaurar.sh` | Prueba la restauración real cuando el contrato del ejercicio 01 se archive |

## Salida esperada

- Base: todo nace con 120.960 ledgers (≈7 días); la rama, con 3.110.000 (≈180 días).
- 90 pruebas verdes en la rama (79 originales + 11 propias).
- En testnet, el schema nº 30 de ~2 KB falla con *ContractData size exceeds network config maximum size*.

## Casos negativos probados

- `extend_attestation_ttl` con un UID inexistente → error #5 (AttestationNotFound).
- Registrar el schema nº 30 de ~2 KB → falla por superar 64 KiB.
- Renovar con el TTL ya alto → no envía transacción (no cuesta).

## Problemas frecuentes

| Síntoma | Causa probable | Qué hacer |
|---|---|---|
| `HTTP Error 403` al leer el TTL | El RPC rechaza el User-Agent de Python | `ttl.py` ya usa uno propio; no lo quites |
| `no method named extend_attestation_ttl` en las pruebas de la rama | `CARGO_TARGET_DIR` compartido entre base y rama | Usa `target` distinto por árbol (el script ya lo hace) |
| Los costos del entorno de pruebas no cuadran con testnet | El entorno usa una configuración de tarifas simplificada | Usa solo `logs/costos.txt` (Horizon) |
| `restaurar.sh` dice que todavía no vencen | Es antes del 2026-11-18 20:50 UTC | Espera esa hora |
| `contract not found` | Testnet se reinició | Repite el ejercicio 01 y copia sus datos |

## Seguridad

Solo claves públicas en `datos-*.env`. Los valores de prueba no contienen datos personales.
