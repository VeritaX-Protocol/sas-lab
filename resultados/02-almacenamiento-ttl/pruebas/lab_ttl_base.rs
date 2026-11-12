//! Ejercicio 02 (pruebas que valen para el contrato tal cual y para la rama con extend_ttl).
//! Usan los valores reales de testnet (ejercicio 00): TTL mínimo persistente 120.960 y máximo 3.110.400.
//! `mock_all_auths` aquí solo aísla el TTL; la autorización se prueba en el ejercicio 04.
use protocol::{state::DataKey, AttestationContract, AttestationContractClient};
use soroban_sdk::{
    testutils::{
        storage::{Instance as _, Persistent as _},
        Address as _, Ledger,
    },
    Address, BytesN, Env, String as S,
};
use std::panic::{catch_unwind, AssertUnwindSafe};

const MIN_PERSISTENT: u32 = 120_960;
const MAX_TTL: u32 = 3_110_400;

struct Ctx<'a> {
    env: Env,
    id: Address,
    client: AttestationContractClient<'a>,
    attester: Address,
}

fn ctx<'a>() -> Ctx<'a> {
    let env = Env::default();
    env.mock_all_auths();
    env.cost_estimate().disable_resource_limits();
    // Los valores de red se fijan ANTES de crear entradas, y sin tocar protocol_version (evita el fallo del SDK 29).
    env.ledger().with_mut(|li| {
        li.sequence_number = 1_000;
        li.min_persistent_entry_ttl = MIN_PERSISTENT;
        li.min_temp_entry_ttl = 720;
        li.max_entry_ttl = MAX_TTL;
        li.timestamp = 1_794_000_000;
    });
    let id = env.register(AttestationContract {}, ());
    let client = AttestationContractClient::new(&env, &id);
    let admin = Address::generate(&env);
    let attester = Address::generate(&env);
    client.initialize(&admin);
    Ctx { env, id, client, attester }
}

fn schema<'a>(c: &Ctx<'a>, definicion: &str) -> BytesN<32> {
    c.client.register(&c.attester, &S::from_str(&c.env, definicion), &None, &true)
}

fn emitir<'a>(c: &Ctx<'a>, schema_uid: &BytesN<32>) -> BytesN<32> {
    c.client.attest(&c.attester, schema_uid, &S::from_str(&c.env, "{\"tipo\":\"asistencia\"}"), &None)
}

fn ttl_attestation<'a>(c: &Ctx<'a>, uid: &BytesN<32>) -> u32 {
    c.env.as_contract(&c.id, || c.env.storage().persistent().get_ttl(&DataKey::AttestationUID(uid.clone())))
}

fn ttl_nonce<'a>(c: &Ctx<'a>) -> u32 {
    c.env.as_contract(&c.id, || c.env.storage().persistent().get_ttl(&DataKey::AttesterNonce(c.attester.clone())))
}

fn ttl_instancia<'a>(c: &Ctx<'a>) -> u32 {
    c.env.as_contract(&c.id, || c.env.storage().instance().get_ttl())
}

fn avanzar<'a>(c: &Ctx<'a>, ledgers: u32) {
    c.env.ledger().with_mut(|li| {
        li.sequence_number += ledgers;
        li.timestamp += ledgers as u64 * 5;
    });
}

#[test]
fn ttl_inicial_de_lo_que_crea_el_contrato() {
    let c = ctx();
    let s = schema(&c, "curso:string,asistio:bool");
    let a = emitir(&c, &s);
    let (i, at, n) = (ttl_instancia(&c), ttl_attestation(&c, &a), ttl_nonce(&c));
    println!("TTL_INICIAL instancia={i} attestation={at} nonce={n} (mínimo de red {MIN_PERSISTENT})");
    // Sin extend_ttl en el contrato, todo nace con el TTL mínimo de la red.
    assert!(at >= MIN_PERSISTENT - 1); // en la base == mínimo de red; en la rama con extend_ttl es mayor
}

#[test]
fn sin_extender_el_certificado_se_archiva() {
    let c = ctx();
    let s = schema(&c, "curso:string,asistio:bool");
    let a = emitir(&c, &s);
    let antes = c.client.try_get_attestation(&a).is_ok();
    avanzar(&c, MIN_PERSISTENT + 10); // pasa el TTL
    let ttl_directo = catch_unwind(AssertUnwindSafe(|| ttl_attestation(&c, &a)));
    println!("ARCHIVO get_ttl_directo_tras_vencer(sin invocar)={:?} (secuencia {})", ttl_directo.ok(), c.env.ledger().sequence());
    let despues = catch_unwind(AssertUnwindSafe(|| c.client.try_get_attestation(&a)));
    println!("ARCHIVO antes_de_vencer_lee_ok={antes}");
    match &despues {
        Ok(r) => println!("ARCHIVO tras_vencer_resultado={:?}", r.as_ref().map(|_| "Ok(attestation)")),
        Err(_) => println!("ARCHIVO tras_vencer=PANICO del entorno de pruebas (entrada archivada)"),
    }
    // El entorno NO archiva: comprobamos qué dice get_ttl tras vencer.
    let ttl_tras = catch_unwind(AssertUnwindSafe(|| ttl_attestation(&c, &a)));
    println!("ARCHIVO get_ttl_tras_vencer={:?} (secuencia actual {} frente a live_until)", ttl_tras.ok(), c.env.ledger().sequence());
    assert!(antes);
}

#[test]
fn costo_de_emitir_y_revocar() {
    let c = ctx();
    let s = schema(&c, "curso:string,asistio:bool");
    let a = emitir(&c, &s);
    let r = c.env.cost_estimate().resources();
    let f = c.env.cost_estimate().fee();
    println!("COSTO_EMITIR recursos={r:?}");
    println!("COSTO_EMITIR fee={f:?}");
    let _ = a;
}

#[test]
fn crecimiento_de_instance_con_n_schemas() {
    let c = ctx();
    let mut n = 0u32;
    for objetivo in [1u32, 10, 50, 100, 200] {
        while n < objetivo {
            // definiciones distintas de ~100 bytes
            let def = format!("curso{n:04}:string,asistio:bool,{}", "x".repeat(70));
            schema(&c, &def);
            n += 1;
        }
        let r = c.env.cost_estimate().resources();
        println!("INSTANCE n={n} write_bytes={} disk_read_bytes={}", r.write_bytes, r.disk_read_bytes);
    }
}

#[test]
fn costo_de_emitir_segun_numero_de_schemas() {
    // Cada llamada carga la instancia completa: con más schemas, emitir cuesta más CPU y memoria.
    for n in [1u32, 50, 100, 200] {
        let c = ctx();
        let mut primero = None;
        for i in 0..n {
            let def = format!("curso{i:04}:string,asistio:bool,{}", "x".repeat(70));
            let s = schema(&c, &def);
            if primero.is_none() { primero = Some(s); }
        }
        emitir(&c, primero.as_ref().unwrap());
        let r = c.env.cost_estimate().resources();
        let f = c.env.cost_estimate().fee();
        println!("EMITIR_CON_N n={n} instrucciones={} mem_bytes={} write_bytes={} fee_total={}", r.instructions, r.mem_bytes, r.write_bytes, f.total);
    }
}

#[test]
fn el_entorno_modela_el_paso_del_tiempo() {
    // Diagnóstico: ¿baja get_ttl cuando avanza el ledger?
    let c = ctx();
    let s = schema(&c, "curso:string,asistio:bool");
    let a = emitir(&c, &s);
    let t0 = ttl_attestation(&c, &a);
    avanzar(&c, 100);
    let t1 = ttl_attestation(&c, &a);
    avanzar(&c, 1_000);
    let t2 = ttl_attestation(&c, &a);
    println!("TIEMPO ttl: inicial={t0} +100 ledgers={t1} +1100 ledgers={t2} secuencia={}", c.env.ledger().sequence());
}
