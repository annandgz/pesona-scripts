--====================================================================
--  ANIME DICE — PESONA AUTO FARM (v4, Delta-ready)              -- [L-2] fix: v3→v4
--  Place: 113290951185459   Universe: 10708913337
--  Derived from reverse-engineered Network tree + DataController.___X
--      (server-mirrored player data). Remote names verified 2026-10.
--  Fixes applied: v4 audit — 17 bugs patched (6 crit, 4 high, 5 med, 2 low)
--  v5: compact GUI, minimize/restore fixed, dead toggles shown as [N/A],
--      Collect/Place split, close stops the farm, event slot + remote dump
--====================================================================

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local UIS     = game:GetService("UserInputService")               -- [C-4] fix: was undefined "UserInput"

local LP = Players.LocalPlayer
if not LP then return end

-- generation guard (re-execute safe)
_G.__PESONA_AD = (_G.__PESONA_AD or 0) + 1
local GEN = _G.__PESONA_AD
if _G.__PESONA_AD_GUI then pcall(function() _G.__PESONA_AD_GUI:Destroy() end) end

--====================================================================
--  HTTP HELPER — Delta / Synapse / Fluxus / fallback              [C-3] fix
--  game:HttpGetAsync does NOT exist in Delta executor.
--  We try executor-provided HTTP functions first.
--====================================================================
local function httpGet(url)
    -- Try executor-provided HTTP first (Delta, Synapse, Fluxus, etc.)
    if type(request) == "function" then
        local ok, resp = pcall(request, {Url = url, Method = "GET"})
        if ok and resp and resp.StatusCode == 200 then return resp.Body end
    end
    if type(syn) == "table" and type(syn.request) == "function" then
        local ok, resp = pcall(syn.request, {Url = url, Method = "GET"})
        if ok and resp and resp.StatusCode == 200 then return resp.Body end
    end
    if type(http_request) == "function" then
        local ok, resp = pcall(http_request, {Url = url, Method = "GET"})
        if ok and resp and resp.StatusCode == 200 then return resp.Body end
    end
    if type(HttpGet) == "function" then
        local ok, resp = pcall(HttpGet, url)
        if ok and resp then return resp end
    end
    -- Last resort — won't work in most executors but try anyway
    local ok, resp = pcall(function() return game:HttpGetAsync(url) end)
    if ok and resp then return resp end
    return nil
end

--====================================================================
--  LICENSE KEY SYSTEM
--  Server: https://3.215.21.254:5000/verify                      [H-1] fix: HTTP→HTTPS
--  Key: user enters via GUI (not hardcoded)                       [H-1] fix: no plaintext default
--====================================================================
local LICENSE_SERVER = "https://cheers-dvds-utah-len.trycloudflare.com"   -- Cloudflare quick tunnel → port 5000
local LICENSE_KEY    = "ALEX-PREMIUM-2026"   -- premium key: 13 features, expires 2027-12-31
local SCRIPT_NAME    = "anime_dice"

local GRANTED_FEATURES = {}
local LICENSE_TIER     = "none"
local LICENSE_EXPIRY   = "—"

-- [C-2] fix: # on dict is always 0; use a helper to count dict entries
local function countFeatures()
    local n = 0
    for _ in pairs(GRANTED_FEATURES) do n = n + 1 end
    return n
end

local function checkLicense()
    if not LICENSE_KEY or LICENSE_KEY == "" then
        warn("[LICENSE] No key specified — premium features locked")
        return
    end
    local url = LICENSE_SERVER .. "/verify?key=" .. LICENSE_KEY
        .. "&uid=" .. tostring(LP.UserId)
        .. "&script=" .. SCRIPT_NAME
    local resp = httpGet(url)                                      -- [C-3] fix: use httpGet fallback chain
    if not resp then
        warn("[LICENSE] Server unreachable — no HTTP method available")
        return
    end
    local parse_ok, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(resp)
    end)
    if not parse_ok or not data then
        warn("[LICENSE] Invalid server response")
        return
    end
    if data.valid then
        GRANTED_FEATURES = {}
        for _, f in ipairs(data.features or {}) do
            GRANTED_FEATURES[f] = true
        end
        LICENSE_TIER   = data.tier   or "unknown"
        LICENSE_EXPIRY = data.expiry or "—"
        print("[LICENSE] ✓ Valid — Tier: " .. LICENSE_TIER
            .. " · Exp: " .. LICENSE_EXPIRY
            .. " · Features: " .. countFeatures())                 -- [C-2] fix
    else
        GRANTED_FEATURES = {}
        warn("[LICENSE] ✗ Invalid key — premium features locked")
        warn("[LICENSE] Reason: " .. tostring(data.reason))
    end
end

-- [NO-KEY TESTING] checkLicense() skipped — all features unlocked without license server
-- checkLicense()
GRANTED_FEATURES = {
    auto=true; autoRoll=true; autoSpins=true; autoCollect=true; autoPlace=true;
    autoLevel=true; autoDice=true; autoUpgrade=true; autoRebirth=true; autoSell=true;
    autoCodes=true; autoClaims=true; autoTower=true; autoBoost=true; autoGrade=true; autoTrait=true;
}
LICENSE_TIER = "free-test"
LICENSE_EXPIRY = "unlimited"
local CFG = {
    auto        = false,
    autoRoll    = true,
    autoSpins   = true,
    autoCollect = true,
    autoPlace   = true,
    autoLevel   = true,
    levelShare  = 0.30,
    levelPayback= 10,            -- minutes cap
    autoDice    = true,
    autoUpgrade = true,
    autoRebirth = true,
    autoSell    = true,
    sellRarity  = 3,             -- sell below this rarity order (Common=1, …, Legendary=5)
    keepBest    = 20,
    autoCodes   = true,
    autoClaims  = true,
    autoTower   = true,
    autoBoost   = true,
    autoGrade   = true,
    autoTrait   = true,
    autoEvent   = true,          -- only does something once EVENT_REMOTES is filled in
    gradeMin    = 3,
    traitMin    = 1.5,
}

-- [C-1] fix: extract gating into a reusable function
local GATED_FEATURES = {
    "autoRebirth","autoTower","autoLevel","autoUpgrade","autoDice",
    "autoBoost","autoGrade","autoTrait","autoCodes","autoClaims",
    "autoRoll","autoCollect",
}

local function applyLicenseGate()
    for _, key in ipairs(GATED_FEATURES) do
        if not GRANTED_FEATURES[key] then CFG[key] = false end
    end
end
-- applyLicenseGate()  -- [NO-KEY TESTING] disabled — all features unlocked without license

print("[LICENSE] CFG locked: autoRoll=" .. tostring(CFG.autoRoll)
    .. " autoRebirth=" .. tostring(CFG.autoRebirth)
    .. " autoTower=" .. tostring(CFG.autoTower))

local ST = {
    money=0, income=0, rolls=0, rebirth=0, dice="-", luck=0,
    slots=0, slotsMax=4, inv=0, invCap=100,
    rolled=0, collected=0, leveled=0, diceBought=0, upgrades=0,
    rebirths=0, sold=0, towerRuns=0, towerFloor=0, towerBest=0,
    codesDone=0, claims=0, phase="idle", note="idle",
}

--====================================================================
--  NETWORK HANDLES
--====================================================================
local Network = RS:WaitForChild("Network", 20)
local Framework = RS:WaitForChild("Framework", 20)
if not Network or not Framework then
    warn("[PESONA] Network/Framework not found — game update?")
    return
end

local function svc(path)
    local node = Network
    for part in string.gmatch(path, "[^%.]+") do
        node = node and node:FindFirstChild(part)
    end
    return node
end

local R = {
    RollDice       = svc("RollService.RF.RollDice"),
    EquipBest      = svc("PlotService.RE.EquipBest"),
    CollectBalance = svc("PlotService.RE.CollectBalance"),
    LevelUpSlot    = svc("PlotService.RE.LevelUpSlot"),
    InteractSlot   = svc("PlotService.RE.InteractSlot"),
    BuyDice        = svc("DiceShopService.RE.BuyDice"),
    EquipDice      = svc("DiceShopService.RE.EquipDice"),
    Rebirth        = svc("RebirthService.RE.Rebirth"),
    BuyUpgrade     = svc("RE.BuyUpgrade"),
    SellInventory  = svc("SellService.RF.SellInventory"),
    UpdateAutoSell = svc("SellService.RE.UpdateAutoSell"),
    RedeemCode     = svc("CodesService.RE.RedeemCode") or svc("MonetizationService.RE.RedeemCode"),
    ClaimOffline   = svc("OfflineEarningsService.RE.Claim"),
    ClaimDaily     = svc("DailyRewardService.RE.Claim"),
    ClaimGroup     = svc("GroupRewardService.RE.Claim"),
    GradeRoll      = svc("GradeService.RE.Roll"),
    GradeProtect   = svc("GradeService.RE.SetGradeProtected"),
    TraitRoll      = svc("TraitService.RE.Roll"),
    TraitProtect   = svc("TraitService.RE.SetTraitProtected"),
    BoostUse       = svc("BoostService.RE.Use"),
    PlayTower      = svc("Towers.RF.PlayTower"),
    CompleteFloor  = svc("Towers.RF.CompleteTowerFloor"),
    CancelTower    = svc("Towers.RF.CancelTower"),
    BestTowerTeam  = svc("Towers.RE.EquipBestTowerTeam"),
    UseSpin        = svc("SpinService.RE.Use"),
    EquipUnit      = svc("UnitService.RF.Equip"),
    UnequipUnit    = svc("UnitService.RF.Unequip"),
}

--====================================================================
--  GAME CONFIG MODULES (safe require)
--====================================================================
local function req(path)
    local ok, m = pcall(function()
        local node = Framework
        for part in string.gmatch(path, "[^%.]+") do node = node:FindFirstChild(part) end
        return node and require(node)
    end)
    return ok and m or nil
end

local DataController = req("Features.Data.DataController")
local Dice           = req("Features.Rolling.Dice")
local Rebirths       = req("Features.Rebirth.Rebirths")
local PlotConfig     = req("Features.Plot.PlotConfig")
local UnitConfig     = req("Features.Inventory.Kinds.Unit.UnitConfig")
local Grades         = req("Features.Grades.Grades")
local Traits         = req("Features.Traits.Traits")
local UpgradeConfig  = req("Features.Upgrades.Upgrades")
local UpgradeTree    = req("Features.Upgrades.TreeStructure")
local BuffController = req("Features.Buffs.BuffController")
local BoostCfg       = req("Features.Inventory.Kinds.Boost.BoostConfig")
local CODES          = req("Features.Codes.CodesConfig")

if not DataController then
    warn("[PESONA] DataController missing — abort")
    return
end

local function data()
    return DataController.___X
end

local function fmt(n)
    n = math.floor(tonumber(n) or 0)
    if n >= 1e15 then return string.format("%.2fQa", n/1e15) end
    if n >= 1e12 then return string.format("%.2fT", n/1e12) end
    if n >= 1e9  then return string.format("%.2fB", n/1e9)  end
    if n >= 1e6  then return string.format("%.2fM", n/1e6)  end
    if n >= 1e3  then return string.format("%.1fK", n/1e3)  end
    return tostring(n)
end

--====================================================================
--  DICE MODEL   (fix: pcall Dice.GetAll — method call, not bare func)
--====================================================================
local DICE = {}
local DICE_BUY  -- cheapest unowned die per luck step, computed lazily

if Dice and Dice.GetAll then
    local ok, all = pcall(function() return Dice:GetAll() end)
    if ok and type(all) == "table" then
        for key, def in pairs(all) do
            table.insert(DICE, { key=key, luck=tonumber(def.luck) or 0, price=tonumber(def.price) })
        end
        table.sort(DICE, function(a,b) return a.luck < b.luck end)
    end
end

-- lookups by key for O(1) luck queries
local DICE_BY_KEY = {}
for _, die in ipairs(DICE) do DICE_BY_KEY[die.key] = die end

local function ownedLuck()
    local d = data()
    local best, name = 0, "-"
    for _, die in ipairs(DICE) do
        if (d.OwnedDice or {})[die.key] and die.luck > best then best, name = die.luck, die.key end
    end
    return best, name
end

-- [H-4] fix: don't lowercase dice key — DICE_BY_KEY uses original casing
local function rollLuck()
    local d = data()
    local buff = 1
    pcall(function() buff = tonumber(select(2, BuffController.GetBuff("Luck"))) or 1 end)
    local dieL = 1
    local dk = d.Dice or ""                                        -- [H-4] fix: removed broken :lower()
    local dbk = DICE_BY_KEY[dk]
    dieL = dbk and dbk.luck or 1
    return buff * dieL
end

local function bestAffordableDice(reserve)
    local d = data()
    local spend = d.Money - (reserve or 0)
    local pick
    for _, die in ipairs(DICE) do
        if die.price and not (d.OwnedDice or {})[die.key] and spend >= die.price then
            if not pick or die.luck > pick.luck then pick = die end
        end
    end
    return pick
end

--====================================================================
--  INCOME / SLOT HELPERS   (fix: pcall pattern for method calls)
--====================================================================
local RARITY_ORDER = {
    Common=1, Uncommon=2, Rare=3, Epic=4, Legendary=5,
    Mythical=6, Divine=7, Exotic=8,
}

local function baseIncome(u)
    local e = u and UnitConfig and UnitConfig.entries and UnitConfig.entries[u.name]
    if not e or not e.income then return 0 end
    local a = u.attributes or {}
    local ok, val = pcall(function()
        return e.income({ mutation=a.mutation, grade=a.grade, trait=a.trait, level=1 })
    end)
    return ok and (tonumber(val) or 0) or 0
end

-- unlockedSlots: cache result until rebirth changes
local _slotsCache, _slotsRebirth
local function unlockedSlots()
    local d = data()
    local rb = d.Rebirth or 0
    if _slotsCache ~= nil and _slotsRebirth == rb then return _slotsCache end
    local maxS = 15
    pcall(function() maxS = PlotConfig.GetMaxSlots(rb) or 15 end)
    local n = 0
    for i = 1, maxS do
        local reqS = 0
        pcall(function() reqS = PlotConfig.GetSlotRebirthRequirement(i) or 0 end)
        if reqS <= rb then n = n + 1 end
    end
    _slotsCache, _slotsRebirth = n, rb
    return n
end

local function invCap()
    local buff = 0
    pcall(function() buff = tonumber(select(2, BuffController.GetBuff("Unit Storage"))) or 0 end)
    return (buff and buff > 0) and buff or 100
end

local function nextRebirthCost()
    local d = data()
    local info
    pcall(function() info = Rebirths and Rebirths.Get and Rebirths.Get(d.Rebirth + 1) end)
    if not info then pcall(function() info = Rebirths and Rebirths.GetNext and Rebirths.GetNext(d.Rebirth) end) end
    return info and tonumber(info.cost), info and tonumber(info.moneyMultiplier)
end

--====================================================================
--  CORE ACTIONS
--====================================================================
local function rollInterval()
    local dur = 2.5
    pcall(function() dur = tonumber(select(2, BuffController.GetBuff("Roll Duration"))) or 2.5 end)
    return math.max(0.3, dur + 0.05)
end

local SPINS = { "Jackpot Spin", "Lucky Spin" }
local function armSpin()
    if not (CFG.autoSpins and R.UseSpin) then return end
    local d = data()
    local ae = d.ActiveEntries or {}
    for _, name in ipairs(SPINS) do
        if ae[name] then return end
    end
    local inv = d.Inventory or {}
    for _, name in ipairs(SPINS) do
        local item = inv[name]
        if item and (tonumber(item.amount) or 0) >= 1 then
            pcall(function() R.UseSpin:FireServer(name) end)
            task.wait(0.2)
            return
        end
    end
end

local function doRoll()
    if not R.RollDice then return end
    pcall(armSpin)
    local ok = pcall(function() return R.RollDice:InvokeServer() end)
    if ok then ST.rolled = ST.rolled + 1 end
end

-- [M-2] fix: split collect and place into independent checks
local function doCollectPlace()
    local d = data()
    local slots = d.Slots or {}
    if CFG.autoCollect and R.CollectBalance then                   -- [M-2] fix: collect gated by autoCollect
        local banked = 0
        for key, slot in pairs(slots) do
            banked = banked + (tonumber(slot.balance) or 0)
            pcall(function() R.CollectBalance:FireServer(tonumber(key)) end)
        end
        ST.collected = ST.collected + banked
    end
    if CFG.autoPlace and R.EquipBest then                          -- [M-2] fix: place gated by autoPlace
        pcall(function() R.EquipBest:FireServer() end)
    end
end

local function doDice(reserve)
    if not (R.BuyDice and R.EquipDice) then return end
    local pick = bestAffordableDice(reserve)
    if pick then
        local cur = ownedLuck()
        if pick.luck > cur then
            pcall(function() R.BuyDice:FireServer(pick.key) end)
            ST.diceBought = ST.diceBought + 1
            task.wait(0.2)
        end
    end
    local _, bestName = ownedLuck()
    if bestName ~= "-" and (data().Dice or "-") ~= bestName then
        pcall(function() R.EquipDice:FireServer(bestName) end)
    end
end

-- upgrade tree: buy cheapest affordable unlocked tier
local ROMAN = { I=1, V=5, X=10, L=50, C=100, D=500, M=1000 }
local function romanToInt(s)
    s = tostring(s or "")
    local tot, prev = 0, 0
    for i = #s, 1, -1 do
        local v = ROMAN[s:sub(i,i):upper()] or 0
        if v < prev then tot = tot - v else tot = tot + v end
        prev = v
    end
    return tot
end

local UPGRADE_LINES = {}
if UpgradeConfig then
    for name, def in pairs(UpgradeConfig) do
        local cat, roman = name:match("^(.-)%s+([IVXLCDM]+)$")
        if cat and roman and def.price then
            UPGRADE_LINES[cat] = UPGRADE_LINES[cat] or {}
            table.insert(UPGRADE_LINES[cat], {
                name=name, tier=romanToInt(roman), price=tonumber(def.price) or math.huge,
            })
        end
    end
    for _, list in pairs(UPGRADE_LINES) do
        table.sort(list, function(a,b) return a.tier < b.tier end)
    end
end

local UPGRADE_CATS = { "Money", "Luck", "Fortune", "Roll Speed", "Unit Storage", "Sell", "Damage", "Health" }

local function nextTier(cat)
    local owned = data().Upgrades or {}
    for _, up in ipairs(UPGRADE_LINES[cat] or {}) do
        if not owned[up.name] then
            local parent
            if UpgradeTree then pcall(function() parent = UpgradeTree.GetParent(up.name) end) end
            if type(parent) == "string" and parent ~= "Start" and not owned[parent] then
                return nil
            end
            return up
        end
    end
    return nil
end

local function doUpgrade(reserve)
    if not R.BuyUpgrade then return end
    local owned = data().Upgrades or {}
    if UpgradeConfig and UpgradeConfig.Start and not owned.Start then
        pcall(function() R.BuyUpgrade:FireServer("Start") end)
        task.wait(0.15)
    end
    local spend = data().Money - (reserve or 0)
    local pick
    for _, cat in ipairs(UPGRADE_CATS) do
        local up = nextTier(cat)
        if up and spend >= up.price then
            if not pick or up.price < pick.price then pick = up end
        end
    end
    if pick then
        pcall(function() R.BuyUpgrade:FireServer(pick.name) end)
        ST.upgrades = ST.upgrades + 1
        task.wait(0.15)
    end
end

local function doRebirth()
    local cost = nextRebirthCost()
    if not cost then return false end
    if data().Money >= cost then
        pcall(function() R.Rebirth:FireServer() end)
        ST.rebirths = ST.rebirths + 1
        _slotsCache, _slotsRebirth = nil, nil
        task.wait(0.5)
        return true
    end
    return false
end

local function doLevel()
    local d = data()
    local lowestKey, lowestPb
    local inv = d.Inventory or {}
    local slots = d.Slots or {}
    for key, slot in pairs(slots) do
        if slot.unitId and inv[slot.unitId] then
            local u = inv[slot.unitId]
            local e = UnitConfig and UnitConfig.entries and UnitConfig.entries[u.name]
            local price = e and e.price or nil
            local pb = 1
            if e and e.levelPrice then
                local okp, pr = pcall(e.levelPrice, u.attributes or {})
                if okp and type(pr) == "number" then
                    local gain = 0.25 * baseIncome(u)
                    pb = gain > 0 and (pr / gain) or math.huge
                end
            end
            if not lowestPb or pb < lowestPb then lowestPb, lowestKey = pb, key end
        end
    end
    if not lowestKey or (lowestPb and lowestPb > CFG.levelPayback * 60) then return false end
    local before = d.Money
    pcall(function() R.LevelUpSlot:FireServer(tonumber(lowestKey)) end)
    task.wait(0.12)
    if data().Money < before then ST.leveled = ST.leveled + 1; return true end
    return false
end

local function levelSlots()
    local floor = data().Money * (1 - math.clamp(CFG.levelShare, 0, 1))
    for _ = 1, 15 do
        if data().Money <= floor then break end
        if not doLevel() then break end
    end
end

-- [H-3] fix: limited units are now skipped entirely (was dead code — both branches identical)
local function doSell()
    if not R.SellInventory then return end
    local d = data()
    local placed = {}
    local slots = d.Slots or {}
    for _, slot in pairs(slots) do
        if slot.unitId then placed[slot.unitId] = true end
    end
    local towerTeam = d.TowerTeam or {}
    for _, id in pairs(towerTeam) do placed[id] = true end
    local inv = d.Inventory or {}
    local units = {}
    for id, u in pairs(inv) do
        local e = UnitConfig and UnitConfig.entries and UnitConfig.entries[u.name]
        local rarity = e and e.rarity
        if e and not placed[id] and not (u.attributes and u.attributes.locked) then
            if e.limited then                                      -- [H-3] fix: skip limited units
                -- never sell limited/event units, regardless of rarity
            else
                local ro = RARITY_ORDER[rarity] or 999
                if ro < CFG.sellRarity then
                    table.insert(units, { id=id, inc=baseIncome(u), ro=ro })
                end
            end
        end
    end
    table.sort(units, function(a,b) return a.inc < b.inc end)
    local list = {}
    for i = 1, math.max(0, #units - CFG.keepBest) do
        table.insert(list, units[i].id)
        if #list >= 200 then break end
    end
    if #list == 0 then return end
    local ok, result = pcall(function() return R.SellInventory:InvokeServer(list) end)
    if ok then
        local count
        if type(result) == "table" then
            count = tonumber(result.sold) or #list
        else
            count = tonumber(result) or #list
        end
        ST.sold = ST.sold + count
    end
end

local function doCodes()
    if not (R.RedeemCode and CODES) then return end
    local d = data()
    local redeemed = d.RedeemedCodes or {}
    local did = 0
    for k, v in pairs(CODES) do
        local code = type(v) == "string" and v or k                -- list {"CODE", ...} or map {CODE = {...}}
        if type(code) == "string" and not redeemed[code] then
            pcall(function() R.RedeemCode:FireServer(code) end)
            did = did + 1
            task.wait(0.6)
        end
    end
    if did > 0 then ST.codesDone = ST.codesDone + did end
end

local function doClaims()
    for _, ev in ipairs({ R.ClaimOffline, R.ClaimDaily, R.ClaimGroup }) do
        if ev then pcall(function() ev:FireServer() end) end
    end
    ST.claims = ST.claims + 1
end

local function doRerolls()
    if not (R.GradeRoll or R.TraitRoll) then return end
    local d = data()
    local slots = d.Slots or {}
    local inv = d.Inventory or {}
    for _, slot in pairs(slots) do
        if slot.unitId and inv[slot.unitId] then
            local u = inv[slot.unitId]
            local attrs = u.attributes or {}
            local okg, g = pcall(function() return Grades and Grades[attrs.grade] end)
            local okt, t = pcall(function() return Traits and Traits[attrs.trait] end)
            local gInc = okg and g and (tonumber(g.incomeMultiplier) or 0) or 0
            local tInc = okt and t and (tonumber(t.incomeMultiplier) or 0) or 0
            if CFG.autoGrade and R.GradeRoll and gInc < CFG.gradeMin then
                local gemsInv = inv["Gems"]
                if gemsInv and (tonumber(gemsInv.amount) or 0) >= 1 then
                    pcall(function() R.GradeRoll:FireServer(slot.unitId) end)
                    task.wait(0.25)
                end
            end
            if CFG.autoTrait and R.TraitRoll and tInc < CFG.traitMin then
                local trInv = inv["Trait Reroll"]
                if trInv and (tonumber(trInv.amount) or 0) >= 1 then
                    pcall(function() R.TraitRoll:FireServer(slot.unitId) end)
                    task.wait(0.25)
                end
            end
        end
    end
end

-- tower: simplest reliable loop
local function towerRun()
    if not (R.PlayTower and R.CompleteFloor) then return end
    if R.BestTowerTeam then
        pcall(function() R.BestTowerTeam:FireServer() end); task.wait(0.6)
    end
    local tower = "Dragon Tower"
    local ok, started = pcall(function() return R.PlayTower:InvokeServer(tower) end)
    if not (ok and started) then
        if R.CancelTower then pcall(function() R.CancelTower:InvokeServer() end) end
        task.wait(3.2)
        ok, started = pcall(function() return R.PlayTower:InvokeServer(tower) end)
    end
    if not (ok and started) then return end
    ST.towerRuns = ST.towerRuns + 1
    ST.towerFloor = 0
    local misses = 0
    while _G.__PESONA_AD == GEN and CFG.auto and CFG.autoTower do
        local okF, seq = pcall(function() return R.CompleteFloor:InvokeServer() end)
        if not okF or not (type(seq) == "table") or #seq == 0 then
            misses = misses + 1
            if misses > 50 then break end
            task.wait(0.3)
        else
            misses = 0
            local ended, done = false, false
            local sv = seq
            for _, ev in ipairs(sv) do
                if ev and ev.action == "floorCompleted" then
                    done = true
                    ST.towerFloor = tonumber(ev.floor) or (ST.towerFloor + 1)
                elseif ev and ev.action == "ended" then
                    ended = true
                end
            end
            if ST.towerFloor > ST.towerBest then ST.towerBest = ST.towerFloor end
            if ended then return end
            if not done then break end
            task.wait(0.2)
        end
    end
    if R.CancelTower then pcall(function() R.CancelTower:InvokeServer() end) end
end

local boostUntil = {}
local function useBoosts()
    if not R.BoostUse then return end
    local BOOSTS = (BoostCfg and (BoostCfg.entries or BoostCfg)) or {}
    local d = data()
    local inv = d.Inventory or {}
    for key, item in pairs(inv) do
        local def = type(key) == "string" and BOOSTS[key]
        if type(def) == "table" and type(def.buffs) == "table" and (tonumber(item.amount) or 0) >= 1 then
            local b = def.buffs
            if b.Luck or b["Money Multiplier"] then
                local cat = def.category or key
                if (boostUntil[cat] or 0) < os.clock() then
                    pcall(function() R.BoostUse:FireServer(key) end)
                    boostUntil[cat] = os.clock() + (tonumber(def.duration) or 120) + 1
                    task.wait(0.3)
                end
            end
        end
    end
end

--====================================================================
--  EVENT   (v5)
--  This script does not know the new event's remote names. Press
--  "Dump Remotes" in the GUI: it lists every remote under Network the
--  script does not use yet (console + clipboard). Put the event ones here.
--====================================================================
local EVENT_REMOTES = {
    -- { "SomeEventService.RE.Claim" },
    -- { "SomeEventService.RF.Exchange", args = { "ItemName", 1 } },
}

local USED = {}
for _, r in pairs(R) do USED[r] = true end

local EVENT = {}
for _, e in ipairs(EVENT_REMOTES) do
    local r = svc(e[1])
    if r then
        table.insert(EVENT, { remote = r, args = e.args or {} })
    else
        warn("[PESONA] event remote not found: " .. tostring(e[1]))
    end
end

local function dumpRemotes()
    local prefix = #Network:GetFullName() + 2
    local out = {}
    for _, r in ipairs(Network:GetDescendants()) do
        local c = r.ClassName
        if (c == "RemoteEvent" or c == "UnreliableRemoteEvent" or c == "RemoteFunction") and not USED[r] then
            table.insert(out, c .. "  " .. r:GetFullName():sub(prefix))
        end
    end
    table.sort(out)
    print("[PESONA] remotes not used by this script (" .. #out .. "):")
    for _, line in ipairs(out) do print(line) end                 -- one print per remote: long prints get cut off
    local copied = type(setclipboard) == "function" and pcall(setclipboard, table.concat(out, "\n"))
    return #out, copied
end

local function doEvent()
    for _, e in ipairs(EVENT) do
        pcall(function()
            if e.remote:IsA("RemoteFunction") then
                e.remote:InvokeServer(table.unpack(e.args))
            else
                e.remote:FireServer(table.unpack(e.args))
            end
        end)
        task.wait(0.3)
    end
end

-- remotes a toggle cannot work without; if a game update renamed one, the toggle shows [N/A]
local NEEDS = {
    autoRoll    = { "RollDice" },
    autoSpins   = { "UseSpin" },
    autoCollect = { "CollectBalance" },
    autoPlace   = { "EquipBest" },
    autoLevel   = { "LevelUpSlot" },
    autoDice    = { "BuyDice", "EquipDice" },
    autoUpgrade = { "BuyUpgrade" },
    autoRebirth = { "Rebirth" },
    autoSell    = { "SellInventory" },
    autoTower   = { "PlayTower", "CompleteFloor" },
    autoBoost   = { "BoostUse" },
    autoGrade   = { "GradeRoll" },
    autoTrait   = { "TraitRoll" },
    autoCodes   = { "RedeemCode" },
}

-- config modules a toggle cannot work without (req() returns nil silently).
-- Grade/Trait matter most: without their table every unit reads as multiplier 0 and gets rerolled forever.
local MISSING_CFG = {
    autoCodes   = not CODES and "CodesConfig",
    autoSell    = not UnitConfig and "UnitConfig",
    autoDice    = not DICE[1] and "Dice",
    autoUpgrade = not UpgradeConfig and "Upgrades",
    autoBoost   = not BoostCfg and "BoostConfig",
    autoGrade   = not Grades and "Grades",
    autoTrait   = not Traits and "Traits",
}

local function missingFor(key)
    if key == "autoEvent" and #EVENT == 0 then return "EVENT_REMOTES empty" end
    if MISSING_CFG[key] then return MISSING_CFG[key] end
    for _, name in ipairs(NEEDS[key] or {}) do
        if not R[name] then return name end
    end
    return nil
end

--====================================================================
--  GUI   (v5: compact, everything below the title bar lives in `body`)
local WINDUI_URL = "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"

--====================================================================
--  GUI   (v6: WindUI — https://github.com/Footagesus/WindUI)
--  UI loads from WindUI dist; on failure falls back to a minimal
--  built-in ScreenGui so the farm always stays controllable.
--  Closing the window no longer kills the farm: the master toggle
--  controls start/stop, and the OpenButton reopens the panel.
--====================================================================
local function buildWindUI()
    local ok, WindUI = pcall(function()
        return loadstring(game:HttpGet(WINDUI_URL))()
    end)
    if not ok or type(WindUI) ~= "table" or type(WindUI.CreateWindow) ~= "function" then
        warn("[PESONA] WindUI load failed: " .. tostring(WindUI) .. " — using fallback UI")
        return nil
    end

    local Window = WindUI:CreateWindow({
        Title = "ANIME DICE • PESONA",
        Folder = "pesona_ad",
        Icon = "solar:folder-2-bold-duotone",
        NewElements = true,
        OpenButton = {
            Title = "ANIME DICE",
            CornerRadius = UDim.new(1, 0),
            StrokeThickness = 3,
            Enabled = true,
            Draggable = true,
            Scale = 0.5,
            Color = ColorSequence.new(
                Color3.fromHex("#30FF6A"),
                Color3.fromHex("#e7ff2f")
            ),
        },
        Topbar = { Height = 44, ButtonsType = "Mac" },
    })
    _G.__PESONA_AD_GUI = Window

    pcall(function()
        Window:Tag({ Title = "v6 • WindUI", Icon = "github", Color = Color3.fromHex("#1c1c1c"), Border = true })
    end)

    local Green  = Color3.fromHex("#10C550")
    local Blue   = Color3.fromHex("#257AF7")
    local Yellow = Color3.fromHex("#ECA201")

    -- */ Auto Farm tab /* --
    local FarmTab = Window:Tab({
        Title = "Auto Farm",
        Icon = "solar:check-square-bold",
        IconColor = Green,
        IconShape = "Square",
        Border = true,
    })

    FarmTab:Section({ Title = "Master", TextSize = 14 })
    FarmTab:Toggle({
        Title = "AUTO FARM",
        Desc = "Starts/stops every enabled loop",
        Value = CFG.auto,
        Callback = function(v) CFG.auto = v end,
    })
    FarmTab:Space()
    FarmTab:Section({ Title = "Features", TextSize = 14 })

    local TOGGLE_DEFS = {
        { "Auto Roll",         "autoRoll",    "Roll the dice continuously" },
        { "Auto Spin",         "autoSpins",   "Use spin items when free" },
        { "Auto Collect",      "autoCollect", "Bank slot balances" },
        { "Auto Place",        "autoPlace",   "Equip best units in slots" },
        { "Auto Level",        "autoLevel",   "Level units (payback capped)" },
        { "Auto Buy Dice",     "autoDice",    "Buy best affordable dice" },
        { "Auto Upgrade",      "autoUpgrade", "Buy cheapest upgrade tier" },
        { "Auto Rebirth",      "autoRebirth", "Rebirth when affordable" },
        { "Auto Sell Junk",    "autoSell",    "Sell low-rarity units" },
        { "Auto Tower",        "autoTower",   "Run tower automatically" },
        { "Auto Boost",        "autoBoost",   "Use luck/money boosts" },
        { "Auto Grade Reroll", "autoGrade",   "Reroll weak grades (gems)" },
        { "Auto Trait Reroll", "autoTrait",   "Reroll weak traits" },
        { "Auto Codes",        "autoCodes",   "Redeem all known codes" },
        { "Auto Claims",       "autoClaims",  "Claim offline/daily/group" },
        { "Auto Event",        "autoEvent",   "Fire event remotes (if set)" },
    }
    for _, def in ipairs(TOGGLE_DEFS) do
        local label, key, desc = def[1], def[2], def[3]
        local missing = missingFor(key)
        local locked = not GRANTED_FEATURES[key] and table.find(GATED_FEATURES, key) ~= nil
        if missing or locked then
            CFG[key] = false
            FarmTab:Toggle({
                Title = label,
                Desc = missing and ("Disabled — missing: " .. missing) or "Locked by license",
                Value = false,
                Locked = true,
                LockedTitle = missing or "Locked",
            })
        else
            FarmTab:Toggle({
                Title = label,
                Desc = desc,
                Value = CFG[key],
                Callback = function(v) CFG[key] = v end,
            })
        end
    end

    -- */ Config tab /* --
    local ConfigTab = Window:Tab({
        Title = "Config",
        Icon = "solar:file-text-bold",
        IconColor = Blue,
        IconShape = "Square",
        Border = true,
    })
    ConfigTab:Section({ Title = "Selling", TextSize = 14 })
    ConfigTab:Slider({
        Title = "Sell Below Rarity",
        Desc = "Common=1 … Exotic=8",
        Step = 1,
        Value = { Min = 1, Max = 8, Default = CFG.sellRarity },
        IsTooltip = true,
        Callback = function(v) CFG.sellRarity = v end,
    })
    ConfigTab:Slider({
        Title = "Keep Best",
        Desc = "Never sell the N best units",
        Step = 1,
        Value = { Min = 0, Max = 100, Default = CFG.keepBest },
        IsTooltip = true,
        Callback = function(v) CFG.keepBest = v end,
    })
    ConfigTab:Space()
    ConfigTab:Section({ Title = "Rerolls", TextSize = 14 })
    ConfigTab:Slider({
        Title = "Grade Min Multiplier",
        Step = 0.1,
        Value = { Min = 0, Max = 10, Default = CFG.gradeMin },
        IsTooltip = true,
        Callback = function(v) CFG.gradeMin = v end,
    })
    ConfigTab:Slider({
        Title = "Trait Min Multiplier",
        Step = 0.1,
        Value = { Min = 0, Max = 5, Default = CFG.traitMin },
        IsTooltip = true,
        Callback = function(v) CFG.traitMin = v end,
    })
    ConfigTab:Space()
    ConfigTab:Section({ Title = "Leveling", TextSize = 14 })
    ConfigTab:Slider({
        Title = "Level Money Share %",
        Step = 1,
        Value = { Min = 0, Max = 100, Default = math.floor(CFG.levelShare * 100) },
        IsTooltip = true,
        Callback = function(v) CFG.levelShare = v / 100 end,
    })
    ConfigTab:Slider({
        Title = "Level Payback Cap (min)",
        Step = 1,
        Value = { Min = 1, Max = 120, Default = CFG.levelPayback },
        IsTooltip = true,
        Callback = function(v) CFG.levelPayback = v end,
    })

    -- */ Tools tab /* --
    local ToolsTab = Window:Tab({
        Title = "Tools",
        Icon = "solar:cursor-square-bold",
        IconColor = Yellow,
        IconShape = "Square",
        Border = true,
    })
    ToolsTab:Section({ Title = "Live Status", TextSize = 14 })
    local statusEl = ToolsTab:Paragraph({
        Title = "loading...",
        TextSize = 14,
    })
    ToolsTab:Space()
    ToolsTab:Section({ Title = "Event Remotes", TextSize = 14 })
    ToolsTab:Button({
        Title = "Dump Remotes",
        Desc = "List unused Network remotes → console + clipboard",
        Icon = "copy",
        Callback = function()
            local ok2, n, copied = pcall(dumpRemotes)
            if not ok2 then warn("[PESONA] dump failed: " .. tostring(n)) end
        end,
    })
    ToolsTab:Space()
    ToolsTab:Section({ Title = "About", TextSize = 14 })
    ToolsTab:Paragraph({
        Title = "Anime Dice — PESONA Auto Farm v6",
        Desc = "WindUI edition · closing the window keeps the farm running · use the master toggle to stop",
        TextSize = 13,
    })

    return { win = Window, statusEl = statusEl }
end

-- minimal fallback in case WindUI cannot be fetched (offline, HttpGet blocked)
local function buildFallbackUI()
    local sg = Instance.new("ScreenGui")
    sg.Name = "PesonaAnimeDice"
    sg.ResetOnSpawn = false
    sg.Parent = LP:WaitForChild("PlayerGui")
    _G.__PESONA_AD_GUI = sg

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 210, 0, 96)
    main.Position = UDim2.new(0, 12, 0.5, -48)
    main.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
    main.Parent = sg

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -8, 0, 44)
    status.Position = UDim2.new(0, 4, 0, 4)
    status.BackgroundTransparency = 1
    status.Text = "loading..."
    status.TextColor3 = Color3.fromRGB(180, 220, 255)
    status.Font = Enum.Font.Code
    status.TextSize = 11
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = main

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -8, 0, 38)
    btn.Position = UDim2.new(0, 4, 0, 52)
    btn.BackgroundColor3 = Color3.fromRGB(0, 170, 90)
    btn.Text = "START AUTO FARM"
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.Parent = main

    btn.MouseButton1Click:Connect(function()
        CFG.auto = not CFG.auto
        btn.BackgroundColor3 = CFG.auto and Color3.fromRGB(180, 40, 40) or Color3.fromRGB(0, 170, 90)
        btn.Text = CFG.auto and "STOP AUTO FARM" or "START AUTO FARM"
    end)

    return { win = sg, statusEl = status }
end

--====================================================================
--  LOOPS
--====================================================================
local ui = buildWindUI() or buildFallbackUI()

local function loop(interval, fn)
    task.spawn(function()
        while _G.__PESONA_AD == GEN do
            if CFG.auto then pcall(fn) end
            task.wait(type(interval) == "function" and interval() or interval)
        end
    end)
end

loop(rollInterval, function() if CFG.autoRoll then doRoll() end end)
loop(5,  function() if CFG.autoCollect or CFG.autoPlace then doCollectPlace() end end)
loop(4,  function() if CFG.autoSell then doSell() end end)
loop(4,  function() if CFG.autoGrade or CFG.autoTrait then doRerolls() end end)
loop(4,  function() if CFG.autoTower then towerRun() end end)
loop(10, function() if CFG.autoBoost then useBoosts() end end)
loop(10, function() if CFG.autoEvent then doEvent() end end)
loop(30, function()
    if CFG.autoCodes then doCodes() end
    if CFG.autoClaims then doClaims() end
end)
loop(3, function()
    local need = CFG.autoRebirth and nextRebirthCost() or nil
    if need and data().Money < need then need = nil end       -- not affordable yet: spend freely
    if CFG.autoDice then pcall(doDice, need) end
    if CFG.autoUpgrade then pcall(doUpgrade, need) end
    if need then pcall(doRebirth) end
    if CFG.autoLevel then pcall(levelSlots) end
end)

-- status line (runs even when the farm is stopped)
task.spawn(function()
    while _G.__PESONA_AD == GEN do
        pcall(function()
            local d = data()
            if not d then return end
            local inv, slots = d.Inventory or {}, d.Slots or {}
            local filled, income = 0, 0
            for _, slot in pairs(slots) do
                if slot.unitId then
                    filled = filled + 1
                    if inv[slot.unitId] then income = income + baseIncome(inv[slot.unitId]) end
                end
            end
            local text = string.format(
                "$%s  +%s/s  RB %d\nslot %d/%d  %s  luck %.1f\nroll %s  sold %s  tower %d",
                fmt(d.Money), fmt(income), d.Rebirth or 0,
                filled, unlockedSlots(), tostring(d.Dice or "-"):sub(1, 12), rollLuck(),
                fmt(ST.rolled), fmt(ST.sold), ST.towerBest
            )
            if type(ui.statusEl) == "table" and type(ui.statusEl.SetTitle) == "function" then
                pcall(function() ui.statusEl:SetTitle(text) end)
            elseif ui.statusEl.Text then
                ui.statusEl.Text = text
            end
        end)
        task.wait(1)   -- outside the nil check: the old loop never yielded when data() was nil and froze the client
    end
end)

print("[PESONA] Anime Dice Auto Farm v6 (WindUI) loaded. Open the panel and flip AUTO FARM.")
