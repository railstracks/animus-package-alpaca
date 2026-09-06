function run(ctx)
  local raw = ctx.package.get_state("triggers") or "[]"
  local ok, list = pcall(json.decode_safe, raw)
  if not ok or type(list) ~= "table" then list = {} end
  local armed, fired = {}, {}
  for i, t in ipairs(list) do
    if t.status == "armed" then table.insert(armed, t) else table.insert(fired, t) end
  end
  return {success = true, armed = armed, fired = fired, armed_count = #armed}
end
