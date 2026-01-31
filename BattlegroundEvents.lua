local _, ns = ...

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
    scanTicker = C_Timer.NewTicker(3, function()
        if ns.bgActive or not ns.inBattleground then
            StopScanTicker()
            return
        end
        ns.ScanForUnbuffed()
        if not InCombatLockdown() then
            ns.UpdateButton()
        end
    end)
end

local function HideForBattle()
    ns.bgActive = true
    StopScanTicker()
    if not InCombatLockdown() then
        ns.btn:Hide()
    else
        C_Timer.After(0.5, function()
            if ns.bgActive and not InCombatLockdown() then
                ns.btn:Hide()
            end
        end)
    end
    ns.Print("Battleground started. Hiding until next prep phase.")
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
        ns.buffNames = config.buffs
        ns.castSpells = { config.cast }
        if config.targetOverrides then
            for _, override in pairs(config.targetOverrides) do
                table.insert(ns.castSpells, override.cast)
            end
        end

        C_Timer.After(2, function()
            if IsInBattleground() then
                ns.inBattleground = true
                ns.bgActive = false
                ns.btn:Show()
                ns.ScanForUnbuffed()
                ns.UpdateButton()
                StartScanTicker()
                ns.Print("Battleground detected. Scanning for hungry brains...")
            else
                ns.inBattleground = false
                ns.bgActive = false
                StopScanTicker()
                ns.btn:Hide()
            end
        end)

    elseif event == "CHAT_MSG_BG_SYSTEM_NEUTRAL" then
        if arg1 and arg1:find("has begun") then
            HideForBattle()
        end

    elseif event == "GROUP_ROSTER_UPDATE" then
        if ns.bgActive or not ns.inBattleground then return end
        if not InCombatLockdown() then
            ns.ScanForUnbuffed()
            ns.UpdateButton()
        end

    elseif event == "UNIT_AURA" then
        if ns.bgActive or not ns.inBattleground then return end
        local now = GetTime()
        if now - throttle < 0.5 then return end
        throttle = now
        if not InCombatLockdown() then
            ns.UpdateButton()
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        if ns.bgActive or not ns.inBattleground then return end
        ns.ScanForUnbuffed()
        ns.UpdateButton()

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if ns.bgActive or not ns.inBattleground then return end
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
