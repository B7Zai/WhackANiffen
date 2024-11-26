local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameMaul = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init spell data
    local abilityActive = false
    local nMaulDmg, nMaulDmgAoE = 0, 0

    -- Init trait data
    local nVulnerableFlesh = 0
    local nUrsocsFury = 0
    local nDreadfulWoundDmg, nDreadfulWoundHeal, nDreadfulWoundDR = 0, 0, 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or not wan.auraData.player.buff_BearForm
            or not wan.IsSpellUsable(wan.spellData.Maul.id)
        then
            wan.UpdateAbilityData(wan.spellData.Maul.basename)
            wan.UpdateMechanicData(wan.spellData.Maul.basename)
            return
        end

        -- Check for valid unit
        local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.Maul.id)
        if not isValidUnit then
            wan.UpdateAbilityData(wan.spellData.Maul.basename)
            wan.UpdateMechanicData(wan.spellData.Maul.basename)
            return
        end

        -- Base values
        local critChanceMod = 0
        local critDamageMod = 0
        local cMaulDmg = nMaulDmg
        local cMaulHeal = 0

        -- Vulnerable Flesh
        if wan.traitData.VulnerableFlesh.known then
            critChanceMod = critDamageMod + nVulnerableFlesh
        end

        -- Remove physical layer
        local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction(wan.classificationData)
        cMaulDmg = cMaulDmg * checkPhysicalDR

        --Ravage AoE
        if wan.traitData.Ravage.known and wan.auraData.player.buff_Ravage and countValidUnit > 1 then
            local checkPhysicalDRAoE = wan.CheckUnitPhysicalDamageReductionAoE(wan.classificationData, wan.spellData.Maul.id)
            local ravageUnitAoE = countValidUnit - 1
            local cleaveRavageDmg = nMaulDmgAoE * ravageUnitAoE * checkPhysicalDRAoE

            cMaulDmg = cMaulDmg + cleaveRavageDmg
        end

        -- Dreadful Wound
        if wan.traitData.DreadfulWound.known and wan.auraData.player.buff_Ravage then
            local cDreadfulWoundDmg = nDreadfulWoundDmg * countValidUnit
            local cDreadfulWoundHeal = nDreadfulWoundHeal * countValidUnit
            cMaulDmg = cMaulDmg + cDreadfulWoundDmg
            cMaulHeal = cMaulHeal + cDreadfulWoundHeal
        end

        -- Crit layer
        cMaulDmg = cMaulDmg * wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

        -- Ursoc's Fury
        if wan.traitData.UrsocsFury.known then
            local cUrsocsFury = cMaulDmg * nUrsocsFury
            cMaulHeal = cMaulHeal + cUrsocsFury
        end

        -- Threat situation
        local isTanking = wan.IsTanking()

        -- Update ability data
        local damageValue = not isTanking and math.floor(cMaulDmg) or 0 -- Update Ability Data
        local healValue = isTanking and math.floor(cMaulHeal) or 0 -- Update Mechanic Data

        wan.UpdateMechanicData(wan.spellData.Maul.basename, healValue, wan.spellData.Maul.icon, wan.spellData.Maul.name)
        wan.UpdateAbilityData(wan.spellData.Maul.basename, damageValue, wan.spellData.Maul.icon, wan.spellData.Maul.name)
    end


    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nMaulValues = wan.GetSpellDescriptionNumbers(wan.spellData.Maul.id, { 1, 2 })
            nMaulDmg = nMaulValues[1]
            nMaulDmgAoE = nMaulValues[2]

            local nDreadfulWoundValues = wan.GetTraitDescriptionNumbers(wan.traitData.DreadfulWound.entryid, { 1, 3 })
            nDreadfulWoundDmg = nDreadfulWoundValues[1]
            nDreadfulWoundDR = nDreadfulWoundValues[2]
            nDreadfulWoundHeal = wan.AbilityPercentageToValue(nDreadfulWoundDR)
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.Maul.known and wan.spellData.Maul.id
            wan.BlizzardEventHandler(frameMaul, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameMaul, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then
            nVulnerableFlesh = wan.GetTraitDescriptionNumbers(wan.traitData.VulnerableFlesh.entryid, { 1 }, wan.traitData.VulnerableFlesh.rank)
            nUrsocsFury = wan.GetTraitDescriptionNumbers(wan.traitData.UrsocsFury.entryid, { 1 }) / 100
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameMaul, CheckAbilityValue, abilityActive)
        end
    end)
end

frameMaul:RegisterEvent("ADDON_LOADED")
frameMaul:SetScript("OnEvent", AddonLoad)