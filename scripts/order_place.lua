function run(ctx)
  if not shared.require_auth(ctx.package) then
    return {success = false, error = "credentials not configured (key_id, secret_key)"}
  end
  local a = ctx.args
  if a.qty == nil and a.notional == nil then
    return {success = false, error = "either qty or notional is required (notional = dollar amount, e.g. 150 for $150 worth)"}
  end
  local body = {
    symbol = a.symbol,
    qty = a.qty,
    notional = a.notional,
    side = a.side,
    type = a.type or "market",
    time_in_force = a.time_in_force or "day"
  }
  if a.limit_price ~= nil then body.limit_price = a.limit_price end
  if a.stop_price ~= nil then body.stop_price = a.stop_price end
  if a.client_order_id ~= nil then body.client_order_id = a.client_order_id end
  local r = shared.send(ctx.package, ctx.http, "POST", "/v2/orders", body)
  if r.status ~= 200 and r.status ~= 201 then
    return {success = false, http_status = r.status, error = "HTTP " .. tostring(r.status), data = r.json}
  end
  local o = r.json or {}
  return {
    success = true,
    data = {
      id = o.id,
      symbol = o.symbol,
      side = o.side,
      qty = o.qty,
      type = o.type,
      status = o.status,
      limit_price = o.limit_price,
      filled_qty = o.filled_qty
    }
  }
end
