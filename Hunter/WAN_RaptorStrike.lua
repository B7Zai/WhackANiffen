local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local abilityActive = false
local nRaptorStrikeDmg = 0

-- Init trait datat
local nVipersVenomInstantDmg, nVipersVenomDotDmg = 0, 0
local nContagiousReagentsUnitCap = 0
local nHowlOfThePack = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.RaptorStrike.id)
    then
        wan.UpdateAbilityData(wan.spellData.RaptorStrike.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.RaptorStrike.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.RaptorStrike.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critDamageModBase = 0

    local cRaptorStrikeInstantDmg = nRaptorStrikeDmg
    local cRaptorStrikeDotDmg = 0
    local cRaptorStrikeInstantDmgAoE = 0
    local cRaptorStrikeDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cVipersVenomInstantDmg = 0
    local cVipersVenomDotDmg = 0
    if wan.traitData.VipersVenom.known then
        local checkSerpentstalkersTrickeryDebuff = wan.auraData[targetUnitToken] and wan.auraData[targetUnitToken].debuff_SerpentSting
        cVipersVenomInstantDmg = cVipersVenomInstantDmg + nVipersVenomInstantDmg

        if not checkSerpentstalkersTrickeryDebuff then
            cVipersVenomDotDmg = cVipersVenomDotDmg + nVipersVenomDotDmg
        end
    end

    local cContagiousReagentsInstantDmgAoE = 0
    local cContagiousReagentsDotDmgAoE = 0
    if wan.traitData.ContagiousReagents.known then
        local cContagiousReagentsUnitCap = math.min(countValidUnit, nContagiousReagentsUnitCap)
        local checkContagiousReagentsDebuff = wan.auraData[targetUnitToken] and wan.auraData[targetUnitToken].debuff_SerpentSting
        local countContagiousReagents = 0

        if checkContagiousReagentsDebuff then
            cContagiousReagentsInstantDmgAoE = cContagiousReagentsInstantDmgAoE + (nVipersVenomInstantDmg * cContagiousReagentsUnitCap)

            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID and not wan.auraData[nameplateUnitToken].debuff_SerpentSting then

                    cContagiousReagentsDotDmgAoE = cContagiousReagentsDotDmgAoE + nVipersVenomDotDmg

                    countContagiousReagents = countContagiousReagents + 1

                    if countContagiousReagents >= nContagiousReagentsUnitCap then break end
                end
            end
        end
    end

    ---- PACK LEADER TRAITS ----

    if wan.traitData.HowlofthePack.known then
        local checkHowlOfThePackBuff = wan.auraData.player["buff_" .. wan.traitData.HowlofthePack.traitkey]
        if checkHowlOfThePackBuff then
            local stacksHowlOfThePack = checkHowlOfThePackBuff.applications
            critDamageMod = critDamageMod + (nHowlOfThePack * stacksHowlOfThePack)
        end
    end

    local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction()
    local cRaptorStrikeCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cRaptorStrikeInstantDmg = (cRaptorStrikeInstantDmg * checkPhysicalDR * cRaptorStrikeCritValue) + (cVipersVenomInstantDmg * cRaptorStrikeCritValue)
    cRaptorStrikeDotDmg = (cRaptorStrikeDotDmg * cRaptorStrikeCritValue) + (cVipersVenomDotDmg * cRaptorStrikeCritValue)
    cRaptorStrikeInstantDmgAoE = cRaptorStrikeInstantDmgAoE + (cContagiousReagentsInstantDmgAoE * cRaptorStrikeCritValue)
    cRaptorStrikeDotDmgAoE = cRaptorStrikeDotDmgAoE + (cContagiousReagentsDotDmgAoE * cRaptorStrikeCritValue)

    local cRaptorStrikeDmg = cRaptorStrikeInstantDmg + cRaptorStrikeDotDmg + cRaptorStrikeInstantDmgAoE + cRaptorStrikeDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cRaptorStrikeDmg)
    wan.UpdateAbilityData(wan.spellData.RaptorStrike.basename, abilityValue, wan.spellData.RaptorStrike.icon, wan.spellData.RaptorStrike.name)
end

-- Init frame 
local frameRaptorStrike = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nRaptorStrikeDmg = wan.GetSpellDescriptionNumbers(wan.spellData.RaptorStrike.id, { 1 })

            local nVipersVenomValues = wan.GetTraitDescriptionNumbers(wan.traitData.VipersVenom.entryid, { 3, 4 })
            nVipersVenomInstantDmg = nVipersVenomValues[1]
            nVipersVenomDotDmg = nVipersVenomValues[2]
        end
    end)
end
frameRaptorStrike:RegisterEvent("ADDON_LOADED")
frameRaptorStrike:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.RaptorStrike.known and wan.spellData.RaptorStrike.id
        wan.BlizzardEventHandler(frameRaptorStrike, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameRaptorStrike, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nContagiousReagentsUnitCap = wan.GetTraitDescriptionNumbers(wan.traitData.ContagiousReagents.entryid, { 1 })

        nHowlOfThePack = wan.GetTraitDescriptionNumbers(wan.traitData.HowlofthePack.entryid, { 1 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameRaptorStrike, CheckAbilityValue, abilityActive)
    end
end)