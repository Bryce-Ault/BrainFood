local _, ns = ...

local scanTicker = nil

local function IsInBattlegroundOrArena()
    local _, instanceType = IsInInstance()
    return instanceType == "pvp" or instanceType == "arena"
end

local function HasPreparationBuff()
    for i = 1, 40 do
        local name = UnitBuff("player", i)
        if not name then break end
        if name == "Preparation" then return true end
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
    scanTicker = C_Timer.NewTicker(3, function()
        if not ns.btn:IsShown() then
            StopScanTicker()
            return
        end
        ns.ScanForUnbuffed()
        if not InCombatLockdown() then
            ns.UpdateButton()
        end
    end)
end

function ns.EnableButton()
    if InCombatLockdown() then return end
    ns.btn:Show()
    ns.ScanForUnbuffed()
    ns.UpdateButton()
    StartScanTicker()
end

function ns.DisableButton()
    if InCombatLockdown() then return end
    StopScanTicker()
    ns.btn:Hide()
end

local function HideForBattle()
    ns.bgActive = true
    ns.DisableButton()
    ns.Print("Match started. Hiding BrainFood.")
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("UNIT_AURA")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")

local throttle = 0
frame:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        local _, class = UnitClass("player")
        local config = ns.CLASS_CONFIG[class]
        if not config then
            ns.btn:Hide()
            self:UnregisterAllEvents()
            return
        end
        ns.playerClass = class
        ns.castSpell = config.cast
        ns.greaterCastSpell = config.greaterCast
        ns.buffNames = config.buffs
        ns.castSpells = { config.cast, config.greaterCast }
        if config.targetOverrides then
            for _, override in pairs(config.targetOverrides) do
                table.insert(ns.castSpells, override.cast)
                if override.greaterCast then
                    table.insert(ns.castSpells, override.greaterCast)
                end
            end
        end

        C_Timer.After(2, function()
            if IsInBattlegroundOrArena() then
                ns.inBattleground = true
                if HasPreparationBuff() then
                    ns.bgActive = false
                    ns.EnableButton()
                    ns.Print("Match detected. Scanning for hungry brains...")
                else
                    ns.bgActive = true
                    ns.DisableButton()
                    ns.Print("Match already in progress. BrainFood hidden.")
                end
            else
                ns.inBattleground = false
                ns.bgActive = false
                ns.DisableButton()
            end
        end)

    elseif event == "CHAT_MSG_BG_SYSTEM_NEUTRAL" then
        if arg1 and arg1:find("has begun") then
            HideForBattle()
        end

    elseif event == "GROUP_ROSTER_UPDATE" then
        if not ns.btn:IsShown() then return end
        if not InCombatLockdown() then
            ns.ScanForUnbuffed()
            ns.UpdateButton()
        end

    elseif event == "UNIT_AURA" then
        if not ns.btn:IsShown() then return end
        local now = GetTime()
        if now - throttle < 0.5 then return end
        throttle = now
        if not InCombatLockdown() then
            ns.UpdateButton()
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        if not ns.btn:IsShown() then return end
        if ns.bgActive then
            ns.DisableButton()
            return
        end
        ns.ScanForUnbuffed()
        ns.UpdateButton()

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if not ns.btn:IsShown() then return end
        if arg1 == "player" then
            local spellName = ...
            local isOurSpell = false
            for _, s in ipairs(ns.castSpells) do
                if spellName == s then isOurSpell = true; break end
            end
            if isOurSpell then
                C_Timer.After(0.3, function()
                    if not InCombatLockdown() then
                        ns.UpdateButton()
                    end
                end)
            end
        end
    end
end)
