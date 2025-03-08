local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nBladestorm, nBladestormMaxRange = 0, 11

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or not wan.IsSpellUsable(wan.spellData.Bladestorm.id)
        or wan.CheckUnitBuff(nil, wan.spellData.Bladestorm.formattedName)
    then
        wan.UpdateAbilityData(wan.spellData.Bladestorm.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nBladestormMaxRange)
    if countValidUnit == 0 then
        wan.UpdateAbilityData(wan.spellData.Bladestorm.basename)
        return
    end

    -- Base value
    local cBladestorm = nBladestorm
    local cdPotency = wan.CheckOffensiveCooldownPotency(cBladestorm, isValidUnit, idValidUnit)

    -- Update ability data
    local abilityValue = cdPotency and math.floor(cBladestorm) or 0
    wan.UpdateAbilityData(wan.spellData.Bladestorm.basename, abilityValue, wan.spellData.Bladestorm.icon, wan.spellData.Bladestorm.name)
end

-- Init frame 
local frameBladestorm = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nBladestorm = wan.OffensiveCooldownToValue(wan.spellData.Bladestorm.id)
        end
    end)
end
frameBladestorm:RegisterEvent("ADDON_LOADED")
frameBladestorm:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Bladestorm.known and wan.spellData.Bladestorm.id
        wan.BlizzardEventHandler(frameBladestorm, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameBladestorm, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameBladestorm, CheckAbilityValue, abilityActive)
    end
end)