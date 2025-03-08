local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nChampionsSpear, nChampionsSpearMaxRange = 0, 12

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.ChampionsSpear.id) then
        wan.UpdateAbilityData(wan.spellData.ChampionsSpear.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, wan.spellData.ChampionsSpear.maxRange)
    if countValidUnit == 0 then
        wan.UpdateAbilityData(wan.spellData.ChampionsSpear.basename)
        return
    end

    -- Base value
    local cChampionsSpear = nChampionsSpear
    local cdPotency = wan.CheckOffensiveCooldownPotency(cChampionsSpear, isValidUnit, idValidUnit)

    -- Update ability data
    local abilityValue = cdPotency and math.floor(cChampionsSpear) or 0
    wan.UpdateAbilityData(wan.spellData.ChampionsSpear.basename, abilityValue, wan.spellData.ChampionsSpear.icon, wan.spellData.ChampionsSpear.name)
end

-- Init frame 
local frameChampionsSpear = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nChampionsSpear = wan.OffensiveCooldownToValue(wan.spellData.ChampionsSpear.id)
        end
    end)
end
frameChampionsSpear:RegisterEvent("ADDON_LOADED")
frameChampionsSpear:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.ChampionsSpear.known and wan.spellData.ChampionsSpear.id
        wan.BlizzardEventHandler(frameChampionsSpear, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameChampionsSpear, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameChampionsSpear, CheckAbilityValue, abilityActive)
    end
end)