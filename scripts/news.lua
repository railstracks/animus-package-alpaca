function run(ctx)
  if not shared.require_auth(ctx.package) then
    return {success = false, error = "credentials not configured (key_id, secret_key)"}
  end
  local a = ctx.args
  local limit = tonumber(a.limit or "10") or 10
  if limit < 1 then limit = 1 end
  if limit > 50 then limit = 50 end

  local params = {"limit=" .. limit}
  if a.symbols ~= nil and a.symbols ~= "" then table.insert(params, "symbols=" .. tostring(a.symbols)) end
  if a.start ~= nil and a.start ~= "" then table.insert(params, "start=" .. tostring(a.start)) end
  if a.stop ~= nil and a.stop ~= "" then table.insert(params, "end=" .. tostring(a.stop)) end
  if a.sort ~= nil and a.sort ~= "" then table.insert(params, "sort=" .. tostring(a.sort)) end
  if a.page_token ~= nil and a.page_token ~= "" then table.insert(params, "page_token=" .. tostring(a.page_token)) end

  local r = shared.data_get(ctx.package, ctx.http, "/v1beta3/news?" .. table.concat(params, "&"))
  if r.status ~= 200 then
    return {success = false, http_status = r.status, error = "HTTP " .. tostring(r.status), data = r.json}
  end

  local body = r.json or {}
  local items = {}
  for _, n in ipairs(body.news or {}) do
    table.insert(items, {
      id = n.id,
      headline = n.headline,
      summary = n.summary,
      author = n.author,
      created_at = n.created_at,
      symbols = n.symbols,
      source = n.source
    })
  end
  local out = {success = true, news = items, count = #items}
  if body.next_page_token ~= nil and body.next_page_token ~= "" then
    out.next_page_token = body.next_page_token
  end
  return out
end