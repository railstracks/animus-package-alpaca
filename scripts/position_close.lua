function run(ctx)
  if not shared.require_auth(ctx.package) then
    return {success = false, error = "credentials not configured (key_id, secret_key)"}
  end
  local a = ctx.args
  -- Alpaca closes via market order: DELETE /v2/positions/{symbol}[?qty=...]
  -- qty is optional: with it, close partially; without, close the whole position.
  -- Crypto symbols: orders use "BTC/USD" but positions are keyed "BTCUSD" —
  -- retry with the slash stripped on 404 so callers can use either form.
  local path = "/v2/positions/" .. a.symbol
  if a.qty ~= nil and a.qty ~= "" then
    path = path .. "?qty=" .. tostring(a.qty)
  end
  local r = shared.send(ctx.package, ctx.http, "DELETE", path, nil)
  if r.status == 404 and string.find(a.symbol, "/", 1, true) then
    path = "/v2/positions/" .. string.gsub(a.symbol, "/", "")
    if a.qty ~= nil and a.qty ~= "" then
      path = path .. "?qty=" .. tostring(a.qty)
    end
    r = shared.send(ctx.package, ctx.http, "DELETE", path, nil)
  end
  if r.status ~= 200 and r.status ~= 201 and r.status ~= 204 then
    return {success = false, http_status = r.status, error = "HTTP " .. tostring(r.status), data = r.json}
  end
  -- 204 on paper sometimes returns empty body; 200 returns the closing order.
  local o = r.json or {}
  if r.status == 204 or o.id == nil then
    return {success = true, output = "close requested for " .. a.symbol .. (a.qty and (" qty " .. tostring(a.qty)) or " (full position)")}
  end
  return {
    success = true,
    data = {
      symbol = o.symbol,
      side = o.side,
      qty = o.qty,
      type = o.type,
      status = o.status,
      filled_qty = o.filled_qty,
      filled_avg_price = o.filled_avg_price
    },
    output = "position close order submitted for " .. tostring(o.symbol or a.symbol)
  }
end