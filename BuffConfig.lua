local _, ns = ...

ns.CLASS_CONFIG = {
    MAGE = {
        cast = "Arcane Intellect",
        buffs = { "Arcane Intellect", "Arcane Brilliance" },
        skipClasses = { ROGUE = true, WARRIOR = true },
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
