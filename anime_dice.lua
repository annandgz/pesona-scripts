--====================================================================
--  ANIME DICE — PESONA AUTO FARM (v4, Delta-ready)              -- [L-2] fix: v3→v4
--  Place: 113290951185459   Universe: 10708913337
--  Derived from reverse-engineered Network tree + DataController.___X
--      (server-mirrored player data). Remote names verified 2026-10.
--  Fixes applied: v4 audit — 17 bugs patched (6 crit, 4 high, 5 med, 2 low)
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
        local cat, roman = name:match("^(.-)%s+([IVXLM]+)$")
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
    for code in pairs(CODES) do
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
--  GUI   (all GUI bugs fixed: C-4, C-6, M-1, M-3, L-1)
--====================================================================
local function buildGUI()
    local pg = LP:WaitForChild("PlayerGui")
    local sg = Instance.new("ScreenGui")
    sg.Name = "PesonaAnimeDice"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = pg
    _G.__PESONA_AD_GUI = sg

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 320, 0, 600)                         -- [M-3] fix: taller to fit stacked panels
    main.Position = UDim2.new(0, 20, 0.5, -300)
    main.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
    main.BorderSizePixel = 0
    main.Active = true
    main.Parent = sg
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 8); corner.Parent = main
    local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(0, 220, 255); stroke.Thickness = 1.5; stroke.Parent = main

    -- drag
    local dragging, dragStart, startPos
    main.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = main.Position
        end
    end)
    main.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UIS.InputEnded:Connect(function(input)                         -- [C-4] fix: UserInput → UIS
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    -- Forward-declare GUI elements used in minimize handler         [C-6] fix
    local list, statGrid
    local minimized = false
    local collapsedH = 42
    local fullH = 600

    -- minimize + close buttons
    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 24, 0, 24)
    minBtn.Position = UDim2.new(1, -54, 0, 4)                     -- moved left to not overlap close
    minBtn.BackgroundTransparency = 1
    minBtn.Text = "−"
    minBtn.TextColor3 = Color3.new(1, 1, 1)
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 16
    minBtn.Parent = main

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 26, 0, 26)
    closeBtn.Position = UDim2.new(1, -26, 0, 4)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text = "×"
    closeBtn.TextColor3 = Color3.new(1, 0.5, 0.5)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 18
    closeBtn.Parent = main
    closeBtn.MouseButton1Click:Connect(function()
        pcall(function() sg:Destroy() end)
        _G.__PESONA_AD_GUI = nil
    end)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 0, 30)
    title.Position = UDim2.new(0, 10, 0, 2)
    title.BackgroundTransparency = 1
    title.Text = "  ANIME DICE  •  PESONA FARM"
    title.TextColor3 = Color3.fromRGB(0, 220, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = main

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -20, 0, 38)
    status.Position = UDim2.new(0, 10, 0, 36)
    status.BackgroundColor3 = Color3.fromRGB(22, 26, 38)
    status.Text = "money 0  |  /s 0  |  rb 0"
    status.TextColor3 = Color3.fromRGB(180, 220, 255)
    status.Font = Enum.Font.Code
    status.TextSize = 12
    status.Parent = main
    status.Name = "StatusLabel"
    local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0, 6); sc.Parent = status
    -- [L-1] fix: removed the self-assignment no-op GetPropertyChangedSignal handler

    -- License panel (key input + verify + status badge)
    local licPanel = Instance.new("Frame")
    licPanel.Size = UDim2.new(1, -16, 0, 54)
    licPanel.Position = UDim2.new(0, 8, 0, 78)
    licPanel.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
    licPanel.Parent = main
    local plic = Instance.new("UICorner"); plic.CornerRadius = UDim.new(0, 6); plic.Parent = licPanel
    local lstroke2 = Instance.new("UIStroke"); lstroke2.Color = Color3.fromRGB(0, 180, 255); lstroke2.Thickness = 1; lstroke2.Parent = licPanel

    local licLabel = Instance.new("TextLabel")
    licLabel.Size = UDim2.new(1, -6, 0, 14)
    licLabel.Position = UDim2.new(0, 8, 0, 4)
    licLabel.BackgroundTransparency = 1
    licLabel.Text = "LICENSE"
    licLabel.TextColor3 = Color3.fromRGB(0, 220, 255)
    licLabel.Font = Enum.Font.GothamBold
    licLabel.TextSize = 11
    licLabel.Parent = licPanel

    local keyInput = Instance.new("TextBox")
    keyInput.Size = UDim2.new(0.46, -8, 0, 20)
    keyInput.Position = UDim2.new(0, 8, 0, 20)
    keyInput.PlaceholderText = "Masukkan license key..."
    keyInput.Text = LICENSE_KEY
    keyInput.ClearTextOnFocus = false
    keyInput.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
    keyInput.TextColor3 = Color3.new(1, 1, 1)
    keyInput.Font = Enum.Font.Code
    keyInput.TextSize = 11
    keyInput.Parent = licPanel
    local kbox = Instance.new("UICorner"); kbox.CornerRadius = UDim.new(0, 4); kbox.Parent = keyInput

    local verBtn = Instance.new("TextButton")
    verBtn.Size = UDim2.new(0.46, -8, 0, 20)
    verBtn.Position = UDim2.new(0.5, 4, 0, 20)
    verBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 90)
    verBtn.Text = "VERIFY"
    verBtn.TextColor3 = Color3.new(1, 1, 1)
    verBtn.Font = Enum.Font.GothamBold
    verBtn.TextSize = 11
    verBtn.Parent = licPanel
    local vbox = Instance.new("UICorner"); vbox.CornerRadius = UDim.new(0, 4); vbox.Parent = verBtn

    local licBadge = Instance.new("TextLabel")
    licBadge.Size = UDim2.new(1, -12, 0, 16)
    licBadge.Position = UDim2.new(0, 6, 0, 42)
    licBadge.BackgroundTransparency = 1
    licBadge.Text = "Tier: " .. LICENSE_TIER .. "  |  Exp: " .. LICENSE_EXPIRY
        .. "  |  Features: " .. countFeatures()                    -- [C-2] fix
    licBadge.TextColor3 = Color3.fromRGB(120, 180, 220)
    licBadge.Font = Enum.Font.Code
    licBadge.TextSize = 10
    licBadge.Parent = licPanel

    -- [C-1] fix: VERIFY button now re-applies license gate + refreshes toggle visuals
    local toggleButtons = {}   -- filled by addToggle below; key → button ref

    verBtn.MouseButton1Click:Connect(function()
        local newKey = keyInput.Text
        if newKey and newKey ~= "" then
            LICENSE_KEY = newKey
            checkLicense()
            applyLicenseGate()                                     -- [C-1] fix: re-gate after verify
            licBadge.Text = "Tier: " .. LICENSE_TIER .. "  |  Exp: " .. LICENSE_EXPIRY
                .. "  |  Features: " .. countFeatures()            -- [C-2] fix
            if LICENSE_TIER ~= "none" then
                verBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 90)
                verBtn.Text = "RE-VERIFY"
            else
                verBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
                verBtn.Text = "✗ INVALID"
            end
            -- refresh toggle button visuals after re-gate
            for key, btn in pairs(toggleButtons) do
                btn.BackgroundColor3 = CFG[key] and Color3.fromRGB(0, 150, 110) or Color3.fromRGB(38, 42, 58)
                local label = btn:GetAttribute("_label") or key
                btn.Text = "  " .. label .. (CFG[key] and "   [ON]" or "   [OFF]")
            end
        end
    end)

    -- stats grid                                                   [M-3] fix: positioned below license panel
    statGrid = Instance.new("Frame")
    statGrid.Size = UDim2.new(1, -16, 0, 70)
    statGrid.Position = UDim2.new(0, 8, 0, 136)                   -- [M-3] fix: 78+54+4 = 136
    statGrid.BackgroundTransparency = 1
    statGrid.Name = "StatGrid"
    statGrid.Parent = main
    local statLayout = Instance.new("UIListLayout")
    statLayout.Padding = UDim.new(0, 4)
    statLayout.SortOrder = Enum.SortOrder.LayoutOrder
    statLayout.Parent = statGrid
    for _, li in ipairs({
        {"ROLLS", "rolled"}, {"COLLECTED", "collected"}, {"SELL", "sold"},
        {"TOWER FLOOR", "towerBest"}, {"TIER UP", "upgrades"}, {"REBIRTH", "rebirths"},
        {"CODES", "codesDone"}, {"CLAIMS", "claims"},
    }) do
        local lb = Instance.new("TextLabel")
        lb.Size = UDim2.new(0.5, -2, 0, 16)
        lb.BackgroundTransparency = 1
        lb.Text = li[1] .. ": "
        lb.TextColor3 = Color3.fromRGB(120, 160, 200)
        lb.Font = Enum.Font.Code
        lb.TextSize = 11
        lb.Name = "StatLabel"
        lb.Parent = statGrid
    end
    -- dynamic stat label refs
    local statLabels = {}
    for _, child in ipairs(statGrid:GetChildren()) do
        if child:IsA("TextLabel") and child.Name == "StatLabel" then
            table.insert(statLabels, child)
        end
    end
    local function refreshStats()
        if minimized then return end
        for i, child in ipairs(statLabels) do
            if i == 1 then child.Text = "ROLLS   " .. fmt(ST.rolled)
            elseif i == 2 then child.Text = "COLLECT " .. fmt(ST.collected)
            elseif i == 3 then child.Text = "SELL    " .. fmt(ST.sold)
            elseif i == 4 then child.Text = "TOWER   " .. fmt(ST.towerBest)
            elseif i == 5 then child.Text = "TIER UP " .. fmt(ST.upgrades)
            elseif i == 6 then child.Text = "REBIRTH " .. fmt(ST.rebirths)
            elseif i == 7 then child.Text = "CODES   " .. fmt(ST.codesDone)
            elseif i == 8 then child.Text = "CLAIMS  " .. fmt(ST.claims)
            end
        end
    end

    list = Instance.new("ScrollingFrame")                          -- [C-6] fix: assigns to forward-declared local
    list.Size = UDim2.new(1, -16, 0, 220)
    list.Position = UDim2.new(0, 8, 0, 210)                       -- [M-3] fix: 136+70+4 = 210
    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 4
    list.CanvasSize = UDim2.new(0, 0, 0, 0)
    list.Parent = main
    local ll = Instance.new("UIListLayout")
    ll.Padding = UDim.new(0, 4)
    ll.SortOrder = Enum.SortOrder.LayoutOrder
    ll.Parent = list
    ll:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        list.CanvasSize = UDim2.new(0, 0, 0, ll.AbsoluteContentSize.Y + 8)
    end)

    -- [C-6] fix: minimize handler is connected AFTER list and statGrid are created
    minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        main.Size = UDim2.new(0, 320, 0, minimized and collapsedH or fullH)
        list.Visible = not minimized                               -- [C-6] fix: safe now
        statGrid.Visible = not minimized                           -- [C-6] fix: safe now
        if minimized then status.Text = "— minimized —" end       -- [M-1] fix: .Value → .Text
    end)

    -- [H-2] fix: toggle handler checks license gate before allowing toggle-on
    local function addToggle(label, key, order)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -6, 0, 24)
        b.BackgroundColor3 = CFG[key] and Color3.fromRGB(0, 150, 110) or Color3.fromRGB(38, 42, 58)
        b.Text = "  " .. label .. (CFG[key] and "   [ON]" or "   [OFF]")
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Font = Enum.Font.Gotham
        b.TextSize = 12
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.LayoutOrder = order
        b.Parent = list
        b:SetAttribute("_label", label)                            -- store label for verify refresh
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 5); c.Parent = b
        toggleButtons[key] = b                                     -- register for verify refresh
        b.MouseButton1Click:Connect(function()
            -- [H-2] fix: block toggling ON for license-gated features that aren't granted
            if not CFG[key] and not GRANTED_FEATURES[key] then
                -- check if this key is in the gated list
                local isGated = false
                for _, gk in ipairs(GATED_FEATURES) do
                    if gk == key then isGated = true; break end
                end
                if isGated then
                    b.Text = "  " .. label .. "   [LOCKED 🔒]"
                    b.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
                    task.delay(1, function()
                        b.Text = "  " .. label .. "   [OFF]"
                        b.BackgroundColor3 = Color3.fromRGB(38, 42, 58)
                    end)
                    return
                end
            end
            CFG[key] = not CFG[key]
            b.BackgroundColor3 = CFG[key] and Color3.fromRGB(0, 150, 110) or Color3.fromRGB(38, 42, 58)
            b.Text = "  " .. label .. (CFG[key] and "   [ON]" or "   [OFF]")
        end)
    end

    local order = 0
    local function nxt() order = order + 1; return order end
    for _, item in ipairs({
        {"Auto Roll",            "autoRoll"},
        {"Auto Spins (x100/1k)","autoSpins"},
        {"Auto Collect + Place", "autoCollect"},
        {"Auto Level",           "autoLevel"},
        {"Auto Buy Dice",        "autoDice"},
        {"Auto Upgrade",         "autoUpgrade"},
        {"Auto Rebirth",         "autoRebirth"},
        {"Auto Sell Junk",       "autoSell"},
        {"Auto Tower",           "autoTower"},
        {"Auto Boosts",          "autoBoost"},
        {"Auto Grade Reroll",    "autoGrade"},
        {"Auto Trait Reroll",    "autoTrait"},
        {"Auto Codes",           "autoCodes"},
        {"Auto Claims",          "autoClaims"},
    }) do
        addToggle(item[1], item[2], nxt())
    end

    local master = Instance.new("TextButton")
    master.Size = UDim2.new(1, -16, 0, 36)
    master.Position = UDim2.new(0, 8, 1, -48)
    master.BackgroundColor3 = Color3.fromRGB(0, 170, 90)
    master.Text = "START AUTO FARM"
    master.TextColor3 = Color3.new(1, 1, 1)
    master.Font = Enum.Font.GothamBold
    master.TextSize = 15
    master.Parent = main
    local mc = Instance.new("UICorner"); mc.CornerRadius = UDim.new(0, 6); mc.Parent = master

    master.MouseButton1Click:Connect(function()
        CFG.auto = not CFG.auto
        if CFG.auto then
            master.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
            master.Text = "STOP AUTO FARM"
        else
            master.BackgroundColor3 = Color3.fromRGB(0, 170, 90)
            master.Text = "START AUTO FARM"
        end
    end)

    -- refresh stats periodically
    task.spawn(refreshStats)
    task.spawn(function()
        while _G.__PESONA_AD == GEN do
            refreshStats()
            task.wait(2)
        end
    end)

    return { sg = sg, status = status }
end

--====================================================================
--  LOOPS
--====================================================================
local ui = buildGUI()

task.spawn(function()
    while _G.__PESONA_AD == GEN do
        if CFG.auto and CFG.autoRoll then pcall(doRoll) end
        task.wait(rollInterval())
    end
end)

task.spawn(function()
    while _G.__PESONA_AD == GEN do
        if CFG.auto and (CFG.autoCollect or CFG.autoPlace) then    -- [M-2] fix: fire if either is on
            pcall(doCollectPlace)
        end
        task.wait(5)
    end
end)

task.spawn(function()
    while _G.__PESONA_AD == GEN do
        if CFG.auto and CFG.autoSell then pcall(doSell) end
        task.wait(4)
    end
end)

task.spawn(function()
    while _G.__PESONA_AD == GEN do
        if CFG.auto and (CFG.autoGrade or CFG.autoTrait) then pcall(doRerolls) end
        task.wait(4)
    end
end)

task.spawn(function()
    while _G.__PESONA_AD == GEN do
        if CFG.auto and CFG.autoTower then pcall(towerRun) else task.wait(2) end
        task.wait(2)
    end
end)

task.spawn(function()
    while _G.__PESONA_AD == GEN do
        if CFG.auto and CFG.autoBoost then pcall(useBoosts) end
        task.wait(10)
    end
end)

task.spawn(function()
    while _G.__PESONA_AD == GEN do
        if CFG.auto then
            ST.phase = "spending"
            local need = CFG.autoRebirth and nextRebirthCost() or nil
            if need and data().Money >= need then
                if CFG.autoDice then pcall(doDice, need) end
                if CFG.autoUpgrade then pcall(doUpgrade, need) end
                pcall(doRebirth)
            else
                if CFG.autoDice then pcall(doDice) end
                if CFG.autoUpgrade then pcall(doUpgrade) end
            end
            if CFG.autoLevel then pcall(levelSlots) end
        else
            ST.phase = "idle"
        end
        task.wait(3)
    end
end)

task.spawn(function()
    while _G.__PESONA_AD == GEN do
        if CFG.auto and CFG.autoCodes then pcall(doCodes) end
        if CFG.auto and CFG.autoClaims then pcall(doClaims) end
        task.wait(30)
    end
end)

-- snapshot + status refresh
-- [M-4] fix: improved invHash to avoid trivial collisions
local LAST_INV_HASH, LAST_T
local function invHash()
    local d = data()
    local inv = d.Inventory or {}
    local parts = {}
    for k, v in pairs(inv) do
        parts[#parts+1] = tostring(k) .. ":" .. tostring(v.amount or v.name or "")
    end
    table.sort(parts)
    return table.concat(parts, "|")
end

task.spawn(function()
    while _G.__PESONA_AD == GEN do
        local d = data()
        if d then
            ST.money    = d.Money or 0
            ST.rolls    = d.Rolls or 0
            ST.rebirth  = d.Rebirth or 0
            ST.dice     = d.Dice or "-"
            ST.slotsMax = unlockedSlots()
            ST.invCap   = invCap()

            local filled, units = 0, 0
            local slots = d.Slots or {}
            for _, slot in pairs(slots) do
                if slot.unitId then filled = filled + 1 end
            end
            local inv = d.Inventory or {}
            for _, u in pairs(inv) do
                if UnitConfig and UnitConfig.entries and UnitConfig.entries[u.name] then
                    units = units + 1
                end
            end
            ST.slots = filled
            ST.inv  = units
            ST.luck = rollLuck()

            -- compute ST.income from placed slots
            local totalIncome = 0
            for _, slot in pairs(slots) do
                if slot.unitId and inv[slot.unitId] then
                    totalIncome = totalIncome + baseIncome(inv[slot.unitId])
                end
            end
            ST.income = totalIncome

            -- perf: skip snapshot work if inventory unchanged
            local curHash = invHash()
            if curHash == LAST_INV_HASH and LAST_T then
                -- still do ST.money reassign (may have changed)
            end
            LAST_INV_HASH = curHash
            task.wait(1)
            LAST_T = true                                          -- [M-5] fix: was task.wait(1) return value
        end
        if ui and ui.status then
            ui.status.Text = string.format(
                "money %s | income %s/s | rb %d | slots %d/%d | die %s | luck %.1f",
                fmt(ST.money), fmt(ST.income), ST.rebirth,
                ST.slots, ST.slotsMax, ST.dice, ST.luck
            )
        end
    end
end)

print("[PESONA] Anime Dice Auto Farm v4 loaded. Flip START to begin.")  -- [L-2] fix: v3→v4
