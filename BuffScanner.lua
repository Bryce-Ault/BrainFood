local _, ns = ...

function ns.GetConfigForUnit(unit)
    local config = ns.CLASS_CONFIG[ns.playerClass]
    if not config then return nil end
    local _, targetClass = UnitClass(unit)
    if targetClass and config.skipClasses and config.skipClasses[targetClass] then
        return nil
    end
    if targetClass and config.targetOverrides and config.targetOverrides[targetClass] then
        return config.targetOverrides[targetClass]
    end
    return config
end

local BUFF_MIN_REMAINING = 300 -- 5 minutes in seconds

function ns.UnitHasBuff(unit, buffsToCheck)
    local checkBuffs = buffsToCheck or ns.buffNames
    local now = GetTime()
    local checkExpiry = ns.inBattleground and not ns.bgActive
    for i = 1, 40 do
        local name, _, _, _, _, expirationTime = UnitBuff(unit, i)
        if not name then break end
        for _, buffName in ipairs(checkBuffs) do
            if name == buffName then
                if checkExpiry and expirationTime ~= 0 and (expirationTime - now) < BUFF_MIN_REMAINING then
                    break -- treat as unbuffed, keep scanning in case a longer buff exists
                end
                return true
            end
        end
    end
    return false
end

function ns.IsValidBuffTarget(unit)
    if not UnitExists(unit) then return false end
    if UnitIsDeadOrGhost(unit) then return false end
    if not UnitIsConnected(unit) then return false end
    if not UnitIsVisible(unit) then return false end
    if UnitIsUnit(unit, "player") then return true end
    if not CheckInteractDistance(unit, 4) then return false end
    return true
end

function ns.ScanForUnbuffed()
    wipe(ns.queue)
    ns.currentUnit = nil

    local numMembers = GetNumGroupMembers()
    if numMembers == 0 then return end

    local prefix = IsInRaid() and "raid" or "party"
    local count = IsInRaid() and numMembers or (numMembers - 1)

    local priority = {}
    local normal = {}

    local function AddUnit(unit)
        if not ns.IsValidBuffTarget(unit) then return end
        local cfg = ns.GetConfigForUnit(unit)
        if cfg and not ns.UnitHasBuff(unit, cfg.buffs) then
            if cfg ~= ns.CLASS_CONFIG[ns.playerClass] then
                table.insert(priority, unit)
            else
                table.insert(normal, unit)
            end
        end
    end

    for i = 1, count do
        AddUnit(prefix .. i)
    end

    if not IsInRaid() then
        AddUnit("player")
    end

    for _, u in ipairs(priority) do table.insert(ns.queue, u) end
    for _, u in ipairs(normal) do table.insert(ns.queue, u) end
end

function ns.UnitNeedsBuff(unit)
    if not ns.IsValidBuffTarget(unit) then return false end
    local cfg = ns.GetConfigForUnit(unit)
    return cfg and not ns.UnitHasBuff(unit, cfg.buffs)
end

function ns.GetNextTarget()
    if ns.currentUnit and ns.UnitNeedsBuff(ns.currentUnit) then
        return ns.currentUnit
    end

    ns.currentUnit = nil
    for _, unit in ipairs(ns.queue) do
        if ns.UnitNeedsBuff(unit) then
            ns.currentUnit = unit
            return unit
        end
    end

    ns.ScanForUnbuffed()
    for _, unit in ipairs(ns.queue) do
        if ns.UnitNeedsBuff(unit) then
            ns.currentUnit = unit
            return unit
        end
    end

    return nil
end
