local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local playerUnitToken = "player"
local abilityActive = false
local nFrenziedRegenerationHeal = 0
local nReinvigoration, nRejuvenationHotHeal, nRegrowthInstantHeal, nRegrowthHotHeal = 0, 0, 0, 0

-- Init traid data
local nInnateResolve = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.FrenziedRegeneration.id)
    then
        wan.UpdateMechanicData(wan.spellData.FrenziedRegeneration.basename)
        return
    end

    local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1

    -- Base values
    local cFrenziedRegenerationHeal = nFrenziedRegenerationHeal
    local hotPotency = wan.HotPotency(playerUnitToken, currentPercentHealth)
    wan.HotValue[playerUnitToken] = wan.HotValue[playerUnitToken] or {}

    -- Innate Resolve
    local cInnateResolve = 1
    if wan.traitData.InnateResolve.known then
        --local maxHealth = wan.UnitState.MaxHealth[playerUnitToken]
        --local currentHealth = wan.UnitState.Health[unitToken]
        --ocal cInnateResolveRatio = (currentHealth / maxHealth) * nInnateResolve
        --cInnateResolve = cInnateResolve * cInnateResolveRatio
        cInnateResolve = cInnateResolve * (1 + nInnateResolve)
    end

    local cInvigoration = 1
    local cInvigorationHotHeal = 0
    if wan.traitData.Reinvigoration.known then
        cInvigoration = cInvigoration + nReinvigoration 
        cInvigorationHotHeal = cInvigorationHotHeal + ((nRejuvenationHotHeal + nRegrowthInstantHeal + nRegrowthHotHeal) * cInvigoration)
    end

    cFrenziedRegenerationHeal = ((cFrenziedRegenerationHeal * cInnateResolve) + cInvigorationHotHeal) * hotPotency

    wan.HotValue[playerUnitToken][wan.spellData.FrenziedRegeneration.basename] = cFrenziedRegenerationHeal

    -- subtract healing value of ability's hot from ability's max healing value
    if wan.auraData[playerUnitToken]["buff_" .. wan.spellData.FrenziedRegeneration.basename] then
        local hotValue = wan.HotValue[playerUnitToken][wan.spellData.FrenziedRegeneration.basename]
        cFrenziedRegenerationHeal = cFrenziedRegenerationHeal - hotValue
    end

    -- update healing data
    local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cFrenziedRegenerationHeal, currentPercentHealth)
    wan.UpdateMechanicData(wan.spellData.FrenziedRegeneration.basename, abilityValue, wan.spellData.FrenziedRegeneration.icon, wan.spellData.FrenziedRegeneration.name)
end

-- Init frame 
local frameFrenziedRegeneration = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nFrenziedRegeneration = wan.GetSpellDescriptionNumbers(wan.spellData.FrenziedRegeneration.id, { 1 })
            nFrenziedRegenerationHeal = wan.AbilityPercentageToValue(nFrenziedRegeneration)

            nRejuvenationHotHeal = wan.GetTraitDescriptionNumbers(wan.traitData.Rejuvenation.entryid, { 1 })
            
            local nRegrowthValues = wan.GetSpellDescriptionNumbers(wan.spellData.Regrowth.id, { 1, 2 })
            nRegrowthInstantHeal = nRegrowthValues[1]
            nRegrowthHotHeal = nRegrowthValues[2]
        end
    end)
end
frameFrenziedRegeneration:RegisterEvent("ADDON_LOADED")
frameFrenziedRegeneration:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.FrenziedRegeneration.known and wan.spellData.FrenziedRegeneration.id
        wan.BlizzardEventHandler(frameFrenziedRegeneration, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameFrenziedRegeneration, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nInnateResolve = wan.GetTraitDescriptionNumbers(wan.traitData.InnateResolve.entryid, { 1 }) * 0.01

        nReinvigoration = wan.GetTraitDescriptionNumbers(wan.traitData.Reinvigoration.entryid, { 2 }, wan.traitData.Reinvigoration.rank) * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameFrenziedRegeneration, CheckAbilityValue, abilityActive)
    end
end)
