local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nTranquilizingShot = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or not wan.IsSpellUsable(wan.spellData.TranquilizingShot.id) or not wan.CheckPurgeBool()
    then
        wan.UpdateMechanicData(wan.spellData.TranquilizingShot.basename)
        return
    end

    -- Base values
    local cTranquilizingShot = nTranquilizingShot

    -- Update ability data
    local abilityValue = math.floor(cTranquilizingShot)
    wan.UpdateMechanicData(wan.spellData.TranquilizingShot.basename, abilityValue, wan.spellData.TranquilizingShot.icon, wan.spellData.TranquilizingShot.name)
end

-- Init frame 
local frameTranquilizingShot = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            local nTranquilizingShotValue = 10
            nTranquilizingShot = wan.AbilityPercentageToValue(nTranquilizingShotValue)
        end
    end)
end
frameTranquilizingShot:RegisterEvent("ADDON_LOADED")
frameTranquilizingShot:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.TranquilizingShot.known and wan.spellData.TranquilizingShot.id
        wan.BlizzardEventHandler(frameTranquilizingShot, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
        wan.SetUpdateRate(frameTranquilizingShot, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameTranquilizingShot, CheckAbilityValue, abilityActive)
    end
end)