local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init data
local abilityActive = false
local nBristlingFur = 0
local rageMax = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status 
        or not wan.CheckUnitBuff(nil, wan.spellData.BearForm.formattedName)
        or not wan.IsTanking()
        or not wan.IsSpellUsable(wan.spellData.BristlingFur.id)
    then
        wan.UpdateMechanicData(wan.spellData.BristlingFur.basename)
        return
    end

    -- Rage checker
    local currentRage = UnitPower("player", 1) or 0
    local ragePercentage = (currentRage / rageMax) * 100

    -- Base value
    local cBristlingFur = nBristlingFur

    -- Update ability data
    local healValue = ragePercentage < 30 and cBristlingFur or 0
    wan.UpdateMechanicData(wan.spellData.BristlingFur.basename, healValue, wan.spellData.BristlingFur.icon, wan.spellData.BristlingFur.name)
end

-- Local frame and event handler
local frameBristlingFur = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            nBristlingFur = wan.DefensiveCooldownToValue(wan.spellData.BristlingFur.id)
            rageMax = UnitPowerMax("player", 1) or 100
        end
    end)
end
frameBristlingFur:RegisterEvent("ADDON_LOADED")
frameBristlingFur:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.BristlingFur.known and wan.spellData.BristlingFur.id
        wan.BlizzardEventHandler(frameBristlingFur, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
        wan.SetUpdateRate(frameBristlingFur, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameBristlingFur, CheckAbilityValue, abilityActive)
    end
end)