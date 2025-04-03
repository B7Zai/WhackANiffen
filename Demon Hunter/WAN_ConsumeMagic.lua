local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DEMONHUNTER" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nConsumeMagic = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or not wan.IsSpellUsable(wan.spellData.ConsumeMagic.id) or not wan.CheckPurgeBool()
    then
        wan.UpdateMechanicData(wan.spellData.ConsumeMagic.basename)
        return
    end

    -- Base values
    local cConsumeMagic = nConsumeMagic

    -- Update ability data
    local abilityValue = math.floor(cConsumeMagic)
    wan.UpdateMechanicData(wan.spellData.ConsumeMagic.basename, abilityValue, wan.spellData.ConsumeMagic.icon, wan.spellData.ConsumeMagic.name)
end

-- Init frame 
local frameConsumeMagic = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            local nConsumeMagicValue = 10
            nConsumeMagic = wan.AbilityPercentageToValue(nConsumeMagicValue)
        end
    end)
end
frameConsumeMagic:RegisterEvent("ADDON_LOADED")
frameConsumeMagic:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.ConsumeMagic.known and wan.spellData.ConsumeMagic.id
        wan.BlizzardEventHandler(frameConsumeMagic, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
        wan.SetUpdateRate(frameConsumeMagic, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameConsumeMagic, CheckAbilityValue, abilityActive)
    end
end)