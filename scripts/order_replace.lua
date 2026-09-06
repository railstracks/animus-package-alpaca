function run(ctx)
  if not shared.require_auth(ctx.package) then
    return {success = false, error = "credentials not configured (key_id, secret_key)"}
  end
  local a = ctx.args
  local body = {}
  if a.qty ~= nil then body.qty = a.qty end
  if a.limit_price ~= nil then body.limit_price = a.limit_price end
  if a.stop_price ~= nil then body.stop_price = a.stop_price end
  if a.time_in_force ~= nil then body.time_in_force = a.time_in_force end
  local r = shared.send(ctx.package, ctx.http, "PATCH", "/v2/orders/" .. a.order_id, body)
  if r.status ~= 200 and r.status ~= 207 then
    return {success = false, http_status = r.status, error = "HTTP " .. tostring(r.status), data = r.json}
  end
  return {success = true, data = r.json}
end
