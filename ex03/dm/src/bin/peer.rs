//! Tasks 1 & 2: a node that announces itself, discovers peers, publishes a hello
//! message and prints hellos from the other nodes.

use std::collections::BTreeSet;
use std::time::Duration;

use anyhow::Result;
use clap::Parser;
use ex03::{NODES_GLOB, SessionArgs, node_key, node_name};
use zenoh::sample::SampleKind;

const HELLO_PREFIX: &str = "ex03/hello";
const HELLO_GLOB: &str = "ex03/hello/*";

#[derive(Parser, Debug)]
struct Args {
    /// Unique application name, e.g. A, B, C.
    #[arg(long)]
    name: String,

    /// How often to publish "Hello from Node <name>" (milliseconds).
    #[arg(long, default_value_t = 2000)]
    hello_ms: u64,

    /// How often to print the set of currently known peers (milliseconds).
    #[arg(long, default_value_t = 5000)]
    peers_ms: u64,

    #[command(flatten)]
    session: SessionArgs,
}

/// The application-level peer table. Kept in sync from liveliness events.
#[derive(Debug)]
struct PeerSet {
    me: String,
    alive: BTreeSet<String>,
}

impl PeerSet {
    fn new(me: &str) -> Self {
        Self { me: me.to_string(), alive: BTreeSet::new() }
    }

    fn apply(&mut self, peer: &str, kind: SampleKind) {
        match kind {
            SampleKind::Put if self.alive.insert(peer.to_string()) => {
                println!("[{}] peer joined: {peer}", self.me);
            }
            SampleKind::Delete if self.alive.remove(peer) => {
                println!("[{}] peer left: {peer}", self.me);
            }
            _ => {}
        }
    }

    fn list(&self) -> String {
        self.alive.iter().cloned().collect::<Vec<_>>().join(", ")
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    zenoh::init_log_from_env_or("warn");
    let args = Args::parse();
    let session = ex03::open_session(&args.session).await?;
    println!(
        "[{}] session opened (zid {})",
        args.name,
        session.info().zid().await
    );

    // Subscribe before announcing ourselves, so no early message can be lost.
    let hello = session
        .declare_subscriber(HELLO_GLOB)
        .await
        .map_err(|err| anyhow::anyhow!("hello subscriber failed: {err}"))?;
    let me = args.name.clone();
    tokio::spawn(async move {
        while let Ok(sample) = hello.recv_async().await {
            let sender = sample
                .key_expr()
                .as_str()
                .strip_prefix("ex03/hello/")
                .unwrap_or("?");
            if sender == me {
                continue;
            }
            let payload = sample
                .payload()
                .try_to_string()
                .unwrap_or_else(|err| err.to_string().into());
            println!("[{me}] hello rx from {sender}: {payload}");
        }
    });

    // Watch every node's liveliness token. `history(true)` replays tokens of nodes
    // that were already alive before we started.
    let discovery = session
        .liveliness()
        .declare_subscriber(NODES_GLOB)
        .history(true)
        .await
        .map_err(|err| anyhow::anyhow!("discovery subscriber failed: {err}"))?;

    // Announce ourselves. The token disappears automatically when this process exits.
    let _token = session
        .liveliness()
        .declare_token(node_key(&args.name))
        .await
        .map_err(|err| anyhow::anyhow!("liveliness token failed: {err}"))?;
    println!("[{}] announced as {}", args.name, node_key(&args.name));

    // Task 2: publish our hello message periodically.
    let publisher = session.clone();
    let name = args.name.clone();
    let hello_key = format!("{HELLO_PREFIX}/{name}");
    let hello_ms = args.hello_ms;
    tokio::spawn(async move {
        loop {
            let payload = format!("Hello from Node {name}");
            match publisher.put(&hello_key, payload.clone()).await {
                Ok(()) => println!("[{name}] hello tx: {payload}"),
                Err(err) => eprintln!("[{name}] hello tx failed: {err}"),
            }
            tokio::time::sleep(Duration::from_millis(hello_ms)).await;
        }
    });

    // Task 1: react to discovery events and periodically print the peer set.
    let me = args.name.clone();
    let mut peers = PeerSet::new(&args.name);
    let mut tick = tokio::time::interval(Duration::from_millis(args.peers_ms));
    loop {
        tokio::select! {
            sample = discovery.recv_async() => {
                let Ok(sample) = sample else { break };
                let Some(peer) = node_name(sample.key_expr().as_str()) else { continue };
                if peer == me {
                    continue;
                }
                println!("[{me}] discovery event: {:?} {}", sample.kind(), peer);
                peers.apply(peer, sample.kind());
            }
            _ = tick.tick() => {
                println!("[{me}] known peers: [{}]", peers.list());
            }
        }
    }

    Ok(())
}
