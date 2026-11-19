//! grove runs the shared server and says it is grove: start the real binary,
//! as a container would (environment only, key from a file), and ask it.

use std::{
    io::{Read as _, Write as _},
    net::{TcpListener, TcpStream},
    process::{Child, Command, Stdio},
    time::{Duration, Instant},
};

const KEY: &str = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

struct Server(Child);

impl Drop for Server {
    fn drop(&mut self) {
        let _ = self.0.kill();
        let _ = self.0.wait();
    }
}

fn free_port() -> u16 {
    TcpListener::bind("127.0.0.1:0")
        .unwrap()
        .local_addr()
        .unwrap()
        .port()
}

/// `GET path` on the local server: the status code and the body.
fn get(port: u16, path: &str) -> Option<(u16, String)> {
    let mut stream = TcpStream::connect(("127.0.0.1", port)).ok()?;
    stream.set_read_timeout(Some(Duration::from_secs(5))).ok()?;
    write!(
        stream,
        "GET {path} HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
    )
    .ok()?;
    let mut response = String::new();
    stream.read_to_string(&mut response).ok()?;
    let status = response.split(' ').nth(1)?.parse().ok()?;
    let body = response.split("\r\n\r\n").nth(1).unwrap_or("").to_owned();
    Some((status, body))
}

#[test]
fn grove_serves_the_shared_server_under_its_own_name() {
    let dir = tempfile::tempdir().unwrap();
    let key_file = dir.path().join("master.key");
    std::fs::write(&key_file, KEY).unwrap();
    let port = free_port();

    let _server = Server(
        Command::new(env!("CARGO_BIN_EXE_grove"))
            .env_clear()
            .env("PATH", std::env::var("PATH").unwrap_or_default())
            .env("BRIGID_MASTER_KEY_FILE", &key_file)
            .env("BRIGID_SERVER__DOMAIN", "localhost")
            .env("BRIGID_SERVER__HOST", "127.0.0.1")
            .env("BRIGID_SERVER__PORT", port.to_string())
            .env(
                "BRIGID_DATABASE__PATH",
                dir.path().join("brigid.db").to_str().unwrap(),
            )
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()
            .expect("start grove"),
    );

    let deadline = Instant::now() + Duration::from_secs(30);
    loop {
        if let Some((200, _)) = get(port, "/health") {
            break;
        }
        assert!(Instant::now() < deadline, "grove did not answer /health");
        std::thread::sleep(Duration::from_millis(100));
    }

    let (status, body) = get(port, "/auth/server").expect("GET /auth/server");
    assert_eq!(status, 200, "{body}");
    assert!(body.contains(r#""edition":"grove""#), "{body}");
    assert!(
        body.contains(&format!(r#""version":"{}""#, env!("CARGO_PKG_VERSION"))),
        "{body}"
    );

    // The probe the image runs, through the same binary.
    let probe = Command::new(env!("CARGO_BIN_EXE_grove"))
        .args(["healthcheck", "--port", &port.to_string()])
        .status()
        .unwrap();
    assert!(probe.success());
}
