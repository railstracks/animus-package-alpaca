function run(ctx)
  if not shared.require_auth(ctx.package) then
    return {success = false, error = "credentials not configured (key_id, secret_key)"}
  end
  local r = shared.get(ctx.package, ctx.http, "/v2/assets/" .. ctx.args.symbol)
  if r.status ~= 200 then
    return {success = false, http_status = r.status, error = "HTTP " .. tostring(r.status), data = r.json}
  end
  local a = r.json or {}
  return {
    success = true,
    data = {
      symbol = a.symbol,
      name = a.name,
      exchange = a.exchange,
      tradable = a.tradable,
      marginable = a.marginable,
      shortable = a.shortable,
      price_increment = a.price_increment
    }
  }
end
