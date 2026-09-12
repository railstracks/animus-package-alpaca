-- test_base_url.lua — run with: lua5.4 tests/test_base_url.lua
-- Covers shared.normalize_base + shared.base_url (issue #72: /v2 doubling).

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

local function stub(state)
  return { get_state = function(k) return state[k] end }
end

-- normalize_base: the Sept 6 field mishap and friends
check("doubled /v2 (the mishap)",
  shared.normalize_base("https://paper-api.alpaca.markets/v2"),
  "https://paper-api.alpaca.markets")
check("doubled /v2 + trailing slash",
  shared.normalize_base("https://paper-api.alpaca.markets/v2/"),
  "https://paper-api.alpaca.markets")
check("trailing slash only",
  shared.normalize_base("https://paper-api.alpaca.markets/"),
  "https://paper-api.alpaca.markets")
check("clean base untouched",
  shared.normalize_base("https://paper-api.alpaca.markets"),
  "https://paper-api.alpaca.markets")
check("custom host untouched",
  shared.normalize_base("http://localhost:3000"),
  "http://localhost:3000")
check("custom host with /v2",
  shared.normalize_base("http://localhost:3000/v2"),
  "http://localhost:3000")
check("live host with /v2",
  shared.normalize_base("https://api.alpaca.markets/v2"),
  "https://api.alpaca.markets")
check("non-numeric version segment kept (/v1beta3-style)",
  shared.normalize_base("https://example.internal/v1beta3"),
  "https://example.internal/v1beta3")
check("two version segments: only the last stripped",
  shared.normalize_base("https://h.internal/v1/v2"),
  "https://h.internal/v1")

-- base_url: state routing
check("no state -> paper default",
  shared.base_url(stub({})), "https://paper-api.alpaca.markets")
check("paper=false -> live host",
  shared.base_url(stub({paper = false})), "https://api.alpaca.markets")
check('paper="false" -> live host',
  shared.base_url(stub({paper = "false"})), "https://api.alpaca.markets")
check("paper=true with doubled /v2 base -> normalized paper",
  shared.base_url(stub({paper = true, base_url = "https://paper-api.alpaca.markets/v2"})),
  "https://paper-api.alpaca.markets")
check("masked sentinel -> default (not '***')",
  shared.base_url(stub({base_url = "***"})), "https://paper-api.alpaca.markets")
check("empty string -> default",
  shared.base_url(stub({base_url = ""})), "https://paper-api.alpaca.markets")

if failures > 0 then
  print("\n" .. failures .. " failure(s)")
  os.exit(1)
end
print("\nall green")
