function run(ctx)
  if not shared.require_auth(ctx.package) then
    return {success = false, error = "credentials not configured (key_id, secret_key)"}
  end
  local a = ctx.args
  if a.symbols == nil or a.symbols == "" then
    return {success = false, error = "symbols required (comma-separated, one asset class per call)"}
  end
  local timeframe = a.timeframe or "1Hour"
  local limit = tonumber(a.limit or "100") or 100
  if limit < 1 then limit = 1 end
  if limit > 1000 then limit = 1000 end

  local params = {"symbols=" .. tostring(a.symbols), "timeframe=" .. timeframe, "limit=" .. limit}
  if a.start ~= nil and a.start ~= "" then table.insert(params, "start=" .. tostring(a.start)) end
  if a.stop ~= nil and a.stop ~= "" then table.insert(params, "end=" .. tostring(a.stop)) end
  if a.page_token ~= nil and a.page_token ~= "" then table.insert(params, "page_token=" .. tostring(a.page_token)) end

  local path
  if shared.is_crypto(a.symbols) then
    path = "/v1beta3/crypto/us/bars?" .. table.concat(params, "&")
  else
    table.insert(params, "feed=" .. (a.feed or "iex"))
    if a.adjustment ~= nil and a.adjustment ~= "" then table.insert(params, "adjustment=" .. tostring(a.adjustment)) end
    path = "/v2/stocks/bars?" .. table.concat(params, "&")
  end

  local r = shared.data_get(ctx.package, ctx.http, path)
  if r.status ~= 200 then
    return {success = false, http_status = r.status, error = "HTTP " .. tostring(r.status), data = r.json}
  end

  local body = r.json or {}
  local barsMap = body.bars or {}
  local out_bars = {}
  local total = 0
  if type(barsMap) == "table" then
    for sym, arr in pairs(barsMap) do
      if type(arr) == "table" then
        local rows = {}
        for _, b in ipairs(arr) do
          table.insert(rows, shared.bar_row(b))
          total = total + 1
        end
        out_bars[tostring(sym)] = rows
      end
    end
  end
  local out = {success = true, bars = out_bars, bars_returned = total}
  if body.next_page_token ~= nil and body.next_page_token ~= "" then
    out.next_page_token = body.next_page_token
    out.note = "more pages exist — pass page_token to continue"
  end
  return out
end