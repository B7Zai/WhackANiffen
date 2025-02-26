local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local abilityActive = false
local nArcaneShotDmg, nArcaneShotDmgAoE = 0, 0
local nArcaneShotSpellCost = 0

-- Init trait data
local nPenetratingShots = 0
local nAspectoftheHydra, nAspectoftheHydraUnitCap = 0, 1
local nShrapnelShot = 0
local nUnerringVision = 0
local nHogstriderUnitCap = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status
    or (wan.spellData.MultiShot.known and not wan.IsSpellUsable(wan.spellData.MultiShot.id) or not wan.IsSpellUsable(wan.spellData.ArcaneShot.id))
    then
        wan.UpdateAbilityData(wan.spellData.ArcaneShot.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.ArcaneShot.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.ArcaneShot.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0

    local cArcaneShotInstantDmg = 0
    local cArcaneShotDotDmg = 0
    local cArcaneShotInstantDmgAoE = 0
    local cArcaneShotDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- MARKSMAN TRAITS ----

    local cAspectoftheHydra = 0
    if wan.traitData.AspectoftheHydra.known then
        local countAspectoftheHydraUnit = 0

        for _, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then

                cAspectoftheHydra = cAspectoftheHydra + (nArcaneShotDmg * nAspectoftheHydra)

                countAspectoftheHydraUnit = countAspectoftheHydraUnit + 1

                if countAspectoftheHydraUnit >= nAspectoftheHydraUnitCap then break end
            end
        end
    end

    if wan.traitData.PenetratingShots.known then
        critDamageMod = critDamageMod + (wan.CritChance * nPenetratingShots)
    end

    local cShrapnelShot = 1
    local cShrapnelShotAoE = 1
    if wan.traitData.ShrapnelShot.known then
        local formattedDebuffName = wan.traitData.ShrapnelShot.traitkey
        local checkShrapnelShotDebuff = wan.CheckUnitDebuff(nil, formattedDebuffName)

        if checkShrapnelShotDebuff then
            cShrapnelShot = cShrapnelShot + nShrapnelShot
        end

        if wan.traitData.AspectoftheHydra.known then
            local countAspectoftheHydraUnit = 0

            for _, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkShrapnelShotDebuff = wan.CheckUnitDebuff(nil, formattedDebuffName)

                    if checkShrapnelShotDebuff then
                        cShrapnelShotAoE = cShrapnelShotAoE + nShrapnelShot
                    end

                    countAspectoftheHydraUnit = countAspectoftheHydraUnit + 1

                    if countAspectoftheHydraUnit >= nAspectoftheHydraUnitCap then break end
                end
            end
        end
    end

    if wan.traitData.UnerringVision.known then
        local checkTrueshotBuff = wan.CheckUnitBuff(nil, wan.spellData.Trueshot.formattedName)
        if checkTrueshotBuff then
            critDamageMod = critDamageMod + nUnerringVision
        end
    end

    ---- PACK LEADER TRAITS ----

    local nHogstriderInstantDmgAoE = 0
    if wan.traitData.Hogstrider.known then
        local checkHogstriderBuff = wan.CheckUnitBuff(nil, wan.traitData.Hogstrider.traitkey)
        if checkHogstriderBuff then
            local cHogstriderStacks = checkHogstriderBuff.applications
            local cHogstriderUnitCap = nHogstriderUnitCap * cHogstriderStacks
            local countHogstriderUnit = 0

            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

                    nHogstriderInstantDmgAoE = nHogstriderInstantDmgAoE + (nArcaneShotDmg * checkUnitPhysicalDR)

                    countHogstriderUnit = countHogstriderUnit + 1

                    if countHogstriderUnit >= cHogstriderUnitCap then break end
                end
            end
        end
    end

    local checkPhysicalDR = wan.traitData.CobraShot.known and wan.CheckUnitPhysicalDamageReduction() or 1
    local cArcaneShotCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cArcaneShotInstantDmg = cArcaneShotInstantDmg
        + (nArcaneShotDmg * checkPhysicalDR * cArcaneShotCritValue * cShrapnelShot)

    cArcaneShotDotDmg = cArcaneShotDotDmg

    cArcaneShotInstantDmgAoE = cArcaneShotInstantDmgAoE
        + (cAspectoftheHydra * cArcaneShotCritValue * cShrapnelShotAoE)
        + (nHogstriderInstantDmgAoE * cArcaneShotCritValue)

    cArcaneShotDotDmgAoE = cArcaneShotDotDmgAoE

    if (wan.traitData.BeastCleave.known or wan.traitData.TrickShots.known) and countValidUnit > 2 then
        local currentTime = GetTime()
        local checkEnablerBuff = wan.auraData.player.buff_BeastCleave or wan.auraData.player.buff_TrickShots
        local addonUpdateRate = (wan.Options.UpdateRate.Toggle and wan.Options.UpdateRate.Slider * 0.01) or 0.4
        local expirationTime = (checkEnablerBuff and checkEnablerBuff.expirationTime - currentTime) or math.huge
        if not checkEnablerBuff or expirationTime < addonUpdateRate then
            wan.UpdateAbilityData(wan.spellData.ArcaneShot.basename)
            return
        end
    end

    local cArcaneShotDmg = cArcaneShotInstantDmg + cArcaneShotDotDmg + cArcaneShotInstantDmgAoE + cArcaneShotDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cArcaneShotDmg)
    wan.UpdateAbilityData(wan.spellData.ArcaneShot.basename, abilityValue, wan.spellData.ArcaneShot.icon, wan.spellData.ArcaneShot.name)
end

-- Init frame 
local frameArcaneShot = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nArcaneShotValues = wan.GetSpellDescriptionNumbers(wan.spellData.ArcaneShot.id, { 1, 2 })
            nArcaneShotDmg = nArcaneShotValues[1]
            nArcaneShotDmgAoE = wan.traitData.ChimaeraShot.known and nArcaneShotValues[2] or 0
        end
    end)
end
frameArcaneShot:RegisterEvent("ADDON_LOADED")
frameArcaneShot:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.ArcaneShot.known and wan.spellData.ArcaneShot.id
        wan.BlizzardEventHandler(frameArcaneShot, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameArcaneShot, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nPenetratingShots = wan.GetTraitDescriptionNumbers(wan.traitData.PenetratingShots.entryid, { 1 }) * 0.01

        nHogstriderUnitCap = wan.GetTraitDescriptionNumbers(wan.traitData.Hogstrider.entryid, { 2 })

        nAspectoftheHydra = wan.GetTraitDescriptionNumbers(wan.traitData.AspectoftheHydra.entryid, { 1 }) * 0.01

        nShrapnelShot = wan.GetTraitDescriptionNumbers(wan.traitData.ShrapnelShot.entryid, { 1 }) * 0.01

        nUnerringVision = wan.GetTraitDescriptionNumbers(wan.traitData.UnerringVision.entryid, { 2 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameArcaneShot, CheckAbilityValue, abilityActive)
    end
end)