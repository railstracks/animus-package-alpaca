# animus-package-alpaca

Alpaca brokerage API package for Animus agents (manifest v1, api_package kind).

Probe and commit Alpaca data; organize dispatches. The package is an adapter:
no strategy logic, no logging frameworks — the owning agent's workspace documents
carry picks, expectations, and outcomes. All trading commands are active calls
against Alpaca's REST API (paper or live, per the `paper` state toggle).

## Commands

**Portfolio (probe):** `account get`, `positions list`, `orders list`, `asset get`, `clock get`

**Orders (commit):** `order place`, `order cancel`, `order replace`

**Watchlist:** `watchlist list/add/remove` — symbols tracked by the price poller

**Triggers (one-shot dispatches):** `trigger add/list/remove`
- A trigger is `{symbol, condition: above|below, threshold, prompt}` stored in
  package state, `status: armed`
- The `on price update` hook evaluates each poll: first condition hit flips the
  trigger to `fired` (deactivation, not deletion — provenance preserved)
- Each fire appends a record to the package filespace (fire log)
- Firing requests a dispatch of the stored prompt to the owning agent
- One-shot IS the debounce: no repeated prompts while price stays beyond
  threshold. Triggers are best-effort accelerators — periodic portfolio checks
  remain the backstop.

## State schema

| key | secret | notes |
|---|---|---|
| `key_id` | yes | Alpaca API key ID (APCA-API-KEY-ID header) |
| `secret_key` | yes | Alpaca secret key (APCA-API-SECRET-KEY header) |
| `paper` | no | true = paper trading (default) |
| `base_url` | no | override; defaults per `paper` |
| `watchlist` | no | JSON array of symbols |
| `triggers` | no | JSON array of trigger records |

Secrets are operator-configured (admin UI state editor / admin API) — the agent
api surface never reads or writes them.

## Repo layout

```
manifest/manifest.json   repo form (script_file references)
scripts/*.lua            sources; _shared.lua inlined at build
build.py                 emits built/manifest.json (standalone scripts)
built/manifest.json      publishable single-file manifest
```

Publish: POST built/manifest.json to the Animus Registry /api/v1/packages/publish,
or POST manifest/manifest.json with base_dir=repo root (registry inlines scripts).

## Connection

REST polling only. Alpaca's websocket serves trade updates (crypto bars only) —
minute bars for equities come from `/v2/stocks/{symbol}/bars`, polled at
`interval_s: 60` by the connection runtime into the `on price update` hook.