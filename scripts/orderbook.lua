function run(ctx)
  if not shared.require_auth(ctx.package) then
    return {success = false, error = "credentials not configured (key_id, secret_key)"}
  end
  local a = ctx.args
  if a.symbols == nil or a.symbols == "" then
    return {success = false, error = "symbols required (crypto only, e.g. BTC/USD)"}
  end
  if not shared.is_crypto(a.symbols) then
    return {success = false, error = "orderbooks are crypto-only — pass symbols like BTC/USD"}
  end
  local depth = tonumber(a.depth or "10") or 10
  if depth < 1 then depth = 1 end
  if depth > 50 then depth = 50 end

  local r = shared.data_get(ctx.package, ctx.http, "/v1beta3/crypto/us/latest/orderbooks?symbols=" .. tostring(a.symbols))
  if r.status ~= 200 then
    return {success = false, http_status = r.status, error = "HTTP " .. tostring(r.status), data = r.json}
  end

  local books = (r.json or {}).orderbooks or {}
  local out = {success = true, orderbooks = {}}
  for sym, ob in pairs(books) do
    if type(ob) == "table" then
      local function top_n(list)
        local rows = {}
        if type(list) == "table" then
          for i = 1, math.min(depth, #list) do table.insert(rows, list[i]) end
        end
        return rows
      end
      out.orderbooks[tostring(sym)] = {t = ob.t, bids = top_n(ob.b), asks = top_n(ob.a)}
    end
  end
  return out
end