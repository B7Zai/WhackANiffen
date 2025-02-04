local _, wan = ...

if wan.PlayerState.Class ~= "MAGE" then return end

local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nSpellsteal = 0


local function CheckAbilityValue()

    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or not wan.IsSpellUsable(wan.spellData.Spellsteal.id) or not wan.CheckStealBool()
    then
        wan.UpdateMechanicData(wan.spellData.Spellsteal.basename)
        return
    end

    local cSpellsteal = nSpellsteal

    local abilityValue = math.floor(cSpellsteal)
    wan.UpdateMechanicData(wan.spellData.Spellsteal.basename, abilityValue, wan.spellData.Spellsteal.icon, wan.spellData.Spellsteal.name)
end

local frameSoothe = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    if addonName ~= "WhackANiffen" then return end

    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            local nSpellstealValue = 10
            nSpellsteal = wan.AbilityPercentageToValue(nSpellstealValue)
        end
    end)
end
frameSoothe:RegisterEvent("ADDON_LOADED")
frameSoothe:SetScript("OnEvent", AddonLoad)

wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Spellsteal.known and wan.spellData.Spellsteal.id
        wan.BlizzardEventHandler(frameSoothe, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
        wan.SetUpdateRate(frameSoothe, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameSoothe, CheckAbilityValue, abilityActive)
    end
end)