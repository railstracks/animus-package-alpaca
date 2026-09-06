function run(ctx)
  if not shared.require_auth(ctx.package) then
    return {success = false, error = "credentials not configured (key_id, secret_key)"}
  end
  local r = shared.send(ctx.package, ctx.http, "DELETE", "/v2/orders/" .. ctx.args.order_id, nil)
  if r.status == 200 or r.status == 204 then
    return {success = true, output = "order " .. ctx.args.order_id .. " cancelled"}
  end
  return {success = false, http_status = r.status, error = "HTTP " .. tostring(r.status), data = r.json}
end
