-- PESONA LOADER — Anime Dice
-- Usage: loadstring(game:HttpGet("https://raw.githubusercontent.com/annandgz/pesona-scripts/main/loader.lua"))()
local BRANCH = "main"
local BASE = "https://raw.githubusercontent.com/annandgz/pesona-scripts/" .. BRANCH .. "/"

local function get(p)
    return game:HttpGetAsync(BASE .. p)
end

-- main farm
local ok, err = pcall(function()
    loadstring(get("anime_dice.lua"))()
end)
if not ok then warn("[PESONA] farm load failed: " .. tostring(err)) end
