//! Ejercicio 03, tarea 6: el mismo certificado como String JSON y como struct tipado.
//! Mide solo la parte que cambia: el campo `value` del registro (el resto de Attestation es idéntico).
//! Contrato de prueba mínimo; no toca el protocolo. Bytes y CPU del entorno son fiables; su tarifa no (ver ejercicio 02).
use soroban_sdk::{contract, contractimpl, contracttype, BytesN, Env, String as S, Symbol};

#[contracttype]
#[derive(Clone)]
pub struct Cert {
    pub cert_hash: BytesN<32>,
    pub issued_at: u64,
    pub course_code: Symbol,
}

/// Struct de tupla: se guarda como vector, sin nombres de campo.
#[contracttype]
#[derive(Clone)]
pub struct CertT(pub BytesN<32>, pub u64, pub Symbol);

#[contracttype]
pub enum K {
    Texto(u32),
    Tipado(u32),
    Tupla(u32),
}

#[contract]
pub struct T;
#[contractimpl]
impl T {
    pub fn texto(env: Env, n: u32, v: S) { env.storage().persistent().set(&K::Texto(n), &v); }
    pub fn tipado(env: Env, n: u32, v: Cert) { env.storage().persistent().set(&K::Tipado(n), &v); }
    pub fn tupla(env: Env, n: u32, v: CertT) { env.storage().persistent().set(&K::Tupla(n), &v); }
}

fn medir(f: impl FnOnce(&Env)) -> (u32, i64) {
    let env = Env::default();
    env.cost_estimate().disable_resource_limits();
    f(&env);
    let r = env.cost_estimate().resources();
    (r.write_bytes, r.instructions)
}

#[test]
fn string_json_vs_struct_tipado() {
    let hex = "ab".repeat(32);
    let compacto = format!("{{\"v\":1,\"h\":\"{hex}\",\"c\":\"CURSO-DEMO\",\"t\":1790000000}}");
    let legible = format!("{{\"cert_hash\":\"{hex}\",\"issued_at\":1790000000,\"course_code\":\"CURSO_DEMO\"}}");
    let m = |nombre: &str, largo: usize, r: (u32, i64)| println!("STRUCT {nombre} bytes_dato={largo} write_bytes={} instr={}", r.0, r.1);
    for (nombre, json) in [("json_compacto", &compacto), ("json_nombres_largos", &legible)] {
        let r = medir(|env| { let c = TClient::new(env, &env.register(T, ())); c.texto(&1, &S::from_str(env, json)); });
        m(nombre, json.len(), r);
    }
    let r = medir(|env| { let c = TClient::new(env, &env.register(T, ())); c.tipado(&1, &Cert { cert_hash: BytesN::from_array(env, &[0xab; 32]), issued_at: 1_790_000_000, course_code: Symbol::new(env, "CURSO_DEMO") }); });
    m("struct_con_campos", 32 + 8 + 10, r);
    let r = medir(|env| { let c = TClient::new(env, &env.register(T, ())); c.tupla(&1, &CertT(BytesN::from_array(env, &[0xab; 32]), 1_790_000_000, Symbol::new(env, "CURSO_DEMO"))); });
    m("struct_tupla", 32 + 8 + 10, r);
}
