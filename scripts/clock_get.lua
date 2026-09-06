function run(ctx)
  if not shared.require_auth(ctx.package) then
    return {success = false, error = "credentials not configured (key_id, secret_key)"}
  end
  local r = shared.get(ctx.package, ctx.http, "/v2/clock")
  if r.status ~= 200 then
    return {success = false, http_status = r.status, error = "HTTP " .. tostring(r.status), data = r.json}
  end
  local c = r.json or {}
  return {
    success = true,
    data = {
      is_open = c.is_open,
      next_open = c.next_open,
      next_close = c.next_close,
      timestamp = c.timestamp
    }
  }
end
