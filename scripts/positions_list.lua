function run(ctx)
  if not shared.require_auth(ctx.package) then
    return {success = false, error = "credentials not configured (key_id, secret_key)"}
  end
  local r = shared.get(ctx.package, ctx.http, "/v2/positions")
  if r.status ~= 200 then
    return {success = false, http_status = r.status, error = "HTTP " .. tostring(r.status), data = r.json}
  end
  local rows = r.json or {}
  local out = {}
  for i, p in ipairs(rows) do
    table.insert(out, {
      symbol = p.symbol,
      qty = p.qty,
      avg_entry = p.avg_entry_price,
      current = p.current_price,
      market_value = p.market_value,
      unrealized_pl = p.unrealized_pl,
      unrealized_plpc = p.unrealized_plpc,
      side = p.side
    })
  end
  return {success = true, count = #out, data = out}
end
