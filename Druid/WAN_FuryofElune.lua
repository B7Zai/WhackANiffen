local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nFuryOfEluneDmg = 0
local nMasteryAstralInvocationArcane = 0
local nMasteryAstralInvocationNature = 0
local nMasteryAstralInvocationAstral = 0

-- Init trait data
local nAstronomicalImpact = 0
local nBoundlessMoonlight = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or wan.auraData.player.buff_CatForm
        or wan.auraData.player.buff_BearForm or not wan.IsSpellUsable(wan.spellData.FuryofElune.id)
    then
        wan.UpdateAbilityData(wan.spellData.FuryofElune.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.FuryofElune.id)
    if countValidUnit == 0 then
        wan.UpdateAbilityData(wan.spellData.FuryofElune.basename)
        return
    end

    -- Base value
    local critChanceMod = 0
    local critDamageMod = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cMasteryAstralInvocationAstral = 1
    if wan.spellData.MasteryAstralInvocation.known then
        local cMasteryAstralInvocationNatureValue = wan.auraData[targetUnitToken] and wan.auraData[targetUnitToken]["debuff_" .. wan.spellData.Sunfire.basename] and nMasteryAstralInvocationNature or 0
        local cMasteryAstralInvocationArcaneValue = wan.auraData[targetUnitToken] and wan.auraData[targetUnitToken]["debuff_" .. wan.spellData.Moonfire.basename] and nMasteryAstralInvocationArcane or 0
        local cMasteryAstralInvocationAstralValue = cMasteryAstralInvocationNatureValue + cMasteryAstralInvocationArcaneValue
        cMasteryAstralInvocationAstral = 1 + cMasteryAstralInvocationAstralValue
    end

    local cFuryOfEluneInstantDmg = nFuryOfEluneDmg * cMasteryAstralInvocationAstral

    local cBoundlessMoonlight = 0
    if wan.traitData.BoundlessMoonlight.known then
        cBoundlessMoonlight = cBoundlessMoonlight + (nBoundlessMoonlight * cMasteryAstralInvocationAstral)
    end

    -- AoE values
    local cFuryOfEluneInstantDmgAoE = 0
    if countValidUnit > 1 then
        local cFuryOfEluneUnitOverflow = wan.SoftCapOverflow(1, countValidUnit)

        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do
            if nameplateGUID ~= wan.UnitState.GUID[wan.TargetUnitID] then
                local cMasteryAstralInvocationUnitAstral = 1
                if wan.spellData.MasteryAstralInvocation.known then
                    local cMasteryAstralInvocationUnitNatureValue = wan.auraData[nameplateUnitToken]["debuff_" .. wan.spellData.Sunfire.basename] and nMasteryAstralInvocationNature or 0
                    local cMasteryAstralInvocationUnitArcaneValue = wan.auraData[nameplateUnitToken]["debuff_" .. wan.spellData.Moonfire.basename] and nMasteryAstralInvocationArcane or 0
                    local cMasteryAstralInvocationUnitAstralValue = cMasteryAstralInvocationUnitNatureValue + cMasteryAstralInvocationUnitArcaneValue
                    cMasteryAstralInvocationUnitAstral = 1 + cMasteryAstralInvocationUnitAstralValue
                end

                local unitFuryOfEluneDmg = nFuryOfEluneDmg * cFuryOfEluneUnitOverflow * cMasteryAstralInvocationUnitAstral

                local cUnitBoundlessMoonlight = 0
                if wan.traitData.BoundlessMoonlight.known then
                    cUnitBoundlessMoonlight = cUnitBoundlessMoonlight + (nBoundlessMoonlight * cMasteryAstralInvocationUnitAstral)
                end

                cFuryOfEluneInstantDmgAoE = cFuryOfEluneInstantDmgAoE + unitFuryOfEluneDmg + cUnitBoundlessMoonlight
            end
        end
    end

    -- Astronomical Impact
    if wan.traitData.AstronomicalImpact.known then
        critDamageMod = critDamageMod + nAstronomicalImpact
    end

    -- Crit layer
    local cFuryofEluneCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cFuryOfEluneInstantDmg = (cFuryOfEluneInstantDmg + cBoundlessMoonlight) * cFuryofEluneCritValue
    cFuryOfEluneInstantDmgAoE = cFuryOfEluneInstantDmgAoE * cFuryofEluneCritValue

    local cFuryOfEluneDmg = cFuryOfEluneInstantDmg + cFuryOfEluneInstantDmgAoE

    -- Update ability data
    local cdPotency = wan.CheckOffensiveCooldownPotency(cFuryOfEluneDmg, isValidUnit, idValidUnit)
    local abilityValue = cdPotency and math.floor(cFuryOfEluneDmg) or 0
    wan.UpdateAbilityData(wan.spellData.FuryofElune.basename, abilityValue, wan.spellData.FuryofElune.icon, wan.spellData.FuryofElune.name)
end

-- Init frame 
local frameFuryOfElune = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nFuryOfEluneDmg = wan.GetSpellDescriptionNumbers(wan.spellData.FuryofElune.id, { 1 })

            local nMasteryAstralInvocationValues = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryAstralInvocation.id, { 2, 4 })
            nMasteryAstralInvocationArcane = nMasteryAstralInvocationValues[1] * 0.01
            nMasteryAstralInvocationNature = nMasteryAstralInvocationValues[2] * 0.01

            nBoundlessMoonlight = wan.GetTraitDescriptionNumbers(wan.traitData.BoundlessMoonlight.entryid, { 3 })
        end
    end)
end
frameFuryOfElune:RegisterEvent("ADDON_LOADED")
frameFuryOfElune:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.FuryofElune.known and wan.spellData.FuryofElune.id
        wan.BlizzardEventHandler(frameFuryOfElune, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameFuryOfElune, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nAstronomicalImpact = wan.GetTraitDescriptionNumbers(wan.traitData.AstronomicalImpact.entryid, { 1 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameFuryOfElune, CheckAbilityValue, abilityActive)
    end
end)