#!/usr/bin/env python3
"""Field-test driver: sends a task brief to the Animus daemon agent over the
admin chat WS and records everything the agent does until completion."""
import json
import sys
import time

import websocket

TOKEN = open('/home/melvin/projects/animus/.dev-admin-token').read().strip()
URL = f'ws://127.0.0.1:8080/ws/chat?token={TOKEN}'

BRIEF = """Systematic field test of the alpaca api package. Work through it carefully:

1. Run `api alpaca account get`, `api alpaca positions list`, `api alpaca orders list`, `api alpaca clock get`, `api alpaca asset get` (for BTC/USD and one stock symbol like AAPL). Verify each response parses and the numbers look sane for a paper account.

2. `api alpaca watchlist list` - check the tracked symbols. Add one (e.g. SOL/USD), then remove it again. Verify both operations.

3. `api alpaca order place`: place ONE small paper buy of BTC/USD, notional around $150 (use a fractional qty). Then `orders list` to verify it shows. Then cancel it. Then verify it is gone from open orders. (Paper trading only - safe.)

4. `api alpaca trigger add`: arm one above-trigger for ETH/USD at a price well above current so it does NOT fire. `trigger list` to verify it shows armed. Then `trigger remove` it.

5. Probing: try one deliberately malformed invocation of your choice (e.g. wrong arg type) and note how the error surfaces.

At the end, write a concise findings report:
- What worked (one line each)
- What was confusing, broken, or rough (detail: exact command, what came back, what you expected)
- Any missing capability you wanted but lacked
Keep it under 300 words. Do not modify credentials (token set) or delete/reinstall anything."""

log = open('/tmp/field-test-log.jsonl', 'a')

def on_message(ws, message):
    try:
        data = json.loads(message)
    except Exception:
        data = {'type': 'raw', 'text': message[:500]}
    data['_ts'] = time.time()
    log.write(json.dumps(data, default=str)[:8000] + '\n')
    log.flush()
    t = data.get('type', '')
    if t in ('done', 'stopped', 'error', 'complete', 'finished'):
        print(f'[driver] terminal event: {t}', flush=True)
        ws.close()

def on_error(ws, error):
    print(f'[driver] ws error: {error}', flush=True)

def on_close(ws, code, reason):
    print(f'[driver] closed: {code} {reason}', flush=True)

def on_open(ws):
    print('[driver] connected; sending brief', flush=True)
    ws.send(json.dumps({'type': 'message', 'content': BRIEF, 'agent_id': '61cdbd234a859375914816228473df9f'}))
    print('[driver] brief sent; streaming agent run...', flush=True)

ws = websocket.WebSocketApp(URL, on_open=on_open, on_message=on_message,
                            on_error=on_error, on_close=on_close)
ws.run_forever()
print('[driver] done', flush=True)
