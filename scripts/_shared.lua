-- alpaca / shared helpers (inlined at build time — the sandbox has no require)
--
-- Auth: Alpaca REST uses APCA-API-KEY-ID + APCA-API-SECRET-KEY headers.
-- base_url: https://paper-api.alpaca.markets (paper) / https://api.alpaca.markets (live)

local M = {}

-- Build the standard headers from state.
function M.headers(pkg)
  return {
    ["APCA-API-KEY-ID"] = pkg.get_state("key_id"),
    ["APCA-API-SECRET-KEY"] = pkg.get_state("secret_key"),
    ["Content-Type"] = "application/json"
  }
end

function M.base_url(pkg)
  local paper = pkg.get_state("paper")
  if paper == false or paper == "false" then
    return "https://api.alpaca.markets"
  end
  local base = pkg.get_state("base_url")
  if base ~= nil and base ~= "" and base ~= "***" then return base end
  return "https://paper-api.alpaca.markets"
end

-- GET a JSON API path; returns table {status, json, body, error}.
function M.get(pkg, http, path)
  return http.get(M.base_url(pkg) .. path, {headers = M.headers(pkg)})
end

-- POST/PUT/DELETE with JSON body; body is a Lua table.
function M.send(pkg, http, method, path, body)
  local opts = {headers = M.headers(pkg)}
  if body ~= nil then opts.body = json.encode(body) end
  if method == "POST" then return http.post(M.base_url(pkg) .. path, opts) end
  if method == "PUT" then return http.put(M.base_url(pkg) .. path, opts) end
  if method == "DELETE" then return http.delete(M.base_url(pkg) .. path, opts) end
  return {status = 0, error = "unknown method " .. tostring(method)}
end

-- Fail fast when credentials are absent — clearer than a 401 round trip.
function M.require_auth(pkg)
  local key_id = pkg.get_state("key_id")
  local secret = pkg.get_state("secret_key")
  if key_id == nil or key_id == "" or secret == nil or secret == "" then
    return false
  end
  return true
end

return M