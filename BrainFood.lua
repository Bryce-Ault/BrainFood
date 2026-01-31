local addonName, ns = ...

-- Spell names — resolved after PLAYER_LOGIN when spellbook is available
local ARCANE_INTELLECT = "Arcane Intellect"
local ARCANE_BRILLIANCE = "Arcane Brilliance"

-- Buff names to check
local INTELLECT_BUFFS = {
    "Arcane Intellect",
    "Arcane Brilliance",
}

local queue = {}       -- list of unitIDs needing buffs
local currentIndex = 0 -- index into queue for current target

-- ============================================================
-- Helpers
-- ============================================================

local function UnitHasIntellectBuff(unit)
    for i = 1, 40 do
        local name = UnitBuff(unit, i)
        if not name then break end
        for _, buffName in ipairs(INTELLECT_BUFFS) do
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
    if UnitIsUnit(unit, "player") then return false end
    return true
end

local function ScanForUnbuffed()
    wipe(queue)
    currentIndex = 0

    local numMembers = GetNumGroupMembers()
    print("|cff8888ffBrainFood DEBUG:|r Group members: " .. numMembers)
    if numMembers == 0 then return end

    local prefix = IsInRaid() and "raid" or "party"
    local count = IsInRaid() and numMembers or (numMembers - 1)
    print("|cff8888ffBrainFood DEBUG:|r Prefix: " .. prefix .. ", scanning " .. count .. " units")

    for i = 1, count do
        local unit = prefix .. i
        local name = UnitName(unit) or "nil"
        local exists = UnitExists(unit)
        local visible = exists and UnitIsVisible(unit)
        local hasBuff = exists and UnitHasIntellectBuff(unit)
        print("|cff8888ffBrainFood DEBUG:|r " .. unit .. " (" .. name .. ") exists=" .. tostring(exists) .. " visible=" .. tostring(visible) .. " hasBuff=" .. tostring(hasBuff))
        if IsValidBuffTarget(unit) and not UnitHasIntellectBuff(unit) then
            table.insert(queue, unit)
        end
    end
    print("|cff8888ffBrainFood DEBUG:|r Found " .. #queue .. " unbuffed targets")
end

local function AdvanceQueue()
    currentIndex = currentIndex + 1
    -- Skip units that became invalid or got buffed since last scan
    while currentIndex <= #queue do
        local unit = queue[currentIndex]
        if IsValidBuffTarget(unit) and not UnitHasIntellectBuff(unit) then
            return unit
        end
        currentIndex = currentIndex + 1
    end
    -- Ran out — do a fresh scan in case new people arrived
    ScanForUnbuffed()
    currentIndex = 1
    if #queue > 0 then
        return queue[1]
    end
    return nil
end

-- ============================================================
-- Determine which spell the player actually knows
-- ============================================================

local function GetBuffSpellName()
    -- In Classic, /cast Arcane Intellect without a rank casts the highest known rank
    return "Arcane Intellect"
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

    local unit = AdvanceQueue()
    local spell = GetBuffSpellName()
    print("|cff8888ffBrainFood DEBUG:|r UpdateButton — unit=" .. tostring(unit) .. " spell=" .. tostring(spell) .. " btnShown=" .. tostring(btn:IsShown()))

    if unit then
        local name = UnitName(unit) or unit
        local remaining = 0
        for i = currentIndex, #queue do
            local u = queue[i]
            if IsValidBuffTarget(u) and not UnitHasIntellectBuff(u) then
                remaining = remaining + 1
            end
        end

        label:SetText("Feed: " .. name)
        status:SetText(remaining .. " hungry brain(s) left")
        bg:SetColorTexture(0.1, 0.0, 0.3, 0.85)

        local macrotext = "/target " .. name .. "\n/cast Arcane Intellect\n/targetlasttarget"
        print("|cff8888ffBrainFood DEBUG:|r macrotext=" .. macrotext:gsub("\n", "\\n"))

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

local bgActive = false -- true once the battleground has started (gates opened)
local scanTicker = nil  -- periodic rescan timer during prep

local function IsInBattleground()
    local _, instanceType = IsInInstance()
    return instanceType == "pvp"
end

local function PlayerHasPrepBuff()
    for i = 1, 40 do
        local name = UnitBuff("player", i)
        if not name then break end
        if name == "Preparation" then
            return true
        end
    end
    return false
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
        if bgActive or not IsInBattleground() then
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

local throttle = 0
frame:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        -- Show only for mages
        local _, class = UnitClass("player")
        if class ~= "MAGE" then
            btn:Hide()
            self:UnregisterAllEvents()
            return
        end
        -- Short delay to let instance info populate
        C_Timer.After(2, function()
            -- TEST MODE: skip BG checks so it works anywhere in a group
            --if IsInBattleground() then
            --    if PlayerHasPrepBuff() then
            --        bgActive = false
            --        btn:Show()
            --        ScanForUnbuffed()
            --        UpdateButton()
            --        StartScanTicker()
            --        print("|cff8888ffBrainFood:|r BG prep detected. Scanning for hungry brains...")
            --    else
            --        -- Joined mid-match, stay hidden
            --        bgActive = true
            --        btn:Hide()
            --    end
            --else
                -- Not in a BG — reset state, show button for dungeon/raid use
                bgActive = false
                StopScanTicker()
                ScanForUnbuffed()
                UpdateButton()
            --end
        end)

    elseif event == "GROUP_ROSTER_UPDATE" then
        if bgActive then return end
        if not InCombatLockdown() then
            ScanForUnbuffed()
            UpdateButton()
        end

    elseif event == "UNIT_AURA" then
        if bgActive then return end
        local now = GetTime()
        if now - throttle < 0.5 then return end
        throttle = now
        -- TEST MODE: gate-open detection disabled
        --if arg1 == "player" and IsInBattleground() and not PlayerHasPrepBuff() and not bgActive then
        --    HideForBattle()
        --    return
        --end
        if not InCombatLockdown() then
            UpdateButton()
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        if bgActive then
            btn:Hide()
            return
        end
        ScanForUnbuffed()
        UpdateButton()

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if bgActive then return end
        if arg1 == "player" then
            local spellName = ...
            if spellName == ARCANE_INTELLECT or spellName == ARCANE_BRILLIANCE then
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
