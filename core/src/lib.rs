#![warn(clippy::all)]

use std::collections::HashMap;
use std::ffi::CStr;
use std::net::{IpAddr, Ipv4Addr, SocketAddr, ToSocketAddrs};
use std::os::raw::c_char;
use std::sync::{LazyLock, Mutex, OnceLock};
use std::time::Duration;

use tokio::io::copy_bidirectional;
use tokio::net::{TcpListener, TcpStream};
use tokio::runtime::Runtime;
use tokio::task::JoinHandle;

mod error;

use error::Error;

static RT: LazyLock<Runtime> = LazyLock::new(|| Runtime::new().unwrap());

static AVAILABLE_RULE_IDS: LazyLock<Mutex<Vec<i8>>> = LazyLock::new(|| {
    let mut pool = Vec::with_capacity(128);
    pool.extend(0..=127);
    Mutex::new(pool)
});

static RUNNING_RULES: LazyLock<Mutex<HashMap<i8, JoinHandle<()>>>> =
    LazyLock::new(|| Mutex::new(HashMap::with_capacity(128)));

static ERROR_HANDLER: OnceLock<extern "C" fn(i8, i8)> = OnceLock::new();

/// Get a new rule ID.
#[inline]
fn get_new_rule_id() -> Option<i8> {
    AVAILABLE_RULE_IDS.lock().unwrap().pop()
}

/// Make a rule ID available again.
#[inline]
fn release_rule_id(rule_id: i8) {
    AVAILABLE_RULE_IDS.lock().unwrap().push(rule_id);
}

/// Check if an IP address is valid.
#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub extern "C" fn ipf_check_ip_is_valid(ip_c_string: *const c_char) -> bool {
    let ip_str = unsafe {
        if let Ok(ip_str) = CStr::from_ptr(ip_c_string).to_str() {
            ip_str
        } else {
            return false;
        }
    };

    ip_str.parse::<IpAddr>().is_ok()
}

/// Forward a TCP port to another IP address.
#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub extern "C" fn ipf_forward(
    address_c_string: *const c_char,
    remote_port: u16,
    local_port: u16,
    allow_lan: bool,
) -> i8 {
    let addr_str = unsafe {
        match CStr::from_ptr(address_c_string).to_str() {
            Ok(addr_str) => addr_str,
            Err(_) => return Error::InvalidString as i8,
        }
    };
    let socket_addr = match addr_str.parse::<IpAddr>() {
        Ok(ip) => SocketAddr::new(ip, remote_port),
        Err(_) => match (addr_str, remote_port).to_socket_addrs() {
            Ok(mut socket_addrs) => match socket_addrs.next() {
                Some(addr) => addr,
                None => return Error::AddressCantBeResolved as i8,
            },
            Err(_) => return Error::AddressCantBeResolved as i8,
        },
    };

    let rule_id = match get_new_rule_id() {
        Some(id) => id,
        None => return Error::TooManyRules as i8,
    };

    let bind_ip = if allow_lan {
        IpAddr::V4(Ipv4Addr::UNSPECIFIED)
    } else {
        IpAddr::V4(Ipv4Addr::LOCALHOST)
    };

    let join_handler = RT.spawn(async move {
        match TcpListener::bind(SocketAddr::new(bind_ip, local_port)).await {
            Ok(listener) => run_accept_loop(rule_id, listener, socket_addr).await,
            Err(error) => {
                if let Some(error_handler) = ERROR_HANDLER.get() {
                    error_handler(rule_id, Error::from(error) as i8);
                }
            }
        }
    });

    RUNNING_RULES.lock().unwrap().insert(rule_id, join_handler);

    rule_id
}

/// Report an accept error once per this many consecutive failures so transient
/// hiccups stay quiet while a persistent failure mode still surfaces to the UI.
const ACCEPT_ERROR_REPORT_INTERVAL: u32 = 100;

async fn run_accept_loop(rule_id: i8, listener: TcpListener, target: SocketAddr) {
    let mut consecutive_errors: u32 = 0;
    loop {
        match listener.accept().await {
            Ok((mut ingress, _)) => {
                consecutive_errors = 0;
                if let Ok(mut egress) = TcpStream::connect(target).await {
                    RT.spawn(async move {
                        _ = copy_bidirectional(&mut ingress, &mut egress).await;
                    });
                }
            }
            Err(error) => {
                if consecutive_errors % ACCEPT_ERROR_REPORT_INTERVAL == 0 {
                    if let Some(handler) = ERROR_HANDLER.get() {
                        handler(rule_id, Error::from(error) as i8);
                    }
                }
                consecutive_errors = consecutive_errors.saturating_add(1);
                // Backoff briefly to avoid spinning on transient errors such
                // as EMFILE (too many open files) or EINTR.
                tokio::time::sleep(Duration::from_millis(100)).await;
            }
        }
    }
}

/// Cancel a forward rule.
#[no_mangle]
pub extern "C" fn ipf_cancel_forward(forward_rule_id: i8) -> i8 {
    let join_handler = RUNNING_RULES.lock().unwrap().remove(&forward_rule_id);
    if let Some(join_handler) = join_handler {
        release_rule_id(forward_rule_id);
        join_handler.abort();
        forward_rule_id
    } else {
        Error::InvalidRuleId as i8
    }
}

/// Register a callback that will be invoked when a forward rule fails.
#[no_mangle]
pub extern "C" fn ipf_register_error_handler(handler: extern "C" fn(i8, i8)) -> i8 {
    if ERROR_HANDLER.set(handler).is_ok() {
        0
    } else {
        Error::HandlerAlreadyRegistered as i8
    }
}
