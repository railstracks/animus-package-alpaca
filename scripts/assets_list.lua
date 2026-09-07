function run(ctx)
  if not shared.require_auth(ctx.package) then
    return {success = false, error = "credentials not configured (key_id, secret_key)"}
  end
  local a = ctx.args

  -- server-side filters (API supports status/asset_class/exchange; no text search)
  local q = {}
  local status = a.status or "active"
  if status ~= "all" then table.insert(q, "status=" .. tostring(status)) end
  if a.class ~= nil and a.class ~= "" then table.insert(q, "asset_class=" .. tostring(a.class)) end
  if a.exchange ~= nil and a.exchange ~= "" then table.insert(q, "exchange=" .. tostring(a.exchange)) end
  local path = "/v2/assets" .. (#q > 0 and ("?" .. table.concat(q, "&")) or "")

  local r = shared.get(ctx.package, ctx.http, path)
  if r.status ~= 200 then
    return {success = false, http_status = r.status, error = "HTTP " .. tostring(r.status), data = r.json}
  end

  -- client-side search: case-insensitive substring on symbol OR name
  local assets = r.json or {}
  local search = nil
  if a.search ~= nil and a.search ~= "" then search = string.lower(tostring(a.search)) end
  local filtered = {}
  for _, asset in ipairs(assets) do
    if search == nil
      or string.find(string.lower(tostring(asset.symbol or "")), search, 1, true)
      or string.find(string.lower(tostring(asset.name or "")), search, 1, true) then
      table.insert(filtered, asset)
    end
  end

  -- client-side pagination
  local limit = tonumber(a.limit or "20") or 20
  local offset = tonumber(a.offset or "0") or 0
  if limit < 1 then limit = 1 end
  if limit > 100 then limit = 100 end
  local rows = {}
  local last = math.min(offset + limit, #filtered)
  for i = offset + 1, last do
    local asset = filtered[i]
    table.insert(rows, {
      symbol = asset.symbol,
      name = asset.name,
      exchange = asset.exchange,
      class = asset.class,
      tradable = asset.tradable,
      fractionable = asset.fractionable
    })
  end

  local out = {
    success = true,
    total = #filtered,
    returned = #rows,
    offset = offset,
    limit = limit,
    data = rows
  }
  if #filtered > last then
    out.note = "truncated — use offset " .. last .. " for the next page"
  end
  return out
end