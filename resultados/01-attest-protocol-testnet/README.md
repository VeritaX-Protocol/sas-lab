# Ejercicio 01: Attest Protocol tal cual en testnet

Despliega el contrato heredado y su resolver por defecto en testnet, recorre registrar schema → emitir → consultar → revocar, y confirma o descarta que la emisión directa falla con el resolver por defecto.

- Enunciado: [../../ejercicios/ejercicio-01-attest-protocol-testnet.md](../../ejercicios/ejercicio-01-attest-protocol-testnet.md)
- Lo aprendido: [NOTA.md](NOTA.md)
- Resumen de resultados: [informe.md](informe.md) · Hashes y enlaces: [evidencia.md](evidencia.md)

## Requisitos previos

- Ejercicio 00 hecho: identidades `admin`, `emisorA` y `emisorB` creadas y con fondos (`stellar keys ls`).
- `wasm/protocol.wasm` y `wasm/resolvers-default.wasm` (copiados del ejercicio 00; hashes en `wasm/SHA256.txt`).
- `stellar` CLI, `python3` y `curl`. Acceso a internet. Sin `.env.local`.

## Forma rápida: scripts

```bash
cd resultados/01-attest-protocol-testnet
scripts/ejecutar.sh desplegar      # una sola vez: despliega protocolo y resolver y llama a initialize
scripts/ejecutar.sh ciclo          # schemas, emisiones, consultas y revocaciones; escribe evidencia.md
scripts/ejecutar.sh eventos        # cuenta los eventos del contrato
scripts/ejecutar.sh informe         # genera informe.md (incluye costos reales desde Horizon)
scripts/ejecutar.sh                # ciclo + eventos + informe (usa el despliegue ya hecho)
```

- Cada operación se guarda en `logs/NN-nombre.{out,err}` y como una fila de `evidencia.md`.
- **No repitas `ciclo` sobre el mismo despliegue**: los schemas ya existen (error #28). Para empezar de cero, ejecuta `desplegar` primero (crea contratos nuevos).
- Las operaciones que fallan lo hacen en la simulación y no gastan comisión.
- Los IDs de contrato quedan en `datos.env` y los UID de schemas y attestations en `uids.env` (todo público).

## Qué hace cada bloque del ciclo

| Bloque | Operaciones | Qué se aprende |
|---|---|---|
| 2. Schemas | 5 registros (3 sintaxis de `definition`, con resolver, no revocable), 1 duplicado, 1 lectura | El contrato no valida `definition`; el duplicado da #28 |
| 3. Emitir | Sin resolver, con resolver, expiración en segundos, en milisegundos, en el pasado, `emisorB` | La emisión con el resolver por defecto falla (#24 ← #7); ms se acepta en silencio |
| 4. Consultar | Attestation, UID inexistente, expiración en ms | `subject == attester`; "no encontrado" da #5 |
| 5. Revocar | `emisorB` (#6), `emisorA` (OK), dos veces (#29), schema no revocable (#15), lectura final | Solo revoca el emisor original |
| 6. Eventos | `stellar events` | 1 evento por operación exitosa |

## Salida esperada

Los 17 casos con resultado esperado coinciden en `informe.md`, con la hipótesis de la emisión directa **confirmada** (#24 con resolver, OK sin resolver).

## Pasos manuales de referencia

```bash
N="--network testnet"
stellar contract deploy --wasm wasm/protocol.wasm --source-account admin $N --alias sas01_protocol
stellar contract deploy --wasm wasm/resolvers-default.wasm --source-account admin $N --alias sas01_resolver
stellar contract invoke --id <PROTOCOLO> --source-account admin $N -- initialize --admin <GADMIN>
stellar contract invoke --id <PROTOCOLO> --source-account emisorA $N -- register \
  --caller <GEMISORA> --schema_definition 'curso:string,asistio:bool' --revocable true
# resolver: Option<Address> va entre comillas JSON
... register --resolver '"<CRESOLVER>"' ...
stellar contract invoke --id <PROTOCOLO> --source-account emisorA $N -- attest \
  --attester <GEMISORA> --schema_uid <UID> --value '{"tipo":"asistencia"}'
```

## Casos negativos probados

`#13` doble `initialize` · `#28` schema duplicado · `#24` emisión con el resolver por defecto · `#23` expiración pasada · `#5` UID inexistente · `#6` revocar con otra cuenta · `#29` doble revocación · `#15` revocar en schema no revocable.

## Problemas frecuentes

| Síntoma | Causa probable | Qué hacer |
|---|---|---|
| `Invalid JSON in argument 'resolver'` | `Option<Address>` sin comillas JSON | Usa `--resolver '"C…"'` |
| `a value is required for '--schema_uid'` | La variable del UID está vacía por un fallo anterior | Revisa el paso que debía producirla en `logs/` |
| Error #28 al repetir `ciclo` | Los schemas ya existen en ese contrato | Ejecuta `desplegar` para un contrato nuevo |
| `contract not found` más adelante | Testnet se reinició | Vuelve a ejecutar `desplegar` y `ciclo` |

## Seguridad

Solo claves públicas en `datos.env`. Las secretas están en el almacén del CLI. Los valores de prueba (`value`) no contienen datos personales.
