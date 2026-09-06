function run(ctx)
  if not shared.require_auth(ctx.package) then
    return {success = false, error = "credentials not configured (key_id, secret_key)"}
  end
  local a = ctx.args
  local r = shared.send(ctx.package, ctx.http, "GET", "/v2/orders/" .. a.order_id, nil)
  if r.status ~= 200 then
    return {success = false, http_status = r.status, error = "HTTP " .. tostring(r.status), data = r.json}
  end
  local o = r.json or {}
  return {
    success = true,
    data = {
      id = o.id,
      client_order_id = o.client_order_id,
      symbol = o.symbol,
      side = o.side,
      qty = o.qty,
      notional = o.notional,
      type = o.type,
      time_in_force = o.time_in_force,
      status = o.status,
      filled_qty = o.filled_qty,
      filled_avg_price = o.filled_avg_price,
      limit_price = o.limit_price,
      stop_price = o.stop_price,
      created_at = o.created_at,
      updated_at = o.updated_at,
      submitted_at = o.submitted_at,
      filled_at = o.filled_at,
      canceled_at = o.canceled_at,
      expired_at = o.expired_at
    }
  }
end