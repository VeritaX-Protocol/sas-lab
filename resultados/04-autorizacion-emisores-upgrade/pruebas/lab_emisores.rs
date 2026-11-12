//! Ejercicio 04: autorización, lista de emisores en el núcleo, revocación por admin y costo frente a un resolver.
//! Casi todo usa `mock_auths` (no `mock_all_auths`) para que una autorización ausente falle de verdad.
//! `cargo test -p protocol --test lab_emisores [--features v2] -- --nocapture --test-threads=1`
use protocol::{errors::Error, state::IssuerStatus, AttestationContract, AttestationContractClient};
use resolvers::issuers::IssuerResolverClient;
use soroban_sdk::{
    testutils::{Address as _, MockAuth, MockAuthInvoke},
    Address, BytesN, Env, IntoVal, String as S,
};

struct C<'a> {
    env: Env,
    id: Address,
    cl: AttestationContractClient<'a>,
    admin: Address,
    a: Address,
    b: Address,
    schema: BytesN<32>,
}

fn nuevo<'a>() -> C<'a> {
    let env = Env::default();
    env.cost_estimate().disable_resource_limits();
    let id = env.register(AttestationContract {}, ());
    let cl = AttestationContractClient::new(&env, &id);
    let (admin, a, b) = (Address::generate(&env), Address::generate(&env), Address::generate(&env));
    // La preparación usa mock_all_auths; las pruebas de autorización lo reemplazan con mock_auths.
    env.mock_all_auths();
    cl.initialize(&admin);
    let schema = cl.register(&admin, &S::from_str(&env, "{\"v\":1}"), &None, &true);
    C { env, id, cl, admin, a, b, schema }
}

macro_rules! au {
    ($c:expr, $q:expr, $f:expr, $args:expr) => {
        MockAuth { address: $q, invoke: &MockAuthInvoke { contract: &$c.id, fn_name: $f, args: $args, sub_invokes: &[] } }
    };
}

fn emitir(c: &C, quien: &Address) -> Result<BytesN<32>, Result<Error, soroban_sdk::InvokeError>> {
    match c.cl.try_attest(quien, &c.schema, &S::from_str(&c.env, "{\"h\":\"x\"}"), &None) {
        Ok(Ok(u)) => Ok(u),
        Ok(Err(_)) => unreachable!(),
        Err(e) => Err(e),
    }
}

#[test]
fn a1_mock_auths_exige_la_firma_correcta_y_queda_registrada() {
    let c = nuevo();
    let v = S::from_str(&c.env, "{\"h\":\"x\"}");
    let args = (c.a.clone(), c.schema.clone(), v.clone(), None::<u64>).into_val(&c.env);
    // emisorA firma su propia llamada: pasa y env.auths() lo registra.
    c.cl.mock_auths(&[au!(c, &c.a, "attest", args)]).attest(&c.a, &c.schema, &v, &None);
    let auths = c.env.auths();
    println!("AUTHS_A n={} firmante_es_A={} fn={}", auths.len(), auths[0].0 == c.a, "attest");
    assert_eq!(auths.len(), 1);
    assert_eq!(auths[0].0, c.a);
    // emisorB firma pero la llamada dice que el atestador es A: debe fallar (falta la firma de A).
    let args_b = (c.a.clone(), c.schema.clone(), v.clone(), None::<u64>).into_val(&c.env);
    let r = c.cl.mock_auths(&[au!(c, &c.b, "attest", args_b)]).try_attest(&c.a, &c.schema, &v, &None);
    println!("AUTH_B_POR_A error={:?}", r.as_ref().err());
    assert!(r.is_err());
    // sin ninguna firma también falla
    let r = c.cl.mock_auths(&[]).try_attest(&c.a, &c.schema, &v, &None);
    println!("SIN_FIRMA error={:?}", r.as_ref().err());
    assert!(r.is_err());
}

#[test]
fn a2_en_el_contrato_heredado_emisorb_puede_emitir() {
    let c = nuevo();
    c.env.mock_all_auths();
    assert!(emitir(&c, &c.b).is_ok());
    println!("HALLAZGO emisorB emite sin lista: si");
}

#[test]
fn a3_initialize_dos_veces_y_secuestro_por_un_tercero() {
    let env = Env::default();
    env.mock_all_auths();
    let id = env.register(AttestationContract {}, ());
    let cl = AttestationContractClient::new(&env, &id);
    let (admin, intruso) = (Address::generate(&env), Address::generate(&env));
    // Un tercero llega primero y se pone como admin: initialize solo pide la firma del admin que se declara.
    cl.initialize(&intruso);
    let r = cl.try_initialize(&admin);
    println!("INIT_SECUESTRO intruso_primero=ok admin_legitimo={:?}", r.as_ref().err());
    assert_eq!(r.err().unwrap().unwrap(), Error::AlreadyInitialized);
    // Y el mismo admin tampoco puede repetirlo.
    assert_eq!(cl.try_initialize(&intruso).err().unwrap().unwrap(), Error::AlreadyInitialized);
}

#[test]
fn b1_lista_en_el_nucleo_activo_emite_inactivo_no_y_retirado_conserva_certificados() {
    let c = nuevo();
    c.env.mock_all_auths();
    c.cl.add_issuer(&c.admin, &c.schema, &c.a);
    assert!(emitir(&c, &c.a).is_ok());
    // B no está en la lista
    let eb = emitir(&c, &c.b).err().unwrap().ok().unwrap();
    println!("B_RECHAZADO {eb:?}");
    assert_eq!(eb, Error::IssuerNotActive);
    // A emite, luego se retira
    let uid = emitir(&c, &c.a).unwrap();
    c.cl.retire_issuer(&c.admin, &c.schema, &c.a);
    assert_eq!(c.cl.issuer_status(&c.schema, &c.a), IssuerStatus::Retired);
    assert!(!c.cl.is_active_issuer(&c.schema, &c.a));
    assert_eq!(emitir(&c, &c.a).err().unwrap().ok().unwrap(), Error::IssuerNotActive);
    // lo emitido antes sigue ahí, consultable y no revocado
    let at = c.cl.get_attestation(&uid);
    println!("RETIRADO_CONSERVA revoked={} attester_es_A={}", at.revoked, at.attester == c.a);
    assert!(!at.revoked);
    // reactivar no duplica la lista
    c.cl.add_issuer(&c.admin, &c.schema, &c.a);
    assert_eq!(c.cl.list_issuers(&c.schema).len(), 1);
    assert!(emitir(&c, &c.a).is_ok());
}

#[test]
fn b2_quien_puede_cambiar_la_lista() {
    let c = nuevo();
    // un tercero (B) no puede añadir, aunque firme
    c.env.mock_all_auths();
    let r = c.cl.try_add_issuer(&c.b, &c.schema, &c.a);
    println!("TERCERO_ADD {:?}", r.as_ref().err());
    assert_eq!(r.err().unwrap().unwrap(), Error::NotAuthorized);
    // sin firma del admin tampoco, aunque se declare admin
    let args = (c.admin.clone(), c.schema.clone(), c.a.clone()).into_val(&c.env);
    let r = c.cl.mock_auths(&[au!(c, &c.b, "add_issuer", args)]).try_add_issuer(&c.admin, &c.schema, &c.a);
    assert!(r.is_err());
    // la autoridad del schema (aquí también el admin) sí; y una autoridad distinta del admin:
    let aut = Address::generate(&c.env);
    let s2 = c.cl.register(&aut, &S::from_str(&c.env, "{\"v\":2}"), &None, &true);
    c.cl.add_issuer(&aut, &s2, &c.a);
    assert!(c.cl.is_active_issuer(&s2, &c.a));
    // y el admin general también puede sobre un schema ajeno
    c.cl.retire_issuer(&c.admin, &s2, &c.a);
    assert_eq!(c.cl.issuer_status(&s2, &c.a), IssuerStatus::Retired);
}

#[test]
fn c1_quien_puede_revocar() {
    let c = nuevo();
    c.env.mock_all_auths();
    let uid = emitir(&c, &c.a).unwrap();
    let r = c.cl.try_revoke(&c.admin, &uid);
    #[cfg(feature = "v2")]
    { println!("ADMIN_REVOCA v2 ok={}", r.is_ok()); assert!(r.is_ok()); }
    #[cfg(not(feature = "v2"))]
    { println!("ADMIN_REVOCA v1 {:?}", r.as_ref().err()); assert_eq!(r.err().unwrap().unwrap(), Error::NotAuthorized); }
    // un tercero nunca
    let uid2 = emitir(&c, &c.a).unwrap();
    assert_eq!(c.cl.try_revoke(&c.b, &uid2).err().unwrap().unwrap(), Error::NotAuthorized);
    // el emisor original siempre
    assert!(c.cl.try_revoke(&c.a, &uid2).is_ok());
}

#[test]
fn d1_solo_admin_puede_disparar_el_upgrade() {
    let c = nuevo();
    let h = BytesN::from_array(&c.env, &[7; 32]);
    // B firma "upgrade": debe fallar por autorización antes de tocar nada
    let args = (h.clone(),).into_val(&c.env);
    let r = c.cl.mock_auths(&[au!(c, &c.b, "upgrade", args)]).try_upgrade(&h);
    println!("UPGRADE_POR_B error={:?}", r.as_ref().err());
    assert!(r.is_err());
}

#[test]
fn e1_costo_de_attest_nucleo_frente_a_resolver() {
    // Mide una emisión restringida de tres formas: sin lista (original), lista en el núcleo, resolver aparte.
    let medir = |f: &dyn Fn(&C) -> BytesN<32>| {
        let c = nuevo();
        c.env.mock_all_auths();
        let sc = f(&c);
        let _ = c.cl.attest(&c.a, &sc, &S::from_str(&c.env, "{\"h\":\"x\"}"), &None);
        let r = c.env.cost_estimate().resources();
        (r.instructions, r.mem_bytes, r.write_bytes, r.disk_read_bytes)
    };
    let base = medir(&|c| c.schema.clone());
    let nucleo = medir(&|c| { c.cl.add_issuer(&c.admin, &c.schema, &c.a); c.schema.clone() });
    let resolver = medir(&|c| {
        let rid = c.env.register(resolvers::IssuerResolver {}, ());
        let rc = IssuerResolverClient::new(&c.env, &rid);
        rc.init(&c.admin);
        let s = c.cl.register(&c.admin, &S::from_str(&c.env, "{\"v\":3}"), &Some(rid.clone()), &true);
        rc.set_issuer(&s, &c.a, &true);
        s
    });
    println!("COSTO base_sin_lista instr={} mem={} write={} read={}", base.0, base.1, base.2, base.3);
    println!("COSTO lista_en_nucleo instr={} mem={} write={} read={}", nucleo.0, nucleo.1, nucleo.2, nucleo.3);
    println!("COSTO resolver_aparte instr={} mem={} write={} read={}", resolver.0, resolver.1, resolver.2, resolver.3);
}

// ── D3: ¿qué pasa si el contrato nuevo cambia la forma de un tipo guardado? ──────────────────────
mod migracion {
    use soroban_sdk::{contract, contractimpl, contracttype, Env, Symbol};
    #[contracttype] #[derive(Clone)] pub struct V1 { pub a: u32 }
    #[contracttype] #[derive(Clone)] pub struct V2Plus { pub a: u32, pub b: u32 }
    #[contracttype] #[derive(Clone)] pub struct V2Opt { pub a: u32, pub b: Option<u32> }
    #[contract] pub struct M;
    #[contractimpl]
    impl M {
        pub fn guardar(env: Env) { env.storage().persistent().set(&Symbol::new(&env, "k"), &V1 { a: 1 }); }
        pub fn leer_igual(env: Env) -> V1 { env.storage().persistent().get(&Symbol::new(&env, "k")).unwrap() }
        pub fn leer_campo_nuevo(env: Env) -> V2Plus { env.storage().persistent().get(&Symbol::new(&env, "k")).unwrap() }
        pub fn leer_campo_opcional(env: Env) -> V2Opt { env.storage().persistent().get(&Symbol::new(&env, "k")).unwrap() }
    }
}

#[test]
fn d3_cambiar_un_tipo_guardado_exige_migracion() {
    use migracion::*;
    let env = Env::default();
    let cl = MClient::new(&env, &env.register(M, ()));
    cl.guardar();
    let igual = cl.try_leer_igual().is_ok();
    let nuevo = cl.try_leer_campo_nuevo().is_ok();
    let opcional = cl.try_leer_campo_opcional().is_ok();
    println!("MIGRACION mismo_tipo={igual} campo_nuevo_obligatorio={nuevo} campo_nuevo_Option={opcional}");
    assert!(igual);
    assert!(!nuevo);
}
