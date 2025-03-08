local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nBerserkerRage = 0
local dispelTypes = {}

local function CheckAbilityValue()

    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.BerserkerRage.id)
        or not wan.CheckPlayerLossOfControl(dispelTypes)
    then
        wan.UpdateMechanicData(wan.spellData.BerserkerRage.basename)
        return
    end

    local cBerserkerRage = nBerserkerRage

    local abilityValue = math.floor(cBerserkerRage)
    wan.UpdateMechanicData(wan.spellData.BerserkerRage.basename, abilityValue, wan.spellData.BerserkerRage.icon, wan.spellData.BerserkerRage.name)
end

local frameBerserkerRage = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)

    if addonName ~= "WhackANiffen" then return end

    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            nBerserkerRage = wan.DefensiveCooldownToValue(wan.spellData.BerserkerRage.id)
            dispelTypes = wan.CheckDispelType(wan.spellData.BerserkerRage.id)
        end
    end)
end
frameBerserkerRage:RegisterEvent("ADDON_LOADED")
frameBerserkerRage:SetScript("OnEvent", AddonLoad)

wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.BerserkerRage.known and wan.spellData.BerserkerRage.id
        wan.BlizzardEventHandler(frameBerserkerRage, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
        wan.SetUpdateRate(frameBerserkerRage, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameBerserkerRage, CheckAbilityValue, abilityActive)
    end
end)