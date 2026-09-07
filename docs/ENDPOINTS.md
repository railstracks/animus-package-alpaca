# Alpaca API surface — endpoint notes & phasing

Working notes for expanding the package command surface. Sources: Melvin's doc sweep (Sept 7) + live probes against paper API.

## Phase 1 — assets (today)

### `GET /v2/assets` — list assets
Live-verified (Sept 7):
- **33,538 total** (33,465 us_equity + 73 crypto). 14,350 with `status=active`.
- Exchanges: OTC 17,470 / NASDAQ 6,896 / NYSE 3,766 / ARCA 3,197 / BATS 1,749 / AMEX 387
- Server-side filters DO exist: `status`, `asset_class`, `exchange` — but **no text search** → client-side.
- 17 fields per asset; we return ~6 compact ones (symbol, name, exchange, class, tradable, fractionable).

Command design `assets list`:
- Server passthrough: `status` (default `active` — inactive is mostly noise), `class`, `exchange`
- Client-side: `search` (case-insensitive substring on symbol OR name), `limit` (default 20), `offset`
- Response: `total` (post-filter), `returned`, `offset`, compact rows — an agent turn must never see 33k objects (context poison).

`asset get` (single by symbol/uuid) already exists since v1.0.

## Phase 1 — market data, stock + crypto (today/rest of week)

Two data hosts, both key-authenticated:
- Stocks: `https://data.alpaca.markets/v2/stocks/*`
- Crypto: `https://data.alpaca.markets/v1beta3/crypto/us/*`

Docs in Melvin's sweep:
| Endpoint | Doc | Notes |
|---|---|---|
| Stock bars (historical) | stockbars.md | timeframe, start/end, adjustment, feed; limit 10k bars/page |
| Stock latest bars | stocklatestbars-1.md | snapshot per symbol |
| Stock latest quotes | stocklatestquotes-1.md | bid/ask snapshot |
| Stock latest trades | stocklatesttrades-1.md | last trade per symbol |
| Stock trades (historical) | stocktrades-1.md | |
| Stock meta conditions | stockmetaconditions-1.md | market condition codes (reference data) |
| News | news-3.md | per-symbol news, free tier limited |
| Crypto bars | cryptobars-1.md | v1beta3, timeframe 1Min..1Day |
| Crypto latest bars | cryptolatestbars-1.md | already used by the poller connection |
| Crypto latest orderbooks | cryptolatestorderbooks-1.md | bids/asks depth |
| Crypto latest trades | cryptolatesttrades-1.md | |
| Crypto quotes | cryptoquotes-1.md | historical |
| Crypto trades | cryptotrades-1.md | historical |

Command shape (proposed):
- Unified `bars` — routes by symbol shape (`contains "/"` → crypto endpoint, per TIF/position-close convention). Params: symbols (comma list), timeframe, start/end, limit.
- `latest` family: `latest bar`, `latest quote`, `latest trade` (quote/trade route stock↔crypto by symbol). Crypto-only: `orderbook`.
- `news` — symbols, limit.
- Pagination honesty: Alpaca paginates bars (page tokens / next_page_token); expose `next_token` passthrough rather than auto-fetching all pages (bounded context, agent decides).

## Phase 2+ — later (protracted)

- **Options**: get-options-contracts.md, get-option-contract-symbol_or_id.md — chain snapshots, greeks. Separate surface, do after stock+crypto data is stable.
- **Fixed income / forex**: not yet scoped.
- **Streaming (websocket) market data**: would replace/supplement the poller connections; needs the daemon-side websocket connection type first (ApiConnectionManager gap).

## Adjacent (NOT this package)

- **Technical indicators** (SMA/RSI/EMA/...): not Alpaca's surface → out of purview here. Natural home: **Steadyfort** revamped as on-demand indicator service (it has DataPools + pipeline machinery + Finsight export precedent). Future agent surface: a second api package (`steadyfort-indicators`?) so Buffett composes raw bars ← alpaca, derived signals ← steadyfort. Steadyfort do-over is its own project conversation.

## Decisions
- Symbol-shape routing (`/` → crypto) is the established convention (TIF default, position close fallback) — reuse everywhere.
- Client-side search/pagination only where API lacks filters (assets confirmed).
- Every list command defaults to compact + bounded (limit default ≤ 20, total always reported).

## API quirks banked (live-verified Sept 7)

- **v2 stock bars REQUIRE `start`** — no default lookback; omit it and you get `{"bars":{}}` (silently). Package defaults: crypto 7d, stock 30d lookback when caller omits start.
- **IEX feed (paper/free tier) serves ~20 days** of daily stock history. `sip` returns empty silently (not entitled); `otc` 403s explicitly.
- **Multi-symbol bars page symbol-by-symbol** — all pages of symbol 1, then symbol 2. `next_page_token` continues; limit applies per page, not per symbol.
- **News lives under `v1beta1`** (not v1beta3 like the crypto data): `data.alpaca.markets/v1beta1/news`.
- **Crypto without `start`** returns only the current partial bar.
- **Animus Lua sandbox quirks:** `os.date` ignores its time argument (always "now") and inserts a literal `!` prefix — date arithmetic needs JDN calendar math (Hinnant civil-from-days, verified against python). Arg validation runs at manifest level before scripts.
- **Lua HTTP client body cap** was 1MB (KernelConfig) — raised to 32MB; assets list (~7MB) was silently truncated before.
