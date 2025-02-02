local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nBastionofLight, nBastionofLightMaxRange = 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.BastionofLight.id)
    then
        wan.UpdateMechanicData(wan.spellData.BastionofLight.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nBastionofLightMaxRange)
    if countValidUnit == 0 then
        wan.UpdateMechanicData(wan.spellData.BastionofLight.basename)
        return
    end

    -- Base value
    local cBastionofLight = nBastionofLight
    local cdPotency = wan.CheckOffensiveCooldownPotency(cBastionofLight, isValidUnit, idValidUnit)

    -- Update ability data
    local abilityValue = cdPotency and math.floor(cBastionofLight) or 0
    wan.UpdateMechanicData(wan.spellData.BastionofLight.basename, abilityValue, wan.spellData.BastionofLight.icon, wan.spellData.BastionofLight.name)
end

-- Init frame 
local frameBastionofLight = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nBastionofLight = wan.OffensiveCooldownToValue(wan.spellData.BastionofLight.id)
            nBastionofLightMaxRange = wan.spellData.Judgment.maxRange
        end
    end)
end
frameBastionofLight:RegisterEvent("ADDON_LOADED")
frameBastionofLight:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.BastionofLight.known and wan.spellData.BastionofLight.id
        wan.BlizzardEventHandler(frameBastionofLight, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameBastionofLight, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameBastionofLight, CheckAbilityValue, abilityActive)
    end
end)