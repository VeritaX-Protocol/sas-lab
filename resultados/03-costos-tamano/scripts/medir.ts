// Ejercicio 03: mide el costo de `attest` según el tamaño de `value`. Solo testnet. No imprime claves.
// Uso: node --import tsx scripts/medir.ts sim | limites | enviar
import { rpc, TransactionBuilder, Networks, Contract, Keypair, nativeToScVal, Address, xdr, BASE_FEE } from "@stellar/stellar-sdk";
import { execSync } from "node:child_process";
import { readFileSync, appendFileSync } from "node:fs";

const RPC = process.env.SAS_RPC ?? "https://soroban-testnet.stellar.org";
const server = new rpc.Server(RPC, { headers: { "User-Agent": "sas-lab/1.0" } });
const env = Object.fromEntries(readFileSync("../02-almacenamiento-ttl/datos-rama.env", "utf8").split("\n").filter((l) => l.includes("=")).map((l) => l.split("=") as [string, string]));
const CONTRATO = env.RAMA_ID, SCHEMA = env.S_RAMA;
const secreto = () => execSync("stellar keys secret emisorA", { encoding: "utf8" }).trim(); // solo en memoria
const kp = Keypair.fromSecret(secreto());
export const valorDe = (n: number) => { // JSON de ejemplo, sin datos personales, de exactamente n bytes (ASCII)
  const base = JSON.stringify({ v: 1, h: "ab".repeat(32), c: "CURSO-DEMO", t: 1790000000, pad: "" });
  return base.replace('"pad":""', `"pad":"${"x".repeat(Math.max(0, n - base.length))}"`);
};
async function tx(n: number) {
  const cuenta = await server.getAccount(kp.publicKey());
  const args = [new Address(kp.publicKey()).toScVal(), xdr.ScVal.scvBytes(Buffer.from(SCHEMA, "hex")), nativeToScVal(valorDe(n), { type: "string" }), xdr.ScVal.scvVoid()];
  return new TransactionBuilder(cuenta, { fee: BASE_FEE, networkPassphrase: Networks.TESTNET })
    .addOperation(new Contract(CONTRATO).call("attest", ...args)).setTimeout(60).build();
}
async function sim(n: number) {
  const r = await server.simulateTransaction(await tx(n));
  if (rpc.Api.isSimulationError(r)) return { n, error: r.error.slice(0, 200) };
  const d: any = r.transactionData.build().toXdrObject(), res = d.resources, fp = res.footprint;
  return { n, bytes_valor: valorDe(n).length, cpu: res.instructions, leidos_B: res.diskReadBytes, escritos_B: res.writeBytes,
    entradas_leer: fp.readOnly.length, entradas_escribir: fp.readWrite.length, tarifa_recursos: Number(d.resourceFee), minResourceFee: Number(r.minResourceFee) };
}
const info = async () => { const l = await server.getLatestLedger(); return { ledger: l.sequence, protocolo: l.protocolVersion, fecha: new Date().toISOString() }; };

const modo = process.argv[2];
if (modo === "sim") {
  console.log(JSON.stringify(await info()));
  for (const n of [100, 300, 600, 1000]) for (let i = 0; i < 3; i++) console.log(JSON.stringify(await sim(n)));
} else if (modo === "limites") {
  console.log(JSON.stringify(await info()));
  for (const n of [2000, 4000, 8000, 16000, 32000, 48000, 60000, 65000, 65400, 65536, 70000, 100000, 130000]) console.log(JSON.stringify(await sim(n)));
} else if (modo === "enviar") {
  console.log(JSON.stringify(await info()));
  const tamanos = (process.argv[3] ?? "300").split(",").map(Number);
  for (const n of tamanos) {
    const s = await sim(n);
    let env0: any;
    try { const prep = await server.prepareTransaction(await tx(n)); prep.sign(kp); env0 = await server.sendTransaction(prep); }
    catch (e: any) { console.log(JSON.stringify({ n, fallo: "antes de enviar", msg: String(e.message ?? e).slice(0, 250) })); continue; }
    if (env0.status === "ERROR") { console.log(JSON.stringify({ n, fallo: "rechazada al enviar", msg: JSON.stringify(env0.errorResult ?? env0).slice(0, 250) })); continue; }
    let r: any; for (let i = 0; i < 30; i++) { r = await server.getTransaction(env0.hash); if (r.status !== "NOT_FOUND") break; await new Promise((x) => setTimeout(x, 1500)); }
    if (r.status !== "SUCCESS") { console.log(JSON.stringify({ n, hash: env0.hash, estado: r.status, msg: JSON.stringify(r.resultXdr ?? "").slice(0, 250) })); continue; }
    if (process.env.DEBUG_META) console.log(JSON.stringify(r.resultMetaXdr, (k, v) => (typeof v === "bigint" ? v.toString() : v)).slice(0, 1500));
    const mm: any = r.resultMetaXdr; const m = (mm.value ?? mm).sorobanMeta ?? mm.v3?.sorobanMeta ?? mm.v4?.sorobanMeta;
    const v1: any = m.ext.v1 ?? m.ext;
    const fila = { n, hash: env0.hash, estado: r.status, ledger: r.ledger, sim_tarifa_recursos: (s as any).tarifa_recursos, sim_min: (s as any).minResourceFee,
      no_reembolsable: Number(v1.totalNonRefundableResourceFeeCharged), reembolsable: Number(v1.totalRefundableResourceFeeCharged), renta: Number(v1.rentFeeCharged) };
    console.log(JSON.stringify(fila));
  }
}
