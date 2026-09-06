function run(ctx)
  local raw = ctx.package.get_state("watchlist") or "[]"
  local ok, list = pcall(json.decode_safe, raw)
  if not ok or type(list) ~= "table" then list = {} end
  local symbol = string.upper(ctx.args.symbol)
  for i, s in ipairs(list) do
    if s == symbol then
      return {success = true, output = symbol .. " already tracked", count = #list, symbols = list}
    end
  end
  table.insert(list, symbol)
  ctx.package.set_state("watchlist", json.encode(list))
  return {success = true, output = symbol .. " added to watchlist", count = #list, symbols = list}
end
