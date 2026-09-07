-- alpaca / shared helpers (inlined at build time — the sandbox has no require)
--
-- Auth: Alpaca REST uses APCA-API-KEY-ID + APCA-API-SECRET-KEY headers.
-- base_url: https://paper-api.alpaca.markets (paper) / https://api.alpaca.markets (live)

local shared = {}

-- Build the standard headers from state.
function shared.headers(pkg)
  return {
    ["APCA-API-KEY-ID"] = pkg.get_state("key_id"),
    ["APCA-API-SECRET-KEY"] = pkg.get_state("secret_key"),
    ["Content-Type"] = "application/json"
  }
end

function shared.base_url(pkg)
  local paper = pkg.get_state("paper")
  if paper == false or paper == "false" then
    return "https://api.alpaca.markets"
  end
  local base = pkg.get_state("base_url")
  if base ~= nil and base ~= "" and base ~= "***" then return base end
  return "https://paper-api.alpaca.markets"
end

-- GET a JSON API path; returns table {status, json, body, error}.
function shared.get(pkg, http, path)
  return http.get(shared.base_url(pkg) .. path, {headers = shared.headers(pkg)})
end

-- Data API host (bars/quotes/trades/news) — distinct from the trading host.
function shared.data_get(pkg, http, path)
  return http.get("https://data.alpaca.markets" .. path, {headers = shared.headers(pkg)})
end

-- Compact one bar row (Alpaca: t,o,h,l,c,v, n optional)
function shared.bar_row(b)
  return {t = b.t, o = b.o, h = b.h, l = b.l, c = b.c, v = b.v}
end

-- Route a symbol list to asset class by the first symbol's shape.
-- "/" → crypto (v1beta3), otherwise stock (v2). One call = one class.
function shared.is_crypto(symbols)
  return string.find(tostring(symbols), "/", 1, true) ~= nil
end

-- Latest snapshot family: kind = "bar" | "quote" | "trade".
function shared.latest_impl(ctx, kind)
  if not shared.require_auth(ctx.package) then
    return {success = false, error = "credentials not configured (key_id, secret_key)"}
  end
  local a = ctx.args
  if a.symbols == nil or a.symbols == "" then
    return {success = false, error = "symbols required (comma-separated, one asset class per call)"}
  end

  local path
  if shared.is_crypto(a.symbols) then
    local ep = ({bar = "bars", quote = "quotes", trade = "trades"})[kind]
    path = "/v1beta3/crypto/us/latest/" .. ep .. "?symbols=" .. tostring(a.symbols)
  elseif kind == "bar" then
    path = "/v2/stocks/bars/latest?symbols=" .. tostring(a.symbols) .. "&feed=" .. (a.feed or "iex")
  else
    local ep = ({quote = "quotes", trade = "trades"})[kind]
    path = "/v2/stocks/" .. ep .. "/latest?symbols=" .. tostring(a.symbols)
  end

  local r = shared.data_get(ctx.package, ctx.http, path)
  if r.status ~= 200 then
    return {success = false, http_status = r.status, error = "HTTP " .. tostring(r.status), data = r.json}
  end

  local body = r.json or {}
  local key = ({bar = "bars", quote = "quotes", trade = "trades"})[kind]
  local map = body[key] or {}
  local out = {success = true}
  if kind == "bar" then
    local compact = {}
    for sym, b in pairs(map) do
      if type(b) == "table" and b.c ~= nil then compact[tostring(sym)] = shared.bar_row(b) end
    end
    out[key] = compact
  else
    out[key] = map
  end
  return out
end

-- POST/PUT/DELETE with JSON body; body is a Lua table.
function shared.send(pkg, http, method, path, body)
  local opts = {headers = shared.headers(pkg)}
  if body ~= nil then opts.body = json.encode(body) end
  if method == "POST" then return http.post(shared.base_url(pkg) .. path, opts) end
  if method == "PUT" then return http.put(shared.base_url(pkg) .. path, opts) end
  if method == "DELETE" then return http.delete(shared.base_url(pkg) .. path, opts) end
  return {status = 0, error = "unknown method " .. tostring(method)}
end

-- Fail fast when credentials are absent — clearer than a 401 round trip.
function shared.require_auth(pkg)
  local key_id = pkg.get_state("key_id")
  local secret = pkg.get_state("secret_key")
  if key_id == nil or key_id == "" or secret == nil or secret == "" then
    return false
  end
  return true
end

return shared