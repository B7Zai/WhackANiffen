local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nEvocation, nEvocationCastTime = 0, 0
local currentMana, maxMana, percentageMana = 0, 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or not wan.IsSpellUsable(wan.spellData.Evocation.id)
    then
        wan.UpdateMechanicData(wan.spellData.Evocation.basename)
        return
    end

    local canMovecast = ((wan.traitData.Slipstream.known or wan.auraData.player.buff_IceFloes) and true) or false
    local castEfficiency = wan.CheckCastEfficiency(wan.spellData.ArcaneMissiles.id, nEvocationCastTime, canMovecast)
    if castEfficiency == 0 then
        wan.UpdateAbilityData(wan.spellData.ArcaneMissiles.basename)
        return
    end



    currentMana = UnitPower("player", 0) or 0
    percentageMana = (currentMana / maxMana) * 100
    if percentageMana > 10 then
        wan.UpdateMechanicData(wan.spellData.Evocation.basename)
        return
    end

    -- Base value
    local cEvocation = nEvocation

     -- Update AbilityData
    local abilityValue = math.floor(cEvocation)
    wan.UpdateMechanicData(wan.spellData.Evocation.basename, abilityValue, wan.spellData.Evocation.icon, wan.spellData.Evocation.name)
end

-- Init frame 
local frameEvocation = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        
        if event == "SPELLS_CHANGED" then
            maxMana = UnitPowerMax("player", 0) or 0
        end

        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            nEvocation = wan.DefensiveCooldownToValue(wan.spellData.Evocation.id)

            nEvocationCastTime = wan.GetSpellDescriptionNumbers(wan.spellData.Evocation.id, { 2 }) * 1000
        end
    end)
end
frameEvocation:RegisterEvent("ADDON_LOADED")
frameEvocation:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Evocation.known and wan.spellData.Evocation.id
        wan.BlizzardEventHandler(frameEvocation, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
        wan.SetUpdateRate(frameEvocation, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameEvocation, CheckAbilityValue, abilityActive)
    end
end)