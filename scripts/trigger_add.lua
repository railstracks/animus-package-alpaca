function run(ctx)
  local a = ctx.args
  local condition = string.lower(a.condition)
  if condition ~= "below" and condition ~= "above" then
    return {success = false, error = "condition must be 'below' or 'above'"}
  end
  local threshold = tonumber(a.threshold)
  if threshold == nil then
    return {success = false, error = "threshold must be numeric"}
  end
  -- Persist as JSON in state (schema-typed string, like watchlist).
  local raw = ctx.package.get_state("triggers") or "[]"
  local ok, list = pcall(json.decode_safe, raw)
  if not ok or type(list) ~= "table" then list = {} end
  local trigger = {
    id = "trg-" .. tostring(ctx.now) .. "-" .. tostring(#list + 1),
    symbol = string.upper(a.symbol),
    condition = condition,
    threshold = threshold,
    prompt = a.prompt,
    status = "armed",
    created_at = ctx.now
  }
  table.insert(list, trigger)
  ctx.package.set_state("triggers", json.encode(list))

  -- Ensure the symbol is tracked so the poller watches it.
  local wraw = ctx.package.get_state("watchlist") or "[]"
  local wok, wlist = pcall(json.decode_safe, wraw)
  if not wok or type(wlist) ~= "table" then wlist = {} end
  local tracked = false
  for i, s in ipairs(wlist) do
    if s == trigger.symbol then tracked = true end
  end
  if not tracked then
    table.insert(wlist, trigger.symbol)
    ctx.package.set_state("watchlist", json.encode(wlist))
  end

  -- Current close for context (best effort; failure does not block arming).
  local last = nil
  if shared.require_auth(ctx.package) then
    local r = shared.get(ctx.package, ctx.http, "/v2/stocks/" .. trigger.symbol .. "/bars?timeframe=1Min&limit=1")
    if r.status == 200 and r.json ~= nil and r.json.bars ~= nil and #r.json.bars > 0 then
      last = r.json.bars[#r.json.bars].c
    end
  end

  return {
    success = true,
    output = "trigger armed: " .. trigger.symbol .. " " .. condition .. " " .. tostring(threshold),
    trigger = trigger,
    current_close = last,
    warning = last ~= nil and condition == "below" and last < threshold and
      "price is ALREADY below threshold — trigger will fire on the next poll" or nil
  }
end
