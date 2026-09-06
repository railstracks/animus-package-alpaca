function run(ctx)
  local raw = ctx.package.get_state("watchlist") or "[]"
  local ok, list = pcall(json.decode_safe, raw)
  if not ok or type(list) ~= "table" then list = {} end
  local symbol = string.upper(ctx.args.symbol)
  local out = {}
  for i, s in ipairs(list) do
    if s ~= symbol then table.insert(out, s) end
  end
  local ok, err = ctx.package.set_state("watchlist", json.encode(out))
  if not ok then return {success = false, error = "watchlist persist failed: " .. tostring(err)} end
  return {success = true, output = symbol .. (#out < #list and " removed from watchlist" or " not tracked"), count = #out, symbols = out}
end
