function run(ctx)
  if not shared.require_auth(ctx.package) then
    return {success = false, error = "credentials not configured (key_id, secret_key)"}
  end
  local path = "/v2/orders?status="
  if ctx.args.all == true or ctx.args.all == "true" then
    path = path .. "all"
  else
    path = path .. "open"
  end
  if ctx.args.limit ~= nil then
    path = path .. "&limit=" .. tostring(ctx.args.limit)
  end
  local r = shared.get(ctx.package, ctx.http, path)
  if r.status ~= 200 then
    return {success = false, http_status = r.status, error = "HTTP " .. tostring(r.status), data = r.json}
  end
  local rows = r.json or {}
  local out = {}
  for i, o in ipairs(rows) do
    table.insert(out, {
      id = o.id,
      symbol = o.symbol,
      side = o.side,
      qty = o.qty,
      type = o.type,
      status = o.status,
      limit_price = o.limit_price,
      filled_avg_price = o.filled_avg_price,
      created_at = o.created_at
    })
  end
  return {success = true, count = #out, data = out}
end
