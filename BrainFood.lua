local addonName, ns = ...

-- Spell names (localization-safe: pulled from spellbook)
local ARCANE_INTELLECT = GetSpellInfo(10157) or "Arcane Intellect"
local ARCANE_BRILLIANCE = GetSpellInfo(23028) or "Arcane Brilliance"

-- Buff names to check (same as spell names for these)
local INTELLECT_BUFFS = {
    ARCANE_INTELLECT,
    ARCANE_BRILLIANCE,
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
    if numMembers == 0 then return end

    local prefix = IsInRaid() and "raid" or "party"
    local count = IsInRaid() and numMembers or (numMembers - 1)

    for i = 1, count do
        local unit = prefix .. i
        if IsValidBuffTarget(unit) and not UnitHasIntellectBuff(unit) then
            table.insert(queue, unit)
        end
    end
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
    -- Prefer Arcane Brilliance (group) if known
    if IsSpellKnown(23028) then
        return ARCANE_BRILLIANCE
    end
    if IsSpellKnown(10157) then
        return ARCANE_INTELLECT
    end
    -- Fall back to lower ranks
    for _, id in ipairs({10156, 1008, 8450, 1459}) do
        if IsSpellKnown(id) then
            return GetSpellInfo(id)
        end
    end
    return ARCANE_INTELLECT
end

-- ============================================================
-- UI
-- ============================================================

local btn = CreateFrame("Button", "BrainFoodButton", UIParent, "SecureActionButtonTemplate")
btn:SetSize(220, 40)
btn:SetPoint("TOP", UIParent, "TOP", 0, -120)
btn:SetMovable(true)
btn:EnableMouse(true)
btn:RegisterForDrag("LeftButton")
btn:RegisterForClicks("AnyUp")

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

        btn:SetAttribute("type", "macro")
        btn:SetAttribute("macrotext", "/target " .. name .. "\n/cast " .. spell .. "\n/targetlasttarget")
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
        ScanForUnbuffed()
        UpdateButton()

    elseif event == "GROUP_ROSTER_UPDATE" then
        if not InCombatLockdown() then
            ScanForUnbuffed()
            UpdateButton()
        end

    elseif event == "UNIT_AURA" then
        -- Throttle aura updates
        local now = GetTime()
        if now - throttle < 0.5 then return end
        throttle = now
        if not InCombatLockdown() then
            UpdateButton()
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Left combat — safe to update secure button
        ScanForUnbuffed()
        UpdateButton()

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if arg1 == "player" then
            local spellName = ...
            if spellName == ARCANE_INTELLECT or spellName == ARCANE_BRILLIANCE then
                -- Brief delay so the buff registers on the target
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
