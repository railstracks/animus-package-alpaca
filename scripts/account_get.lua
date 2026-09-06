function run(ctx)
  if not shared.require_auth(ctx.package) then
    return {success = false, error = "credentials not configured (key_id, secret_key)"}
  end
  local r = shared.get(ctx.package, ctx.http, "/v2/account")
  if r.status ~= 200 then
    return {success = false, http_status = r.status, error = "HTTP " .. tostring(r.status), data = r.json}
  end
  local a = r.json or {}
  local out = {
    equity = a.equity,
    cash = a.cash,
    buying_power = a.buying_power,
    portfolio_value = a.portfolio_value,
    unrealized_pl = a.unrealized_pl,
    unrealized_plpc = a.unrealized_plpc,
    realized_pl = a.realized_pl,
    trading_blocked = a.trading_blocked,
    account_blocked = a.account_blocked
  }
  return {success = true, data = out, raw = a}
end
