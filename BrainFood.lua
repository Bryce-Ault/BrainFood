local addonName, ns = ...

-- Class-specific configuration (set on PLAYER_ENTERING_WORLD)
local castSpell = nil   -- the spell to cast on click
local buffNames = {}    -- buff auras to check for (if any present, skip that unit)
local castSpells = {}   -- all spells this class can cast (for spellcast detection)
local playerClass = nil

local CLASS_CONFIG = {
    MAGE = {
        cast = "Arcane Intellect",
        buffs = { "Arcane Intellect", "Arcane Brilliance" },
    },
    PRIEST = {
        cast = "Power Word: Fortitude",
        buffs = { "Power Word: Fortitude", "Prayer of Fortitude" },
    },
    DRUID = {
        cast = "Mark of the Wild",
        buffs = { "Mark of the Wild", "Gift of the Wild" },
    },
    PALADIN = {
        cast = "Blessing of Wisdom",
        buffs = { "Blessing of Wisdom", "Greater Blessing of Wisdom" },
        targetOverrides = {
            WARRIOR = {
                cast = "Blessing of Might",
                buffs = { "Blessing of Might", "Greater Blessing of Might" },
            },
            ROGUE = {
                cast = "Blessing of Might",
                buffs = { "Blessing of Might", "Greater Blessing of Might" },
            },
        },
    },
}

local queue = {}       -- list of unitIDs needing buffs
local currentIndex = 0 -- index into queue for current target

-- ============================================================
-- Helpers
-- ============================================================

local function GetConfigForUnit(unit)
    local config = CLASS_CONFIG[playerClass]
    if config and config.targetOverrides then
        local _, targetClass = UnitClass(unit)
        if targetClass and config.targetOverrides[targetClass] then
            return config.targetOverrides[targetClass]
        end
    end
    return config
end

local function UnitHasBuff(unit, buffsToCheck)
    local checkBuffs = buffsToCheck or buffNames
    for i = 1, 40 do
        local name = UnitBuff(unit, i)
        if not name then break end
        for _, buffName in ipairs(checkBuffs) do
            if name == buffName then
                return true
            end
        end
    end
    return false
end

local function IsValidBuffTarget(unit)
    if not UnitExists(unit) then return false end
    if UnitIsDeadOrGhost(unit) then return false end
    if not UnitIsConnected(unit) then return false end
    if not UnitIsVisible(unit) then return false end
    if UnitIsUnit(unit, "player") then return true end
    if not CheckInteractDistance(unit, 4) then return false end -- ~30 yard range check
    return true
end

local function ScanForUnbuffed()
    wipe(queue)
    currentIndex = 0

    local numMembers = GetNumGroupMembers()
    if numMembers == 0 then return end

    local prefix = IsInRaid() and "raid" or "party"
    local count = IsInRaid() and numMembers or (numMembers - 1)

    local priority = {}
    local normal = {}

    local function AddUnit(unit)
        if not IsValidBuffTarget(unit) then return end
        local cfg = GetConfigForUnit(unit)
        if cfg and not UnitHasBuff(unit, cfg.buffs) then
            if cfg ~= CLASS_CONFIG[playerClass] then
                table.insert(priority, unit)
            else
                table.insert(normal, unit)
            end
        end
    end

    for i = 1, count do
        AddUnit(prefix .. i)
    end

    -- In a party, "player" isn't one of the partyN units, so check separately
    if not IsInRaid() then
        AddUnit("player")
    end

    -- Override targets (e.g. warriors/rogues needing Might) go first
    for _, u in ipairs(priority) do table.insert(queue, u) end
    for _, u in ipairs(normal) do table.insert(queue, u) end
end

local currentUnit = nil -- the unit we're currently targeting to buff

local function UnitNeedsBuff(unit)
    if not IsValidBuffTarget(unit) then return false end
    local cfg = GetConfigForUnit(unit)
    return cfg and not UnitHasBuff(unit, cfg.buffs)
end

local function GetNextTarget()
    -- If we have a current target that still needs a buff and is in range, stick with them
    if currentUnit and UnitNeedsBuff(currentUnit) then
        return currentUnit
    end

    -- Current target is done or invalid — find the next one from the queue
    currentUnit = nil
    for _, unit in ipairs(queue) do
        if UnitNeedsBuff(unit) then
            currentUnit = unit
            return unit
        end
    end

    -- Queue exhausted — do a fresh scan
    ScanForUnbuffed()
    for _, unit in ipairs(queue) do
        if UnitNeedsBuff(unit) then
            currentUnit = unit
            return unit
        end
    end

    return nil
end

-- ============================================================
-- UI
-- ============================================================

local btn = CreateFrame("Button", "BrainFoodButton", UIParent, "SecureActionButtonTemplate")
btn:SetSize(220, 40)
btn:SetPoint("TOP", UIParent, "TOP", 0, -120)
btn:SetFrameStrata("HIGH")
btn:SetMovable(true)
btn:EnableMouse(true)
btn:RegisterForDrag("LeftButton")
btn:RegisterForClicks("AnyUp", "AnyDown")

-- Drag handling (only out of combat)
btn:SetScript("OnDragStart", function(self)
    if not InCombatLockdown() then
        self:StartMoving()
    end
end)
btn:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
end)

-- Backdrop
local bg = btn:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0.1, 0.0, 0.3, 0.85)

local border = btn:CreateTexture(nil, "BORDER")
border:SetPoint("TOPLEFT", -1, 1)
border:SetPoint("BOTTOMRIGHT", 1, -1)
border:SetColorTexture(0.5, 0.3, 1.0, 0.6)

local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
label:SetPoint("CENTER")
label:SetText("BrainFood: Scanning...")

-- Status text below the button
local status = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
status:SetPoint("TOP", btn, "BOTTOM", 0, -4)
status:SetTextColor(0.7, 0.7, 1.0)
status:SetText("")

local function UpdateButton()
    if InCombatLockdown() then return end

    local unit = GetNextTarget()

    if unit then
        local name = UnitName(unit) or unit
        local cfg = GetConfigForUnit(unit)
        local spell = cfg and cfg.cast or castSpell
        local remaining = 0
        for _, u in ipairs(queue) do
            if UnitNeedsBuff(u) then
                remaining = remaining + 1
            end
        end

        label:SetText("Feed: " .. name)
        status:SetText(remaining .. " hungry brain(s) left")
        bg:SetColorTexture(0.1, 0.0, 0.3, 0.85)

        local macrotext = "/target " .. name .. "\n/cast " .. spell .. "\n/targetlasttarget"

        btn:SetAttribute("type", "macro")
        btn:SetAttribute("macrotext", macrotext)
    else
        label:SetText("BrainFood: All Fed!")
        status:SetText("Everyone has big brain energy")
        bg:SetColorTexture(0.0, 0.2, 0.0, 0.85)

        btn:SetAttribute("type", nil)
        btn:SetAttribute("macrotext", nil)
    end
end

-- ============================================================
-- Events
-- ============================================================

local bgActive = false   -- true once the BG match has begun (gates opened)
local inBattleground = false
local scanTicker = nil

local function IsInBattleground()
    local _, instanceType = IsInInstance()
    return instanceType == "pvp"
end

local function StopScanTicker()
    if scanTicker then
        scanTicker:Cancel()
        scanTicker = nil
    end
end

local function StartScanTicker()
    StopScanTicker()
    -- Rescan every 3 seconds during prep (players load in over time)
    scanTicker = C_Timer.NewTicker(3, function()
        if bgActive or not inBattleground then
            StopScanTicker()
            return
        end
        ScanForUnbuffed()
        if not InCombatLockdown() then
            UpdateButton()
        end
    end)
end

local function HideForBattle()
    bgActive = true
    StopScanTicker()
    if not InCombatLockdown() then
        btn:Hide()
    else
        C_Timer.After(0.5, function()
            if bgActive and not InCombatLockdown() then
                btn:Hide()
            end
        end)
    end
    print("|cff8888ffBrainFood:|r Battleground started. Hiding until next prep phase.")
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("UNIT_AURA")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")

-- Start hidden until we enter a BG
btn:Hide()

local throttle = 0
frame:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        -- Configure for supported classes
        local _, class = UnitClass("player")
        local config = CLASS_CONFIG[class]
        if not config then
            btn:Hide()
            self:UnregisterAllEvents()
            return
        end
        playerClass = class
        castSpell = config.cast
        buffNames = config.buffs
        castSpells = { config.cast }
        if config.targetOverrides then
            for _, override in pairs(config.targetOverrides) do
                table.insert(castSpells, override.cast)
            end
        end

        -- Short delay to let instance info populate
        C_Timer.After(2, function()
            if IsInBattleground() then
                inBattleground = true
                bgActive = false
                btn:Show()
                ScanForUnbuffed()
                UpdateButton()
                StartScanTicker()
                print("|cff8888ffBrainFood:|r Battleground detected. Scanning for hungry brains...")
            else
                -- Not in a BG — hide and reset
                inBattleground = false
                bgActive = false
                StopScanTicker()
                btn:Hide()
            end
        end)

    elseif event == "CHAT_MSG_BG_SYSTEM_NEUTRAL" then
        -- "has begun" is the system message when gates open (same as TowerTimer)
        if arg1 and arg1:find("has begun") then
            HideForBattle()
        end

    elseif event == "GROUP_ROSTER_UPDATE" then
        if bgActive or not inBattleground then return end
        if not InCombatLockdown() then
            ScanForUnbuffed()
            UpdateButton()
        end

    elseif event == "UNIT_AURA" then
        if bgActive or not inBattleground then return end
        local now = GetTime()
        if now - throttle < 0.5 then return end
        throttle = now
        if not InCombatLockdown() then
            UpdateButton()
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        if bgActive or not inBattleground then return end
        ScanForUnbuffed()
        UpdateButton()

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if bgActive or not inBattleground then return end
        if arg1 == "player" then
            local spellName = ...
            local isOurSpell = false
            for _, s in ipairs(castSpells) do
                if spellName == s then isOurSpell = true; break end
            end
            if isOurSpell then
                C_Timer.After(0.3, function()
                    if not InCombatLockdown() then
                        UpdateButton()
                    end
                end)
            end
        end
    end
end)

-- ============================================================
-- Slash command: /brainfood — toggle visibility, rescan
-- ============================================================

SLASH_BRAINFOOD1 = "/brainfood"
SLASH_BRAINFOOD2 = "/bf"
SlashCmdList["BRAINFOOD"] = function(msg)
    if msg == "reset" then
        if not InCombatLockdown() then
            btn:ClearAllPoints()
            btn:SetPoint("TOP", UIParent, "TOP", 0, -120)
            print("|cff8888ffBrainFood:|r Position reset.")
        end
        return
    end

    if btn:IsShown() then
        btn:Hide()
        print("|cff8888ffBrainFood:|r Hidden. Type /bf to show again.")
    else
        btn:Show()
        ScanForUnbuffed()
        UpdateButton()
        print("|cff8888ffBrainFood:|r Scanning for hungry brains...")
    end
end

print("|cff8888ffBrainFood|r loaded. /bf to toggle, /bf reset to reset position.")
