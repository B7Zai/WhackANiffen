local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local abilityActive = false
local nMultiShotDmg, nMultiShotSoftCap = 0, 0
local nMultiShotSpellCost = 0

-- Init trait data
local nPenetratingShots = 0
local nExplosiveVenomInstantDmg, nExplosiveVenomDotDmg, nExplosiveVenomStacks = 0, 0, 0
local nSalvoUnitCap = 0
local nExplosiveShotDmg, nExplosiveShotSoftCap = 0, 0
local nSymphonicArsenal, nSymphonicArsenalUnitCap = 0, 0
local nHowlOfThePack = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.MultiShot.id)
    then
        wan.UpdateAbilityData(wan.spellData.MultiShot.basename)
        return
    end

    local currentFocus = UnitPower("player", 2) or 0
    if currentFocus < nMultiShotSpellCost
    then
        wan.UpdateAbilityData(wan.spellData.MultiShot.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit ,idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.MultiShot.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.MultiShot.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0

    local cMultiShotInstantDmg = 0
    local cMultiShotDotDmg = 0
    local cMultiShotInstantAoEDmg = 0
    local cMultiShotDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cMultiShotUnitOverflow = wan.SoftCapOverflow(nMultiShotSoftCap, countValidUnit)
    for nameplateUnitToken, _ in pairs(idValidUnit) do
        local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

        cMultiShotInstantAoEDmg = cMultiShotInstantAoEDmg + (nMultiShotDmg * checkPhysicalDR * cMultiShotUnitOverflow)
    end

    ---- BEAST MASTERY TRAITS ----

    local cExplosiveVenomInstantDmgAoE = 0
    local cExplosiveVenomDotDmgAoE = 0
    if wan.traitData.ExplosiveVenom.known then
        local checkExplosiveVenomBuff = wan.auraData.player["buff_" .. wan.traitData.ExplosiveVenom.traitkey]

        if checkExplosiveVenomBuff and checkExplosiveVenomBuff.applications == (nExplosiveVenomStacks - 1) then

            for nameplateUnitToken, _ in pairs(idValidUnit) do
                local checkUnitExplosiveVenomBuff = wan.auraData[nameplateUnitToken].debuff_SerpentSting
                cExplosiveVenomInstantDmgAoE = cExplosiveVenomInstantDmgAoE + nExplosiveVenomInstantDmg

                if not checkUnitExplosiveVenomBuff then
                    local dotPotency = wan.CheckDotPotency(nExplosiveVenomInstantDmg, nameplateUnitToken)
                    cExplosiveVenomDotDmgAoE = cExplosiveVenomDotDmgAoE + (nExplosiveVenomDotDmg * dotPotency)
                end

            end
        end
    end

    ---- MARKSMAN TRAITS ----
    
    if wan.traitData.PenetratingShots.known then
        critDamageMod = critDamageMod + (wan.CritChance * nPenetratingShots)
    end

    local cSalvoInstantDmgAoE = 0
    if wan.traitData.Salvo.known and wan.auraData.player["buff_" .. wan.traitData.Salvo.traitkey] then
        local cExplosiveShotUnitOverflow = wan.AdjustSoftCapUnitOverflow(nExplosiveShotSoftCap, countValidUnit)
        local cSalvoUnitCap = math.min(nSalvoUnitCap, countValidUnit)

        cSalvoInstantDmgAoE = cSalvoInstantDmgAoE + (nExplosiveShotDmg * cExplosiveShotUnitOverflow * cSalvoUnitCap)
    end

    ---- PACK LEADER TRAITS----

    if wan.traitData.HowlofthePack.known then
        local checkHowlOfThePackBuff = wan.auraData.player["buff_" .. wan.traitData.HowlofthePack.traitkey]
        if checkHowlOfThePackBuff then
            local stacksHowlOfThePack = checkHowlOfThePackBuff.applications
            critDamageMod = critDamageMod + (nHowlOfThePack * stacksHowlOfThePack)
        end
    end

    ---- SENTINEL TRAITS ----
    
    local cSymphonicArsenalInstantDmgAoE = 0
    if wan.traitData.SymphonicArsenal.known then
        local cSymphonicArsenalUnitCap = math.min(countValidUnit, nSymphonicArsenalUnitCap)
        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkSentinelDebuff = wan.auraData[nameplateUnitToken]["debuff_" .. wan.traitData.Sentinel.traitkey]
            if checkSentinelDebuff then
                cSymphonicArsenalInstantDmgAoE = cSymphonicArsenalInstantDmgAoE + (nSymphonicArsenal * cSymphonicArsenalUnitCap)
            end
        end
    end

    local cMultiShotCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cMultiShotInstantDmg = cMultiShotInstantDmg
    cMultiShotDotDmg = cMultiShotDotDmg
    cMultiShotInstantAoEDmg = (cMultiShotInstantAoEDmg + cExplosiveVenomInstantDmgAoE + cSymphonicArsenalInstantDmgAoE + cSalvoInstantDmgAoE) * cMultiShotCritValue
    cMultiShotDotDmgAoE = cMultiShotDotDmgAoE + (cExplosiveVenomDotDmgAoE * cMultiShotCritValue)

    local cMultiShotDmg = cMultiShotInstantDmg + cMultiShotDotDmg + cMultiShotInstantAoEDmg + cMultiShotDotDmgAoE

    if (wan.traitData.BeastCleave.known or wan.traitData.TrickShots.known) and countValidUnit > 2 then
        local currentTime = GetTime()
        local checkEnablerBuff = wan.auraData.player.buff_BeastCleave or wan.auraData.player.buff_TrickShots
        local addonUpdateRate = (wan.Options.UpdateRate.Toggle and wan.Options.UpdateRate.Slider * 0.01) or 0.4
        local expirationTime = (checkEnablerBuff and checkEnablerBuff.expirationTime - currentTime) or math.huge
        if not checkEnablerBuff or expirationTime < addonUpdateRate then
            cMultiShotDmg = cMultiShotDmg * countValidUnit
        end
    end

    local abilityValue = math.floor(cMultiShotDmg)
    wan.UpdateAbilityData(wan.spellData.MultiShot.basename, abilityValue, wan.spellData.MultiShot.icon, wan.spellData.MultiShot.name)
end

-- Init frame 
local frameMultiShot = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nMultiShotValues = wan.GetSpellDescriptionNumbers(wan.spellData.MultiShot.id, { 2, 3 })
            nMultiShotDmg = nMultiShotValues[1]
            nMultiShotSoftCap = nMultiShotValues[2]

            nMultiShotSpellCost = (wan.traitData.AimedShot.known and wan.GetSpellCost(wan.spellData.AimedShot.id, 2))
            or wan.GetSpellCost(wan.spellData.MultiShot.id, 2)

            local nExplosiveVenomValues = wan.GetTraitDescriptionNumbers(wan.traitData.VenomsBite.entryid, { 4, 5 })
            nExplosiveVenomInstantDmg = nExplosiveVenomValues[1]
            nExplosiveVenomDotDmg = nExplosiveVenomValues[2]

            local nExplosiveShotValues = wan.GetSpellDescriptionNumbers(wan.spellData.ExplosiveShot.id, { 2, 4 })
            nExplosiveShotDmg = nExplosiveShotValues[1]
            nExplosiveShotSoftCap = nExplosiveShotValues[2]

            local nSymphonicArsenalValues = wan.GetTraitDescriptionNumbers(wan.traitData.SymphonicArsenal.entryid, { 1, 2 })
            nSymphonicArsenal = nSymphonicArsenalValues[1]
            nSymphonicArsenalUnitCap = nSymphonicArsenalValues[2]
        end
    end)
end
frameMultiShot:RegisterEvent("ADDON_LOADED")
frameMultiShot:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.MultiShot.known and wan.spellData.MultiShot.id
        wan.BlizzardEventHandler(frameMultiShot, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameMultiShot, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nPenetratingShots = wan.GetTraitDescriptionNumbers(wan.traitData.PenetratingShots.entryid, { 1 }) * 0.01

        nExplosiveVenomStacks = wan.GetTraitDescriptionNumbers(wan.traitData.ExplosiveVenom.entryid, { 1 })

        nSalvoUnitCap = wan.GetTraitDescriptionNumbers(wan.traitData.Salvo.entryid, { 1 })

        nHowlOfThePack = wan.GetTraitDescriptionNumbers(wan.traitData.HowlofthePack.entryid, { 1 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameMultiShot, CheckAbilityValue, abilityActive)
    end
end)