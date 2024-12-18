local _, wan = ...

wan.spellData = {}
setmetatable(wan.spellData, {
    __index = function(t, key)
        local default = {
            name = "Unknown",
            icon = 134400,
            originalIconID = 134400,
            castTime = 0,
            minRange = 0,
            maxRange = 0,
            id = 61304,
            basename = "Unknown",
            known = false
        }
        t[key] = default
        return default
    end
})

local function GetSpellData(spellDataArray)
    wan.WipeTable(spellDataArray)
    local spellBookItemSpellBank = Enum.SpellBookSpellBank.Player

    for i = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(i)
        if skillLineInfo then
            local offset, numSlots = skillLineInfo.itemIndexOffset, skillLineInfo.numSpellBookItems

            for j = offset + 1, offset + numSlots do
                local spellBookItemInfo = C_SpellBook.GetSpellBookItemInfo(j, spellBookItemSpellBank)
                local spellType, spellID = spellBookItemInfo.itemType, spellBookItemInfo.actionID
                local isPassive, isOffSpec = spellBookItemInfo.isPassive, spellBookItemInfo.isOffSpec

                if spellType == Enum.SpellBookItemType.Spell and not isOffSpec then
                    local baseSpellID = FindBaseSpellByID(spellID)
                    local baseSpellName = C_Spell.GetSpellName(baseSpellID)
                    local overriddenSpellID = C_Spell.GetOverrideSpell(spellID)
                    local spellInfo = C_Spell.GetSpellInfo(overriddenSpellID)
                    local keyName = wan.FormatNameForKey(baseSpellName)

                    if spellInfo then
                        spellDataArray[keyName] = {
                            name = spellInfo.name,
                            icon = spellInfo.iconID,
                            originalIconID = spellInfo.originalIconID,
                            castTime = spellInfo.castTime,
                            minRange = spellInfo.minRange,
                            maxRange = spellInfo.maxRange,
                            id = spellInfo.spellID,
                            basename = keyName,
                            known = true
                        }
                    end
                end
            end
        end
    end
    wan.CustomEvents("SPELL_DATA_READY")
end

local frameAbilityData = CreateFrame("Frame")
wan.RegisterBlizzardEvents(frameAbilityData,
    "PLAYER_ENTERING_WORLD",
    "SPELLS_CHANGED",
    "UNIT_AURA"
)

frameAbilityData:SetScript("OnEvent", function(self, event, ...)
    if event == "SPELLS_CHANGED" or (event == "UNIT_AURA" and ... == "player") or event == "PLAYER_ENTERING_WORLD" then
        GetSpellData(wan.spellData)
    end
end)