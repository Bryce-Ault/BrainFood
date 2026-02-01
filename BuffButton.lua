local _, ns = ...

local btn = CreateFrame("Button", "BrainFoodButton", UIParent, "SecureActionButtonTemplate")
btn:SetSize(220, 40)
btn:SetPoint("TOP", UIParent, "TOP", 0, -120)
btn:SetFrameStrata("HIGH")
btn:SetMovable(true)
btn:EnableMouse(true)
btn:RegisterForDrag("LeftButton")
btn:RegisterForClicks("AnyUp", "AnyDown")

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

local status = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
status:SetPoint("TOP", btn, "BOTTOM", 0, -4)
status:SetTextColor(0.7, 0.7, 1.0)
status:SetText("")

local leftHint = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
leftHint:SetPoint("TOP", status, "BOTTOM", 0, -2)
leftHint:SetTextColor(0.53, 1.0, 0.53)
leftHint:SetText("")

local rightHint = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
rightHint:SetPoint("TOP", leftHint, "BOTTOM", 0, -1)
rightHint:SetTextColor(0.53, 1.0, 0.53)
rightHint:SetText("")

-- Start hidden until we enter a BG
btn:Hide()

-- Expose to namespace
ns.btn = btn

function ns.UpdateButton()
    if InCombatLockdown() then return end

    local unit = ns.GetNextTarget()

    if unit then
        local name = UnitName(unit) or unit
        local cfg = ns.GetConfigForUnit(unit)
        local spell = cfg and cfg.cast or ns.castSpell
        local greaterSpell = cfg and cfg.greaterCast or ns.greaterCastSpell
        local remaining = 0
        for _, u in ipairs(ns.queue) do
            if ns.UnitNeedsBuff(u) then
                remaining = remaining + 1
            end
        end

        label:SetText("Feed: " .. name)
        status:SetText(remaining .. " hungry brain(s) left")
        leftHint:SetText("Left-click: " .. spell)
        rightHint:SetText("Right-click: " .. (greaterSpell or spell))
        bg:SetColorTexture(0.1, 0.0, 0.3, 0.85)

        local macrotext = "/target " .. name .. "\n/cast " .. spell .. "\n/targetlasttarget"
        local greaterMacrotext = "/target " .. name .. "\n/cast " .. (greaterSpell or spell) .. "\n/targetlasttarget"

        btn:SetAttribute("type1", "macro")
        btn:SetAttribute("macrotext1", macrotext)
        btn:SetAttribute("type2", "macro")
        btn:SetAttribute("macrotext2", greaterMacrotext)
    else
        label:SetText("BrainFood: All Fed!")
        status:SetText("Everyone has big brain energy")
        leftHint:SetText("")
        rightHint:SetText("")
        bg:SetColorTexture(0.0, 0.2, 0.0, 0.85)

        btn:SetAttribute("type1", nil)
        btn:SetAttribute("macrotext1", nil)
        btn:SetAttribute("type2", nil)
        btn:SetAttribute("macrotext2", nil)
    end
end
