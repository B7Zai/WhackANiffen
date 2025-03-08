local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nRiteofAdjuration = 0


local function CheckAbilityValue()
    if not wan.PlayerState.Status or wan.PlayerState.Combat
        or not wan.CheckSelfBuff(wan.spellData.RiteofAdjuration.formattedName)
        or not wan.IsSpellUsable(wan.spellData.RiteofAdjuration.id)
    then
        wan.UpdateMechanicData(wan.spellData.RiteofAdjuration.basename)
        return
    end

    local cRiteofAdjuration = nRiteofAdjuration

    local abilityValue = cRiteofAdjuration
    wan.UpdateMechanicData(wan.spellData.RiteofAdjuration.basename, abilityValue, wan.spellData.RiteofAdjuration.icon, wan.spellData.RiteofAdjuration.name)
end

local frameRiteofAdjuration = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)

    if addonName ~= "WhackANiffen" then return end

    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nRiteofSanctificationValue = wan.GetSpellDescriptionNumbers(wan.spellData.RiteofAdjuration.id, { 1 })
            nRiteofAdjuration = wan.AbilityPercentageToValue(nRiteofSanctificationValue)
        end
    end)
end
frameRiteofAdjuration:RegisterEvent("ADDON_LOADED")
frameRiteofAdjuration:SetScript("OnEvent", AddonLoad)

wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.RiteofAdjuration.known and wan.spellData.RiteofAdjuration.id
        wan.BlizzardEventHandler(frameRiteofAdjuration, abilityActive, "UNIT_AURA", "SPELLS_CHANGED", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameRiteofAdjuration, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameRiteofAdjuration, CheckAbilityValue, abilityActive)
    end
end)
