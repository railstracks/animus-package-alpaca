-- test_http_error.lua — run with: lua5.4 tests/test_http_error.lua
-- Covers shared.http_error (v1.4.2): the Sept 14 blind spot — scripts
-- returned "HTTP 0" and discarded r.error, hiding curl's actual verdict.

local shared = dofile("scripts/_shared.lua")

local failures = 0
local function check(label, got, want)
  if got ~= want then
    print("FAIL  " .. label .. ": got " .. tostring(got) .. ", want " .. tostring(want))
    failures = failures + 1
  else
    print("ok    " .. label)
  end
end

-- transport failure: curl error string rides along
check("timeout surfaces reason",
  shared.http_error({status = 0, error = "Operation timed out"}),
  "HTTP 0 (Operation timed out)")
-- budget block: framework message rides along
check("budget block surfaces reason",
  shared.http_error({status = 0, error = "secondary http budget exhausted (5 calls per invocation)"}),
  "HTTP 0 (secondary http budget exhausted (5 calls per invocation))")
-- clean HTTP error response (e.g. 400 with JSON body): no r.error, unchanged
check("plain 400 unchanged",
  shared.http_error({status = 400}),
  "HTTP 400")
-- empty-string error (defensive): unchanged
check("empty error string unchanged",
  shared.http_error({status = 0, error = ""}),
  "HTTP 0")

if failures > 0 then
  print("\n" .. failures .. " FAILURES")
  os.exit(1)
end
print("\nall ok")
