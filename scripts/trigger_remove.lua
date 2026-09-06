function run(ctx)
  local raw = ctx.package.get_state("triggers") or "[]"
  local ok, list = pcall(json.decode_safe, raw)
  if not ok or type(list) ~= "table" then list = {} end
  local out, removed = {}, false
  for i, t in ipairs(list) do
    if t.id == ctx.args.trigger_id then
      removed = true
      -- deactivation, not deletion — provenance preserved for the fire log
      t.status = "disarmed"
    end
    table.insert(out, t)
  end
  local ok, err = ctx.package.set_state("triggers", json.encode(out))
  if not ok then return {success = false, error = "trigger persist failed: " .. tostring(err)} end
  return {
    success = removed,
    output = removed and ("trigger " .. ctx.args.trigger_id .. " disarmed") or ("no trigger " .. ctx.args.trigger_id)
  }
end
