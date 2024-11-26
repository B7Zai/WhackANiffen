local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameFrenziedRegeneration = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init data
    local abilityActive = false
    local nFrenziedRegenerationHeal = 0
    local healthMax = 0

    -- Init traid data
    local nInnateResolve = 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or wan.auraData.player.buff_FrenziedRegeneration
            or not wan.IsSpellUsable(wan.spellData.FrenziedRegeneration.id)
        then
            wan.UpdateMechanicData(wan.spellData.FrenziedRegeneration.basename)
            return
        end

        -- Base values
        local cFrenziedRegenerationHeal = nFrenziedRegenerationHeal

        -- Innate Resolve
        if wan.traitData.InnateResolve.known then
            local currentHealth = UnitHealth("player")
            local cInnateResolveRatio = (currentHealth / healthMax) * nInnateResolve
            local cInnateResolve = nFrenziedRegenerationHeal * cInnateResolveRatio
            cFrenziedRegenerationHeal = cFrenziedRegenerationHeal + cInnateResolve
        end

        -- Update ability data
        local abilityValue = wan.HealThreshold() > cFrenziedRegenerationHeal and math.floor(cFrenziedRegenerationHeal) or 0
        wan.UpdateMechanicData(wan.spellData.FrenziedRegeneration.basename, abilityValue, wan.spellData.FrenziedRegeneration.icon, wan.spellData.FrenziedRegeneration.name)
    end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nFrenziedRegeneration = wan.GetSpellDescriptionNumbers(wan.spellData.FrenziedRegeneration.id, { 1 })
            nFrenziedRegenerationHeal = wan.AbilityPercentageToValue(nFrenziedRegeneration)

            healthMax = UnitHealthMax("player")
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.FrenziedRegeneration.known and wan.spellData.FrenziedRegeneration.id
            wan.BlizzardEventHandler(frameFrenziedRegeneration, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameFrenziedRegeneration, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then 
            nInnateResolve = wan.GetTraitDescriptionNumbers(wan.traitData.InnateResolve.entryid, { 1 }) / 100
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameFrenziedRegeneration, CheckAbilityValue, abilityActive)
        end
    end)
end

frameFrenziedRegeneration:RegisterEvent("ADDON_LOADED")
frameFrenziedRegeneration:SetScript("OnEvent", AddonLoad)