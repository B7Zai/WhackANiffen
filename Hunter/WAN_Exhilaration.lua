local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local playerUnitToken = "player"
local abilityActive = false
local nExhilarationInstantHeal, nExhilarationHotHeal = 0, 0

-- Init traid data
local nRejuvenatingWind = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.Exhilaration.id)
    then
        wan.UpdateMechanicData(wan.spellData.Exhilaration.basename)
        return
    end

    local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1

    -- Base values
    local cExhilarationInstantHeal = nExhilarationInstantHeal

    local cExhilarationHotHeal = nExhilarationHotHeal
    local hotPotency = wan.HotPotency(playerUnitToken, currentPercentHealth)

    cExhilarationHotHeal = cExhilarationHotHeal * hotPotency

    wan.HotValue[playerUnitToken] = wan.HotValue[playerUnitToken] or {}
    wan.HotValue[playerUnitToken][wan.traitData.RejuvenatingWind.traitkey] = cExhilarationHotHeal

    -- subtract healing value of ability's hot from ability's max healing value
    if wan.auraData[playerUnitToken]["buff_" .. wan.spellData.Exhilaration.basename] then
        local hotValue = wan.HotValue[playerUnitToken][wan.spellData.Exhilaration.basename]
        cExhilarationHotHeal = cExhilarationHotHeal - hotValue
    end

    local cExhilarationHeal = cExhilarationInstantHeal + cExhilarationHotHeal

    -- update healing data
    local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cExhilarationHeal, currentPercentHealth)
    wan.UpdateMechanicData(wan.spellData.Exhilaration.basename, abilityValue, wan.spellData.Exhilaration.icon, wan.spellData.Exhilaration.name)
end

-- Init frame 
local frameExhilaration = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nExhilarationValues = wan.GetSpellDescriptionNumbers(wan.spellData.Exhilaration.id, { 1 })
            nExhilarationInstantHeal = wan.AbilityPercentageToValue(nExhilarationValues)
        end
    end)
end
frameExhilaration:RegisterEvent("ADDON_LOADED")
frameExhilaration:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Exhilaration.known and wan.spellData.Exhilaration.id
        wan.BlizzardEventHandler(frameExhilaration, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameExhilaration, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nRejuvenatingWind = wan.GetTraitDescriptionNumbers(wan.traitData.RejuvenatingWind.entryid, { 2 })
        nExhilarationHotHeal = wan.AbilityPercentageToValue(nRejuvenatingWind)
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameExhilaration, CheckAbilityValue, abilityActive)
    end
end)
