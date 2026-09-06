function run(ctx)
  local raw = ctx.package.get_state("watchlist") or "[]"
  local ok, list = pcall(json.decode_safe, raw)
  if not ok or type(list) ~= "table" then list = {} end
  return {success = true, count = #list, symbols = list}
end
