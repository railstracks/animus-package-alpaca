-- Hook: connection on_message — one-shot trigger evaluation.
-- ctx.event carries the latest bars for watchlisted symbols. For each bar,
-- check armed triggers; a matching condition flips the trigger to "fired"
-- (deactivation, not deletion — the fire log in the filespace keeps provenance)
-- and requests a dispatch of the stored prompt to the owning agent.
function run(ctx)
  local raw = ctx.package.get_state("triggers") or "[]"
  local ok, list = pcall(json.decode_safe, raw)
  if not ok or type(list) ~= "table" then list = {} end
  if #list == 0 then return {success = true, evaluated = 0} end

  local prices = {}
  local ev = ctx.event
  if type(ev) == "table" then
    if ev.symbol ~= nil and ev.close ~= nil then
      prices[string.upper(ev.symbol)] = tonumber(ev.close)
    elseif ev.bars ~= nil then
      -- Two response shapes exist:
      --   object map (crypto latest-bars): {["BTC/USD"] = {c = ...}}
      --   array (stock bars):              {{symbol = "...", c = ...}}
      for sym, b in pairs(ev.bars) do
        if type(b) == "table" then
          if b.c ~= nil then
            prices[string.upper(sym)] = tonumber(b.c)
          elseif b.symbol ~= nil and b.c ~= nil then
            prices[string.upper(b.symbol)] = tonumber(b.c)
          end
        end
      end
    end
  end

  local fired = {}
  local updated = false
  for i, t in ipairs(list) do
    if t.status == "armed" then
      local price = prices[t.symbol]
      if price ~= nil then
        local hit = (t.condition == "below" and price <= t.threshold) or
                    (t.condition == "above" and price >= t.threshold)
        if hit then
          t.status = "fired"
          t.fired_at = ctx.now
          t.fired_price = price
          updated = true
          table.insert(fired, {trigger = t, price = price})
        end
      end
    end
  end
  if updated then
    local ok, err = ctx.package.set_state("triggers", json.encode(list))
    if not ok then return {success = false, error = "trigger persist failed: " .. tostring(err)} end
  end

  -- Fire log: package filespace, provenance for the agent's journal.
  -- Dispatch directives: framework routes these to the owning agent.
  local dispatches = {}
  for i, f in ipairs(fired) do
    ctx.fs.write("fire_log-" .. tostring(ctx.now) .. ".json", json.encode({
      fired_at = ctx.now,
      trigger_id = f.trigger.id,
      symbol = f.trigger.symbol,
      condition = f.trigger.condition,
      threshold = f.trigger.threshold,
      price = f.price,
      prompt = f.trigger.prompt
    }))
    table.insert(dispatches, {
      reason = "price_trigger",
      symbol = f.trigger.symbol,
      condition = f.trigger.condition,
      threshold = f.trigger.threshold,
      price = f.price,
      prompt = f.trigger.prompt
    })
  end

  return {
    success = true,
    evaluated = #list,
    fired_count = #fired,
    dispatches = dispatches
  }
end
