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
  local function idiv(a, b) return math.floor(a / b) end
  local function from_jdn(j)
    -- Hinnant civil_from_days (expects days since 1970 epoch; JDN offset 2440588)
    local z = j - 2440588 + 719468
    local era = (z >= 0) and idiv(z, 146097) or idiv(z - 146096, 146097)
    local doe = z - era * 146097
    local yoe = idiv(doe - idiv(doe, 1460) + idiv(doe, 36524) - idiv(doe, 146096), 365)
    local y = yoe + era * 400
    local doy = doe - (365 * yoe + idiv(yoe, 4) - idiv(yoe, 100))
    local mp = idiv(5 * doy + 2, 153)
    local d = doy - idiv(153 * mp + 2, 5) + 1
    local m = (mp < 10) and (mp + 3) or (mp - 9)
    if y <= 0 then y = y - 1 end
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
  local out = {success = true, bars = out_bars, bars_returned = total}
  if body.next_page_token ~= nil and body.next_page_token ~= "" then
    out.next_page_token = body.next_page_token
    out.note = "more pages exist — pass page_token to continue"
  end
  return out
end