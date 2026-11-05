//! Shared plumbing for both exercise binaries: Zenoh session setup and discovery.

use std::time::{Duration, Instant};

use anyhow::{bail, Result};
use clap::Parser;
use zenoh::Session;

/// All application nodes announce themselves below this prefix, e.g. `ex03/nodes/A`.
pub const NODES_PREFIX: &str = "ex03/nodes";
pub const NODES_GLOB: &str = "ex03/nodes/**";

pub fn node_key(name: &str) -> String {
    format!("{NODES_PREFIX}/{name}")
}

pub fn node_name(key: &str) -> Option<&str> {
    key.strip_prefix(NODES_PREFIX)?.strip_prefix('/')
}

/// Command-line flags that control how Zenoh connects. Flattened into each binary's args.
///
/// Default behaviour: peer mode, multicast scouting enabled, so nodes find each other
/// on the local network without any address.
#[derive(Parser, Debug, Clone, Default)]
pub struct SessionArgs {
    /// Endpoint to connect to, e.g. `tcp/127.0.0.1:7447` (comma separated).
    #[arg(long, value_delimiter = ',')]
    pub connect: Vec<String>,

    /// Endpoint to listen on, e.g. `tcp/0.0.0.0:7448` (comma separated).
    #[arg(long, value_delimiter = ',')]
    pub listen: Vec<String>,

    /// Disable UDP multicast scouting (needed when multicast is blocked/undesired).
    #[arg(long)]
    pub no_multicast: bool,
}

impl SessionArgs {
    pub fn config(&self) -> Result<zenoh::Config> {
        let mut config = zenoh::Config::default();
        if !self.connect.is_empty() {
            config.insert_json5(
                "connect/endpoints",
                &serde_json::json!(self.connect).to_string(),
            )
            .map_err(|err| anyhow::anyhow!("invalid connect/endpoints: {err}"))?;
        }
        if !self.listen.is_empty() {
            config.insert_json5(
                "listen/endpoints",
                &serde_json::json!(self.listen).to_string(),
            )
            .map_err(|err| anyhow::anyhow!("invalid listen/endpoints: {err}"))?;
        }
        if self.no_multicast {
            config
                .insert_json5("scouting/multicast/enabled", "false")
                .map_err(|err| anyhow::anyhow!("invalid scouting config: {err}"))?;
        }
        Ok(config)
    }
}

pub async fn open_session(args: &SessionArgs) -> Result<Session> {
    zenoh::open(args.config()?)
        .await
        .map_err(|err| anyhow::anyhow!("failed to open Zenoh session: {err}"))
}

/// Ask the system which application nodes are currently alive (liveliness tokens).
pub async fn discovered_nodes(session: &Session) -> Result<Vec<String>> {
    let replies = session
        .liveliness()
        .get(NODES_GLOB)
        .await
        .map_err(|err| anyhow::anyhow!("liveliness query failed: {err}"))?;
    let mut names = Vec::new();
    while let Ok(reply) = replies.recv_async().await {
        if let Ok(sample) = reply.result() {
            if let Some(name) = node_name(sample.key_expr().as_str()) {
                names.push(name.to_string());
            }
        }
    }
    names.sort();
    names.dedup();
    Ok(names)
}

/// Block until every name in `wanted` has announced itself, or fail after `timeout`.
pub async fn wait_for_nodes(
    session: &Session,
    wanted: &[String],
    timeout: Duration,
) -> Result<()> {
    let deadline = Instant::now() + timeout;
    loop {
        let found = discovered_nodes(session).await?;
        if wanted.iter().all(|name| found.contains(name)) {
            return Ok(());
        }
        if Instant::now() >= deadline {
            bail!("timed out waiting for {wanted:?}; currently alive: {found:?}");
        }
        tokio::time::sleep(Duration::from_millis(200)).await;
    }
}
