//! brig·id `grove`: the server for a community, in a container.
//!
//! The server and its commands are `brigid-server` (core), the same for every
//! edition: grove runs exactly what seedling runs. What makes it grove is how
//! it is delivered (`Dockerfile.release`, `deploy/compose.yaml`) and run: in a
//! container, configured by its environment, its database on a volume
//! replicated continuously (`deploy/litestream.yml`), its metrics on an
//! internal port.

use std::path::PathBuf;

use clap::Parser;

mod embedded {
    include!(concat!(env!("OUT_DIR"), "/embedded_ui.rs"));
}

/// grove as an edition of the server.
const EDITION: brigid_server::Edition = brigid_server::Edition {
    name: "grove",
    version: env!("CARGO_PKG_VERSION"),
    ui: brigid_server::EmbeddedUi {
        files: embedded::FILES,
        csp_hashes: embedded::CSP_HASHES,
    },
    // A container is configured by its environment (`BRIGID_*`), and gets
    // its key from a mounted secret (`BRIGID_MASTER_KEY_FILE`).
    config_path: None,
    key_path: None,
    // A container's key is a mounted secret: never sealed by a machine.
    sealed_key_path: None,
    key_hint: " (with Docker: a secret, and BRIGID_MASTER_KEY_FILE=/run/secrets/<its name>)",
    root_hint: ": the image runs it as nonroot (65532).",
};

#[derive(Parser)]
#[command(
    name = "grove",
    version,
    about = "brig·id server for a community, in a container"
)]
struct Cli {
    /// Path to a TOML configuration file. Optional: a container is normally
    /// configured by `BRIGID_*` environment variables alone.
    #[arg(long, global = true)]
    config: Option<PathBuf>,

    #[command(subcommand)]
    command: Option<brigid_server::Command>,
}

#[tokio::main]
async fn main() {
    let cli = Cli::parse();
    brigid_server::run(&EDITION, cli.config, cli.command).await;
}
