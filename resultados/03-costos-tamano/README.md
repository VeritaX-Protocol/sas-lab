# Ejercicio 03: costos por tamaño

Mide cuánto cuesta emitir un certificado según el tamaño de `value`, qué parte es renta, dónde fallan los tamaños grandes y qué topes conviene fijar.

- Enunciado: [../../ejercicios/ejercicio-03-costos-tamano.md](../../ejercicios/ejercicio-03-costos-tamano.md)
- Lo aprendido y la propuesta de topes: [NOTA.md](NOTA.md)
- Resumen de resultados: [informe.md](informe.md)
- Ajustes de red del momento: [ajustes-testnet.json](ajustes-testnet.json)

## Requisitos previos

- Ejercicio 02 hecho: `../02-almacenamiento-ttl/datos-rama.env` (contrato de la rama con TTL de 180 días y schema sin resolver) y el clon `attestprotocol-rama`.
- Identidad `emisorA` con fondos. Sin `.env.local`.
- Node ≥ 20, `npm install` dentro de esta carpeta (instala `@stellar/stellar-sdk`, `tsx`), `stellar` CLI, `cargo`, `python3`.

## Forma rápida: scripts

```bash
cd resultados/03-costos-tamano
npm install
scripts/ejecutar.sh              # todo (≈ 6 XLM de testnet y 25 transacciones)
scripts/ejecutar.sh sim          # 1. simulaciones (no cuestan nada)
scripts/ejecutar.sh enviar       # 2. 4 envíos reales y desglose de renta
scripts/ejecutar.sh limites      # 3. tamaños grandes (los envíos fallidos cobran poco)
scripts/ejecutar.sh struct       # 4. String JSON frente a struct tipado (Rust)
scripts/ejecutar.sh informe      # 5. genera informe.md
```

- Cada paso escribe en `logs/`. Los costos reales (Horizon) quedan en `logs/costos.txt`.
- `scripts/medir.ts` hace el trabajo; sus modos son `sim`, `limites` y `enviar 100,300,...`.

## Qué hace cada pieza

| Pieza | Qué hace |
|---|---|
| `scripts/medir.ts` | Construye `attest` con `value` de n bytes, lo simula o lo envía y lee recursos, footprint y renta del meta |
| `pruebas/lab_struct.rs` | Prueba Rust: mismo certificado como JSON, struct con campos y struct de tupla |
| `scripts/informe.py` | Genera `informe.md` desde `logs/` (ajuste lineal de renta, proyección a 1/5/10 años) |
| `scripts/ejecutar.sh` | Orquesta los pasos |

## Salida esperada

- Renta ≈ `1.351.098 + 2.499,7 × bytes` stroops por 180 días; 119 B ≈ 0,166 XLM, 1.000 B ≈ 0,386 XLM cobrados.
- `value` de 16.000 B pasa y de 16.050 B falla con `resource_limit_exceeded`, aunque la simulación pase.
- Struct con campos ocupa más que el JSON compacto; el de tupla, menos.

## Problemas frecuentes

| Síntoma | Causa probable | Qué hacer |
|---|---|---|
| `Top-level await is currently not supported` | Falta `"type": "module"` | `npm pkg set type=module` |
| `d.resources is not a function` | Otra versión del SDK | Esta carpeta usa SDK 17.4.0 (objetos planos) |
| `contract not found` | Testnet se reinició | Repite los ejercicios 01 y 02 |
| `tx_soroban_invalid` en tamaños grandes | Límite de red | Es un resultado esperado, no un error del script |

## Seguridad

La clave secreta de `emisorA` se lee en memoria con `stellar keys secret` y nunca se imprime ni se guarda. Los valores de prueba no contienen datos personales.
