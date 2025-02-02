local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nRiteofSanctification = 0


local function CheckAbilityValue()
    if not wan.PlayerState.Status or wan.PlayerState.Combat
        or wan.CheckSelfBuff(wan.spellData.RiteofSanctification.basename)
        or not wan.IsSpellUsable(wan.spellData.RiteofSanctification.id)
    then
        wan.UpdateMechanicData(wan.spellData.RiteofSanctification.basename)
        return
    end

    local cRiteofSanctification = nRiteofSanctification

    local abilityValue = cRiteofSanctification
    wan.UpdateMechanicData(wan.spellData.RiteofSanctification.basename, abilityValue, wan.spellData.RiteofSanctification.icon, wan.spellData.RiteofSanctification.name)
end

local frameRiteofSanctification = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)

    if addonName ~= "WhackANiffen" then return end

    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nRiteofSanctificationValue = wan.GetSpellDescriptionNumbers(wan.spellData.RiteofSanctification.id, { 1 })
            nRiteofSanctification = wan.AbilityPercentageToValue(nRiteofSanctificationValue)
        end
    end)
end
frameRiteofSanctification:RegisterEvent("ADDON_LOADED")
frameRiteofSanctification:SetScript("OnEvent", AddonLoad)

wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.RiteofSanctification.known and wan.spellData.RiteofSanctification.id
        wan.BlizzardEventHandler(frameRiteofSanctification, abilityActive, "UNIT_AURA", "SPELLS_CHANGED", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameRiteofSanctification, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameRiteofSanctification, CheckAbilityValue, abilityActive)
    end
end)
