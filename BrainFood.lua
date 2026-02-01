local addonName, ns = ...

-- Shared state (populated during PLAYER_ENTERING_WORLD)
ns.playerClass = nil
ns.castSpell = nil
ns.greaterCastSpell = nil
ns.buffNames = {}
ns.castSpells = {}

-- Buff queue state
ns.queue = {}
ns.currentUnit = nil

-- Battleground state
ns.inBattleground = false
ns.bgActive = false

function ns.Print(msg)
    print("|cff8888ffBrainFood:|r " .. msg)
end
