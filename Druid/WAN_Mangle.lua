local _, wan = ...

local frameMangle = CreateFrame("Frame")
local function OnEvent(self, event, addonName)
    -- Early Exits
    if addonName ~= "WhackANiffen" or wan.PlayerState.Class ~= "DRUID" then return end

    -- Init spell data
    local abilityActive = false
    local checkDebuffs = {"Rake", "Thrash", "Rip", "Feral Frenzy", "Tear", "Frenzied Assault"}
    local nMangleDmg = 0

    -- Init trait data
    local nPrimalFury = 0
    local nMangle = 0
    local nIncarnationAoeCap = 0
    local nStrikeForTheHeart = 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or not wan.auraData.player.buff_BearForm
            or not wan.IsSpellUsable(wan.spellData.Mangle.id)
        then
            wan.UpdateAbilityData(wan.spellData.Mangle.basename)
            return
        end

        -- Check for valid unit
        local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.Mangle.id)
        if not isValidUnit then
            wan.UpdateAbilityData(wan.spellData.Mangle.basename)
            return
        end

        -- Base values
        local critChanceMod = 0
        local critDamageMod = 0
        local cMangleDmg = nMangleDmg 

        -- Primal Fury
        if wan.traitData.PrimalFury.known then
            critDamageMod = critDamageMod + nPrimalFury
        end

        -- Mangle
        if wan.traitData.Mangle.known and wan.CheckForAnyDebuff(wan.auraData, checkDebuffs, wan.TargetUnitID) then
            local cMangle = nMangleDmg * nMangle
            cMangleDmg = cMangleDmg + cMangle
        end

        -- Remove physical layer
        local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction(wan.classificationData)
        cMangleDmg = cMangleDmg * checkPhysicalDR

        -- Incarnation: Guardian of Ursoc
        if wan.auraData.player.buff_IncarnationGuardianofUrsoc and countValidUnit > 1 then
            local nIncarnationUnits = countValidUnit - 1
            local nIncarnationUnitCap = math.min(nIncarnationUnits, nIncarnationAoeCap)
            local cIncarnation = nMangleDmg * nIncarnationUnitCap

            if wan.traitData.Mangle.known then
                local debuffed = (wan.CheckForAnyDebuff(wan.auraData, checkDebuffs, wan.TargetUnitID) and 1) or 0
                local countDebuffed = wan.CheckForAnyDebuffAoE(wan.auraData, checkDebuffs, idValidUnit) - debuffed
                local nIncarnationMangleCap = math.min(countDebuffed, nIncarnationAoeCap)
                local nIncarnationMangle = nMangleDmg * nIncarnationMangleCap * nMangle
                cIncarnation = cIncarnation + nIncarnationMangle
            end

             -- Remove physical layer
            local checkPhysicalDRAoE = wan.CheckUnitPhysicalDamageReductionAoE(wan.classificationData, wan.spellData.Mangle.id)
            cIncarnation = cIncarnation * checkPhysicalDRAoE
            cMangleDmg = cMangleDmg + cIncarnation
        end

        -- Strike for the Heart
        if wan.traitData.StrikefortheHeart.known then
            critChanceMod = critChanceMod + nStrikeForTheHeart
            critDamageMod = critDamageMod + nStrikeForTheHeart
        end

        -- Crit layer
        cMangleDmg = cMangleDmg * wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

        -- Update ability data
        local abilityValue = math.floor(cMangleDmg)
        wan.UpdateAbilityData(wan.spellData.Mangle.basename, abilityValue, wan.spellData.Mangle.icon, wan.spellData.Mangle.name)
    end


    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            nMangleDmg = wan.GetSpellDescriptionNumbers(wan.spellData.Mangle.id, { 1 })
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.Mangle.known and wan.spellData.Mangle.id
            wan.BlizzardEventHandler(frameMangle, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
            wan.SetUpdateRate(frameMangle, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then
            nPrimalFury = wan.GetTraitDescriptionNumbers(wan.traitData.PrimalFury.entryid, { 1 }) / 100
            nMangle = wan.GetTraitDescriptionNumbers(wan.traitData.Mangle.entryid, { 1 }) / 100
            nIncarnationAoeCap = wan.GetTraitDescriptionNumbers(wan.traitData.IncarnationGuardianofUrsoc.entryid, { 1 })
            nStrikeForTheHeart = wan.GetTraitDescriptionNumbers(wan.traitData.StrikefortheHeart.entryid, { 1 })
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameMangle, CheckAbilityValue, abilityActive)
        end
    end)
end

frameMangle:RegisterEvent("ADDON_LOADED")
frameMangle:SetScript("OnEvent", OnEvent)