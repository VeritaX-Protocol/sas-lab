//! Ejercicio 02: pruebas SOLO de la rama lab/ttl (con extend_ttl y extend_attestation_ttl).
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
fn emitir_extiende_el_ttl_hasta_180_dias() {
    let c = ctx();
    let s = schema(&c, "curso:string,asistio:bool");
    let a = emitir(&c, &s);
    let (i, at, n) = (ttl_instancia(&c), ttl_attestation(&c, &a), ttl_nonce(&c));
    println!("RAMA_TTL_TRAS_EMITIR instancia={i} attestation={at} nonce={n}");
    assert!(at >= 3_109_990 && at <= 3_110_000);
    assert!(i >= 3_109_990 && n >= 3_109_990);
}

#[test]
fn el_certificado_sigue_vivo_sin_restaurar_tras_7_dias_y_tras_90() {
    let c = ctx();
    let s = schema(&c, "curso:string,asistio:bool");
    let a = emitir(&c, &s);
    avanzar(&c, MIN_PERSISTENT + 10); // lo que antes lo archivaba
    let t = ttl_attestation(&c, &a);
    println!("RAMA_TRAS_7_DIAS ttl={t}");
    assert!(t > 2_900_000, "debería seguir lejos del vencimiento");
    avanzar(&c, 1_555_200); // ~90 días más
    let t2 = ttl_attestation(&c, &a);
    println!("RAMA_TRAS_97_DIAS ttl={t2}");
    assert!(t2 > 1_000_000);
}

#[test]
fn cualquiera_puede_renovar_cuando_queda_poco() {
    let c = ctx();
    let s = schema(&c, "curso:string,asistio:bool");
    let a = emitir(&c, &s);
    // Se acerca al vencimiento: quedan ~400.000 ledgers (< umbral de 518.400)
    avanzar(&c, 3_110_000 - 400_000);
    let antes = ttl_attestation(&c, &a);
    // Un tercero cualquiera (no el emisor) renueva
    c.env.mock_auths(&[]); // sin firmas: la función no exige autorización
    c.client.extend_attestation_ttl(&a);
    let f = c.env.cost_estimate().fee(); // medir ANTES de leer el TTL (cada lectura pisa la última invocación)
    let despues = ttl_attestation(&c, &a);
    println!("RAMA_RENOVAR antes={antes} despues={despues} renta_persistente={} fee_total={}", f.persistent_entry_rent, f.total);
    assert!(f.persistent_entry_rent > 0, "renovar cuando queda poco SÍ debe cobrar renta");
    assert!(antes < 518_400 + 5);
    assert!(despues >= 3_109_990);
}

#[test]
fn renovar_sin_necesidad_no_cobra_extension() {
    let c = ctx();
    let s = schema(&c, "curso:string,asistio:bool");
    let a = emitir(&c, &s); // TTL ya alto
    c.client.extend_attestation_ttl(&a);
    let f = c.env.cost_estimate().fee();
    println!("RAMA_RENOVAR_INNECESARIO renta_persistente={} fee_total={}", f.persistent_entry_rent, f.total);
    assert_eq!(f.persistent_entry_rent, 0, "si el TTL ya es alto no debe cobrar renta");
}

#[test]
fn renovar_un_uid_inexistente_falla() {
    let c = ctx();
    let r = c.client.try_extend_attestation_ttl(&BytesN::from_array(&c.env, &[7u8; 32]));
    println!("RAMA_UID_INEXISTENTE resultado={r:?}");
    assert!(r.is_err());
}
