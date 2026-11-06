//! Task 3: Byzantine generals over Zenoh.
//!
//! Three-node case: commander + two lieutenants, one round of oral messages.
//! Four-node case: commander + three lieutenants, loyals decide by majority.
//!
//! One round of oral messages; the traitor flags make nodes lie on purpose.
//!
//! Rust has no preprocessor. The `#[...]` lines are *attributes* (built-in macros) that decorate
//! the item below them: `#[derive(Parser)]` generates the clap CLI parser, `#[arg(...)]` is read by
//! that generated parser, `#[serde(...)]` configures the JSON encoding. Ordinary `//` comments.

use std::collections::HashMap;
use std::str::FromStr;
use std::time::{Duration, Instant};

use anyhow::{Context, Result, bail};
use rand::Rng;
use clap::{Parser, ValueEnum};
use ex03::{SessionArgs, node_key};
use serde::{Deserialize, Serialize};
use zenoh::Session;
use zenoh::handlers::FifoChannelHandler;
use zenoh::pubsub::Subscriber;
use zenoh::sample::Sample;

#[derive(Parser, Debug)]
struct Args {
    /// Unique name, e.g. c, l1, l2, l3.
    #[arg(long)]
    name: String,

    #[arg(long, value_enum)]
    role: Role,

    /// Node name of the commander (needed by lieutenants).
    #[arg(long)]
    commander: Option<String>,

    /// Comma-separated lieutenant names, e.g. l1,l2 or l1,l2,l3.
    #[arg(long, value_delimiter = ',')]
    lieutenants: Vec<String>,

    /// The commander's intended order (default: attack).
    #[arg(long, value_enum, default_value_t = Order::Attack)]
    order: Order,

    #[arg(long)]
    traitor: bool,

    /// Commander only: split orders, e.g. --lie l1=attack,l2=retreat.
    #[arg(long)]
    lie: Option<String>,

    /// Lieutenant only: forward a different order than received.
    #[arg(long, value_enum)]
    forward_lie: Option<Order>,

    /// Be random instead of deterministic (traitor only).
    #[arg(long)]
    chaos: bool,

    /// How long to wait for the other nodes to show up.
    #[arg(long, default_value_t = 10_000)]
    startup_timeout_ms: u64,

    /// How long to wait for missing messages before deciding anyway.
    #[arg(long, default_value_t = 2_000)]
    collect_timeout_ms: u64,

    /// How long the commander keeps running after sending its orders.
    #[arg(long, default_value_t = 500)]
    settle_ms: u64,

    #[command(flatten)]
    session: SessionArgs,
}

#[derive(ValueEnum, Clone, Copy, Debug, PartialEq, Eq)]
enum Role {
    Commander,
    Lieutenant,
}

#[derive(Serialize, Deserialize, ValueEnum, Clone, Copy, Debug, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
enum Order {
    Attack,
    Retreat,
}

impl std::fmt::Display for Order {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(match self {
            Order::Attack => "attack",
            Order::Retreat => "retreat",
        })
    }
}

impl FromStr for Order {
    type Err = anyhow::Error;

    fn from_str(s: &str) -> Result<Self> {
        match s {
            "attack" => Ok(Order::Attack),
            "retreat" => Ok(Order::Retreat),
            other => bail!("unknown order {other:?} (expected attack or retreat)"),
        }
    }
}

#[derive(Serialize, Deserialize, Debug)]
struct Msg {
    from: String,
    round: u8,
    order: Order,
}

type Inbox = Subscriber<FifoChannelHandler<Sample>>;

impl Args {
    fn lies(&self) -> Result<HashMap<String, Order>> {
        let Some(spec) = &self.lie else {
            return Ok(HashMap::new());
        };
        spec.split(',')
            .map(|pair| {
                let (name, order) = pair
                    .split_once('=')
                    .with_context(|| format!("--lie expects name=order, got {pair:?}"))?;
                Ok((name.trim().to_string(), order.trim().parse::<Order>()?))
            })
            .collect()
    }

    /// What the commander sends lieutenant `lieutenant` in round 0.
    fn order_for(&self, lieutenant: &str, lies: &HashMap<String, Order>) -> Order {
        if !self.traitor {
            return self.order;
        }
        if self.chaos {
            return random_order();
        }
        lies.get(lieutenant).copied().unwrap_or(self.order)
    }

    /// What a lieutenant forwards in round 1, given what it received.
    fn forward_for(&self, received: Order) -> Order {
        if !self.traitor {
            return received;
        }
        if self.chaos {
            return random_order();
        }
        self.forward_lie.unwrap_or(received)
    }

    /// The lieutenant's final decision, given all values it holds.
    fn decide(&self, values: &[Order]) -> Order {
        let attacks = values.iter().filter(|o| **o == Order::Attack).count();
        if attacks * 2 > values.len() {
            Order::Attack
        } else if (values.len() - attacks) * 2 > values.len() {
            Order::Retreat
        } else {
            Order::Retreat // 1-1 tie: no majority, stay on the safe order
        }
    }
}

fn random_order() -> Order {
    if rand::rng().random_bool(0.5) { Order::Attack } else { Order::Retreat }
}

fn decode(sample: &Sample) -> Result<Msg> {
    let payload = sample
        .payload()
        .try_to_string()
        .map_err(|err| anyhow::anyhow!("payload is not a string: {err}"))?;
    Ok(serde_json::from_str(&payload)?)
}

async fn send(
    session: &Session,
    from: &str,
    to: &str,
    round: u8,
    order: Order,
) -> Result<()> {
    let key = format!("ex03/byz/{to}");
    let msg = Msg {
        from: from.to_string(),
        round,
        order,
    };
    session
        .put(&key, serde_json::to_string(&msg)?)
        .await
        .map_err(|err| anyhow::anyhow!("put to {key} failed: {err}"))?;
    Ok(())
}

#[tokio::main]
async fn main() -> Result<()> {
    zenoh::init_log_from_env_or("warn");
    let args = Args::parse();
    let name = args.name.clone();

    match args.role {
        Role::Commander => {
            if args.lieutenants.is_empty() {
                bail!("commander needs --lieutenants");
            }
            if args.lieutenants.contains(&name) {
                bail!("--name {name} cannot also be a lieutenant");
            }
        }
        Role::Lieutenant => {
            if args.commander.is_none() {
                bail!("lieutenant needs --commander");
            }
            if !args.lieutenants.contains(&name) {
                bail!("--name {name} must be listed in --lieutenants");
            }
            if args.lieutenants.len() < 2 {
                bail!("need at least two lieutenants");
            }
        }
    }

    let session = ex03::open_session(&args.session).await?;
    println!("[{name}] session opened (zid {})", session.info().zid().await);
    println!(
        "[{name}] role {:?} commander={:?} lieutenants={:?} traitor={} chaos={} lie={:?} forward_lie={:?}",
        args.role,
        args.commander,
        args.lieutenants,
        args.traitor,
        args.chaos,
        args.lie,
        args.forward_lie,
    );

    // Subscribe before announcing ourselves, then become discoverable.
    let inbox_key = format!("ex03/byz/{name}");
    let inbox = session
        .declare_subscriber(&inbox_key)
        .await
        .map_err(|err| anyhow::anyhow!("inbox subscriber failed: {err}"))?;
    let _token = session
        .liveliness()
        .declare_token(node_key(&name))
        .await
        .map_err(|err| anyhow::anyhow!("liveliness token failed: {err}"))?;
    println!("[{name}] announced as {}, inbox {inbox_key}", node_key(&name));

    match args.role {
        Role::Commander => run_commander(&args, &session).await,
        Role::Lieutenant => run_lieutenant(&args, &session, &inbox).await,
    }
}

async fn run_commander(args: &Args, session: &Session) -> Result<()> {
    let me = &args.name;
    ex03::wait_for_nodes(
        session,
        &args.lieutenants,
        Duration::from_millis(args.startup_timeout_ms),
    )
    .await?;
    println!("[{me}] all lieutenants are alive, sending orders");

    let lies = args.lies()?;
    for lt in &args.lieutenants {
        let order = args.order_for(lt, &lies);
        send(session, me, lt, 0, order).await?;
        println!("[{me}] -> {lt}: {order} (round 0)");
    }

    tokio::time::sleep(Duration::from_millis(args.settle_ms)).await;
    println!("[{me}] done");
    Ok(())
}

async fn run_lieutenant(args: &Args, session: &Session, inbox: &Inbox) -> Result<()> {
    let me = args.name.clone();
    let commander = args
        .commander
        .clone()
        .context("lieutenant without --commander")?;
    let peers: Vec<String> = args
        .lieutenants
        .iter()
        .filter(|lt| **lt != me)
        .cloned()
        .collect();

    let mut wanted = vec![commander.clone()];
    wanted.extend(peers.iter().cloned());
    ex03::wait_for_nodes(
        session,
        &wanted,
        Duration::from_millis(args.startup_timeout_ms),
    )
    .await?;
    println!("[{me}] commander {commander} and peers {peers:?} are alive");

    // --- round 0: wait for the commander's order ---------------------------
    let wait_until = Instant::now() + Duration::from_millis(args.startup_timeout_ms);
    let mut received: Option<Order> = None;
    let mut forwards: HashMap<String, Order> = HashMap::new();

    while received.is_none() {
        let timeout = wait_until.saturating_duration_since(Instant::now());
        if timeout.is_zero() {
            bail!("[{me}] no commander order arrived");
        }
        match tokio::time::timeout(timeout, inbox.recv_async()).await {
            Ok(Ok(sample)) => {
                let msg = decode(&sample)?;
                if msg.round == 0 {
                    println!("[{me}] commander {} says {}", msg.from, msg.order);
                    received = Some(msg.order);
                } else if peers.contains(&msg.from) {
                    println!("[{me}] early forward from {}: {}", msg.from, msg.order);
                    forwards.entry(msg.from).or_insert(msg.order);
                }
            }
            Ok(Err(err)) => bail!("[{me}] inbox closed: {err}"),
            Err(_) => bail!("[{me}] no commander order arrived"),
        }
    }
    let received = received.expect("loop exits only with an order");

    // --- round 1: forward to every other lieutenant ------------------------
    let forward_value = args.forward_for(received);
    for peer in &peers {
        send(session, &me, peer, 1, forward_value).await?;
        println!("[{me}] -> {peer}: {forward_value} (round 1)");
    }

    // --- collect the other lieutenants' forwards ---------------------------
    let collect_until = Instant::now() + Duration::from_millis(args.collect_timeout_ms);
    while forwards.len() < peers.len() {
        let timeout = collect_until.saturating_duration_since(Instant::now());
        if timeout.is_zero() {
            eprintln!(
                "[{me}] warning: only {}/{} forwards arrived",
                forwards.len(),
                peers.len()
            );
            break;
        }
        match tokio::time::timeout(timeout, inbox.recv_async()).await {
            Ok(Ok(sample)) => {
                let msg = decode(&sample)?;
                if msg.round == 1 && peers.contains(&msg.from) {
                    println!("[{me}] forward from {}: {}", msg.from, msg.order);
                    forwards.entry(msg.from).or_insert(msg.order);
                }
            }
            Ok(Err(err)) => bail!("[{me}] inbox closed: {err}"),
            Err(_) => {
                eprintln!(
                    "[{me}] warning: only {}/{} forwards arrived",
                    forwards.len(),
                    peers.len()
                );
                break;
            }
        }
    }

    let mut values = vec![received];
    values.extend(forwards.values().copied());
    let shown = values
        .iter()
        .map(ToString::to_string)
        .collect::<Vec<_>>()
        .join(", ");
    println!(
        "[{me}] holds [{shown}] (commander + {} forwards)",
        forwards.len()
    );

    let decision = args.decide(&values);
    println!("[{me}] DECISION {decision}");
    Ok(())
}
