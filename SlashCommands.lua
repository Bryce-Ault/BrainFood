local _, ns = ...

SLASH_BRAINFOOD1 = "/brainfood"
SLASH_BRAINFOOD2 = "/bf"
SlashCmdList["BRAINFOOD"] = function(msg)
    if msg == "reset" then
        if not InCombatLockdown() then
            ns.btn:ClearAllPoints()
            ns.btn:SetPoint("TOP", UIParent, "TOP", 0, -120)
            ns.Print("Position reset.")
        end
        return
    end

    if ns.btn:IsShown() then
        ns.DisableButton()
        ns.Print("Hidden. Type /bf to show again.")
    else
        ns.EnableButton()
        ns.Print("Scanning for hungry brains...")
    end
end

ns.Print("Loaded. /bf to toggle, /bf reset to reset position.")
