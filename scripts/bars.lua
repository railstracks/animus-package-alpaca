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
  -- v2 stocks bars REQUIRE a start (no default lookback); crypto without start returns
  -- only the current partial bar. Default a bounded window when the caller omits start.
  -- Sandbox os.date ignores its time argument (always 'now'), so date arithmetic
  -- must be calendar math: Y-M-D -> Julian day number -> subtract -> back.
  local function jdn(y, m, d)
    local a = math.floor((14 - m) / 12)
    local yy = y + 4800 - a
    local mm = m + 12 * a - 3
    return d + math.floor((153 * mm + 2) / 5) + 365 * yy + math.floor(yy / 4) - math.floor(yy / 100) + math.floor(yy / 400) - 32045
  end
  local function from_jdn(j)
    local e = 4 * (j + 1401 + math.floor((math.floor(4 * j + 271279) / 146097) * 3 / 4) - 38) / 4 + 3
    local h = 4 * (j + 1) - math.floor(e / 1461)
    local m = math.floor((5 * math.floor(h / 153) - 2) / 5 + 3)
    local d = math.floor(h - math.floor((153 * m + 2) / 5) + 1)
    local y = math.floor(e / 1461) - 4716 + math.floor((12 - m + 2) / 12)
    return string.format("%04d-%02d-%02d", y, m, d)
  end
  local function days_ago(n)
    local now = os.date("!%Y-%m-%dT%H:%M:%SZ")
    if string.sub(now, 1, 1) == "!" then now = string.sub(now, 2) end
    local y = tonumber(string.sub(now, 1, 4))
    local m = tonumber(string.sub(now, 6, 7))
    local d = tonumber(string.sub(now, 9, 10))
    return from_jdn(jdn(y, m, d) - n)
  end
  local is_crypto = shared.is_crypto(a.symbols)
  if (a.start == nil or a.start == "") and (a.stop == nil or a.stop == "") then
    table.insert(params, "start=" .. days_ago(is_crypto and 7 or 30))
  end
  if a.start ~= nil and a.start ~= "" then table.insert(params, "start=" .. tostring(a.start)) end
  if a.stop ~= nil and a.stop ~= "" then table.insert(params, "end=" .. tostring(a.stop)) end
  if a.page_token ~= nil and a.page_token ~= "" then table.insert(params, "page_token=" .. tostring(a.page_token)) end

  local path
  if is_crypto then
    path = "/v1beta3/crypto/us/bars?" .. table.concat(params, "&")
  else
    table.insert(params, "feed=" .. (a.feed or "iex"))
    if a.adjustment ~= nil and a.adjustment ~= "" then table.insert(params, "adjustment=" .. tostring(a.adjustment)) end
    path = "/v2/stocks/bars?" .. table.concat(params, "&")
  end

  local r = shared.data_get(ctx.package, ctx.http, path)
  local dbg = {path = path}
  if r.status ~= 200 then
    return {success = false, http_status = r.status, error = "HTTP " .. tostring(r.status), data = r.json}
  end

  local body = r.json or {}
  local barsMap = body.bars or {}
  local out_bars = {}
  local total = 0  if type(barsMap) == "table" then
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
  local out = {success = true, bars = out_bars, bars_returned = total, debug = dbg}
  if body.next_page_token ~= nil and body.next_page_token ~= "" then
    out.next_page_token = body.next_page_token
    out.note = "more pages exist — pass page_token to continue"
  end
  return out
end