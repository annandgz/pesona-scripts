--====================================================================
--  PESONA BRIDGE AGENT — remote executor control for Anime Dice
--  Run ONCE in Delta, keep the game open. The agent polls for commands
--  and returns results to the operator.
--  Stop with:  _G.__PB_OFF = true
--====================================================================
if _G.__PB_ALIVE then warn("[PESONA BRIDGE] already running") return end
_G.__PB_ALIVE = true
_G.__PB_OFF = false

local BASE  = "https://cheers-dvds-utah-len.trycloudflare.com"
local TOKEN = "pbr_TBpJZFo5ROGgyl2Ew2GMyDJM"
local SID   = "pesona-main"
local HS    = game:GetService("HttpService")
local RS    = game:GetService("ReplicatedStorage")
local LP    = game:GetService("Players").LocalPlayer

-- HTTP with executor fallbacks -------------------------------------
local function httpCall(url, method, body)
    local opts = {Url = url, Method = method or "GET", Headers = {["Content-Type"] = "application/json"}}
    if body then opts.Body = body end
    if type(request) == "function" then
        local ok, r = pcall(request, opts)
        if ok and r then return r.Body or r.body end
    end
    if type(syn) == "table" and type(syn.request) == "function" then
        local ok, r = pcall(syn.request, opts)
        if ok and r then return r.Body or r.body end
    end
    if type(http_request) == "function" then
        local ok, r = pcall(http_request, opts)
        if ok and r then return r.Body or r.body end
    end
    if (method or "GET") == "GET" then
        if type(HttpGet) == "function" then local ok, r = pcall(HttpGet, url) if ok then return r end end
        if type(game.HttpGet) == "function" then local ok, r = pcall(function() return game:HttpGet(url) end) if ok then return r end end
        if type(game.HttpGetAsync) == "function" then local ok, r = pcall(function() return game:HttpGetAsync(url) end) if ok then return r end end
    end
    return nil
end

-- helpers exposed to commands ---------------------------------------
local function walk(node, depth, maxDepth, out)
    depth = depth or 0
    maxDepth = maxDepth or 5
    out = out or {}
    if not node or depth > maxDepth then return out end
    for _, c in ipairs(node:GetChildren()) do
        table.insert(out, string.rep("  ", depth) .. c.ClassName .. " | " .. c.Name)
        walk(c, depth + 1, maxDepth, out)
    end
    return out
end

_G.PB = {
    RS = RS, LP = LP, HS = HS,
    net = function(d)
        local n = RS:FindFirstChild("Network")
        if not n then return "NO Network node" end
        return table.concat(walk(n, 0, d or 5), "\n")
    end,
    remotes = function(filter)
        local n = RS:FindFirstChild("Network")
        if not n then return "NO Network node" end
        local out = {}
        for _, r in ipairs(n:GetDescendants()) do
            local cl = r.ClassName
            if (cl == "RemoteEvent" or cl == "RemoteFunction" or cl == "UnreliableRemoteEvent") then
                if not filter or r:GetFullName():lower():find(tostring(filter):lower(), 1, true) then
                    table.insert(out, cl .. " | " .. r:GetFullName())
                end
            end
        end
        table.sort(out)
        return table.concat(out, "\n")
    end,
    feat = function()
        local fw = RS:FindFirstChild("Framework")
        if not fw then return "NO Framework" end
        local f = fw:FindFirstChild("Features") or fw
        local out = {}
        for _, c in ipairs(f:GetDescendants()) do
            if c:IsA("ModuleScript") then table.insert(out, c:GetFullName()) end
        end
        table.sort(out)
        return table.concat(out, "\n")
    end,
    datakeys = function()
        local fw = RS:FindFirstChild("Framework")
        if not fw then return "NO Framework" end
        local ok, dc = pcall(function()
            local n = fw:FindFirstChild("Features")
            return require(n:FindFirstChild("Data"):FindFirstChild("DataController"))
        end)
        if not ok or not dc then return "DataController require failed" end
        local d = dc.___X
        if not d then return "no ___X" end
        local out = {}
        for k, v in pairs(d) do
            table.insert(out, tostring(k) .. " = " .. type(v))
        end
        table.sort(out)
        return table.concat(out, "\n")
    end,
    run = function(code)
        local fn, err = loadstring(code)
        if not fn then return "COMPILE ERROR: " .. tostring(err) end
        local ok, res = pcall(fn)
        return (ok and "OK: " or "ERR: ") .. tostring(res)
    end,
}

-- command loop ------------------------------------------------------
local function poll()
    local url = BASE .. "/agent/poll?token=" .. TOKEN .. "&sid=" .. SID
    local body = httpCall(url, "GET")
    if not body then return nil end
    local ok, data = pcall(function() return HS:JSONDecode(body) end)
    if not ok or type(data) ~= "table" then return nil end
    return data.cmd
end

local function report(id, ok, out)
    out = tostring(out or "")
    if #out > 6000 then out = out:sub(1, 6000) .. "\n...[truncated]" end
    local payload = HS:JSONEncode({id = tostring(id), ok = ok, out = out})
    httpCall(BASE .. "/agent/result?token=" .. TOKEN .. "&sid=" .. SID, "POST", payload)
end

print("[PESONA BRIDGE] agent online — waiting for commands")

task.spawn(function()
    while not _G.__PB_OFF do
        local okp, cmd = pcall(poll)
        if okp and cmd and cmd.code then
            local fn, err = loadstring(tostring(cmd.code))
            if not fn then
                report(cmd.id, false, "COMPILE ERROR: " .. tostring(err))
            else
                local okr, res = pcall(fn)
                report(cmd.id, okr, res)
            end
        end
        task.wait(1.2)
    end
    _G.__PB_ALIVE = false
    print("[PESONA BRIDGE] agent stopped")
end)
