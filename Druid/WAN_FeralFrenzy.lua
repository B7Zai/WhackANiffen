local _, wan = ...

local frameFeralFrenzy = CreateFrame("Frame")
local function OnEvent(self, event, addonName)
    -- Early Exits
    if addonName ~= "WhackANiffen" or wan.PlayerState.Class ~= "DRUID" then return end

    -- Init data
    local abilityActive = false
    local nFeralFrenzyInstantDmg, nFeralFrenzyDotDmg = 0, 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.FeralFrenzy.id)
        then
            wan.UpdateAbilityData(wan.spellData.FeralFrenzy.basename)
            return
        end

        -- Check for valid unit
        local isValidUnit = wan.ValidUnitBoolCounter(wan.spellData.FeralFrenzy.id)
        if not isValidUnit then
            wan.UpdateAbilityData(wan.spellData.FeralFrenzy.basename)
            return
        end

        -- Remove physical layer
        local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction(wan.classificationData)
        local cFeralFrenzyInstantDmg = nFeralFrenzyInstantDmg * checkPhysicalDR

        -- Dot value
        local dotPotency = wan.CheckDotPotency(cFeralFrenzyInstantDmg)
        local cFeralFrenzyDotDmg = (not wan.auraData[wan.TargetUnitID].debuff_FeralFrenzy and (nFeralFrenzyDotDmg * dotPotency)) or 0

        -- Base value
        local cFeralFrenzy = cFeralFrenzyInstantDmg + cFeralFrenzyDotDmg
        local cdPotency = wan.CheckOffensiveCooldownPotency(cFeralFrenzy, isValidUnit)

        -- Crit layer
        cFeralFrenzy = cFeralFrenzy * wan.ValueFromCritical(wan.CritChance)

        -- Update ability data
        local abilityValue = cdPotency and math.floor(cFeralFrenzy) or 0
        wan.UpdateAbilityData(wan.spellData.FeralFrenzy.basename, abilityValue, wan.spellData.FeralFrenzy.icon, wan.spellData.FeralFrenzy.name)
    end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local feralFrenzyValues = wan.GetSpellDescriptionNumbers(wan.spellData.FeralFrenzy.id, { 2, 3 })
            nFeralFrenzyInstantDmg = feralFrenzyValues[1]
            nFeralFrenzyDotDmg = feralFrenzyValues[2]
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.FeralFrenzy.known and wan.spellData.FeralFrenzy.id
            wan.BlizzardEventHandler(frameFeralFrenzy, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameFeralFrenzy, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameFeralFrenzy, CheckAbilityValue, abilityActive)
        end
    end)
end

frameFeralFrenzy:RegisterEvent("ADDON_LOADED")
frameFeralFrenzy:SetScript("OnEvent", OnEvent)