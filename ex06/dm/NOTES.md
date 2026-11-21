# UC3 notes / gotchas

Short list of things that cost time or are easy to get wrong. Move anything
useful into the final `README.md`; delete the rest.

## CSM / Cirrina
- Duplicate persistent init: Each container evaluates the
  `persistent` block; the first `etcd` write wins, the other two log
  `variable '...' already exists or failed to create`. Harmless, but noisy.
- `ZENOH_EVENT_HANDLER_CONFIG_URI` is a file path (or URL to the config file), so I pass the mounted file path, e.g. `/zenoh.json5` (`tcp://zenoh:7447` would be wrong)
- Startup race is mostly covered by Zenoh history. Cirrina uses `HistoryConfig(detectLatePublishers = true)` and a cache of 1000 samples. But I still start inventory/payment before the coordinator
- `std:randomAround(550, 250)` gives the required 300–800 ms window
- `Timeout` is attached to the `checking`/`charging` state and is canceled when the state is left, so it does not leak into the next request.
- A `Transition` (handle event) without `to` is internal: no exit/entry actions run. Useful for result handling without leaving the current state.

NOTE:
`docker compose down` without an etcd volume resets persistent state; `stop`/`start` keeps it. Use a volume only if you want to demonstrate restart persistence deliberately.


- In stock JEXL, `orders += { ... }` does **not** merge maps (it stringifies).
  Cirrina adds map-merge arithmetic. For CSML persistent variables use
  `orders = orders + { ... }`: element assignment mutates only a deserialized
  copy and is not written back to etcd.


## Dapr

- Pub/sub is at-least-once: The same result can arrive twice; make state
  transitions idempotent (ignore a result that is no longer expected for that
  order) and guard terminal transitions.
- `getState` + `saveState` is not atomic. Read-modify-write of the `orders`
  map needs the returned ETag / a conditional update, or a single writer.
  The coordinator is the natural single writer.
- Default serializer is Jackson without the Kotlin module. Deserializing a
  Kotlin `data class` from state or a subscription can fail. The templates use `Map<String, String>` on purpose.
- Three apps need three sidecar port pairs. The defaults (3500/50001)
  collide; the run script uses 3500/50001, 3501/50002, 3502/50003.
- Streaming subscriptions (`buildPreviewClient().subscribeToTopic(...)`) need
  no `--app-port` and no HTTP server, but the process must stay alive
  (`.blockLast()`).


## End-to-end CSML runs (2026-11-21)

- Bind mounts needed `:z` on this Fedora host. Without it, Cirrina failed with
  `io.zenoh.exceptions.ZError: Permission denied (os error 13)` when opening
  `zenoh.json5`. Fixed with `../src:/app:ro,z` and
  `./zenoh.json5:/zenoh.json5:ro,z`.
- Do not mount a file *inside* `/app` when `/app` is itself a read-only bind
  mount; Docker cannot create the mountpoint. The Zenoh config is mounted at
  `/zenoh.json5` instead and `ZENOH_EVENT_HANDLER_CONFIG_URI=/zenoh.json5`.
- First run (pre-fix): only Order 1 completed. Inventory/payment accept one request and sit in
  `checking`/`charging`; the other five `inventory-request` events arrive while
  the service is busy and are ignored. The coordinator then waits forever with
  five orders still `PENDING`.
- Run logs: `docker compose logs -f coordinator inventory payment`.
- After ~90 s the etcd client logs `GOAWAY ... ENHANCE_YOUR_CALM ... too_many_pings` and backs off keepalive to 60 s. This is harmless; it is not the reason the run stalls.

## Second run (fixed)

- Inventory/payment now queue requests and process them one at a time; the
  coordinator reaches `done`.
- Result: Order 1, 2, 4, 6 `COMPLETED`; Order 3 `REJECTED` by inventory;
  Order 5 `REJECTED` by payment. Order 3 never reaches payment.
- `always` is a list of transitions. Writing `always { to = ... }` fails with
  `Object of type 'Listing' cannot have a property`; wrap it:
  `always { new Transition { to = ... } }`. The Pkl error includes line and
  caret, so this one is easy to fix.
- `transient { ["queue"] = "[]" }` gives a Java array, not an `ArrayList`.
  `queue.add(...)` fails with `JEXL error : add`; `queue += [...]` concatenates.
  Use `new('java.util.ArrayList')`, then `.add(...)` / `.remove(0)`.
- Persistent-map gotcha: `orders['Order 1'] = 'CHECKING'` mutates only the
  deserialized copy returned by the etcd context; the write is not stored.
  Assign the whole variable instead:
  `orders = orders + { 'Order 1': 'CHECKING' }` or
  `orders = orders + { ($orderId): 'PAYMENT' }`. This was the main blocker:
  the assignment "worked" (the expression returned the new value) but the
  next read still saw `PENDING`.
- Error-message quality: Pkl parse errors are good (file, line, caret,
  explanation). CSML runtime errors are poor: unhandled events and failed
  guards are silently ignored, so missing log lines are the only clue.

## Dapr end-to-end run (2026-11-21)

- First compile error: `No 'set' operator method providing array access` at
  `Coordinator.kt:20`. `State.getValue()` returns `Map<String, String>` (read-only);
  use `toMutableMap()` before `currentOrders[id] = ...`.
- Subscribe **before** publishing. The default Redis pub/sub has no replay:
  a result published before `subscribeToTopic` is active is lost. The
  coordinator subscribes, waits 500 ms, then submits the six orders.
- Do not `Thread.sleep` inside `doOnNext` for the 300–800 ms delay: it blocks
  the Reactor/gRPC thread. Use `Mono.delay(...).then(client.publishEvent(...))`
  with `concatMap` to process requests one at a time without blocking.
- `Flux.merge(...).blockLast()` never returns for an open-ended subscription.
  The coordinator uses `.subscribe()` plus a `CountDownLatch`, and disposes
  after the summary.
- Inventory/payment are long-lived; the coordinator is the one that exits.
  `run.sh` therefore waits only for the coordinator, then the trap kills the
  other two apps/sidecars.
- Successful run: Order 1, 2, 4, 6 `COMPLETED`; Order 3 `REJECTED` by
  inventory; Order 5 `REJECTED` by payment. Coordinator printed the summary
  and exited 0, about 4 s after starting.
- Dapr CLI was installed locally at `.work/dapr/bin/dapr`; `dapr init
  --runtime-version 1.19.1` started `dapr_redis`, `dapr_placement`,
  `dapr_scheduler`, `dapr_zipkin`. Add `.work/dapr/bin` to `PATH` for
  `run.sh`, or install the CLI normally.

## Experiment (10 runs each, 2026-11-21)

- All 20 runs were correct (4 `COMPLETED`, Orders 3/5 `REJECTED`).
- Dapr: median processing 4.00 s (3.51–4.26 s), mean startup 21.52 s,
  mean wall 26.21 s.
- CSML: median processing 4.77 s (4.03–5.29 s), mean startup 8.81 s,
  mean wall 25.31 s.
- Dapr is ~0.8 s faster from first submission to summary, but CSML starts
  ~12.7 s faster; end-to-end wall time is almost equal.
- CSML's processing spread is wider. The likely contributors are container/
  Zenoh scheduling and the transient queue versus one reactive chain per
  service; this was not isolated experimentally.
