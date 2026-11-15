-- PESONA DUMPER — Anime Dice event/network audit
-- Usage: loadstring(game:HttpGet("https://raw.githubusercontent.com/annandgz/pesona-scripts/main/dumper.lua"))()
local RS = game:GetService("ReplicatedStorage")
local out = {"=== NETWORK TREE ==="}
local function walk(node, depth)
    if depth > 4 then return end
    for _, c in ipairs(node:GetChildren()) do
        table.insert(out, string.rep("  ", depth) .. c.ClassName .. " | " .. c:GetFullName())
        walk(c, depth + 1)
    end
end
walk(RS:FindFirstChild("Network"), 0)
table.insert(out, "=== FRAMEWORK FEATURES ===")
local fw = RS:FindFirstChild("Framework")
if fw then walk(fw:FindFirstChild("Features") or fw, 1) end
table.insert(out, "=== PLAYER DATA KEYS ===")
local ok, dc = pcall(function() return require(fw.Features.Data.DataController) end)
if ok and dc and dc.___X then
    for k in pairs(dc.___X) do table.insert(out, tostring(k)) end
end
local text = table.concat(out, "\n")
if setclipboard then setclipboard(text) end
print(text)
if writefile then writefile("pesona_dump.txt", text) end
print("[PESONA] Dump done — copied to clipboard" .. (writefile and " + pesona_dump.txt" or ""))
