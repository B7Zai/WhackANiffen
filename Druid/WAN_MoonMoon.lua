local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init spell data
local playerGUID = wan.PlayerState.GUID
local playerUnitToken = "player"
local abilityActive = false
local nMoonMoonDmg = 0
local nMasteryAstralInvocationArcane = 0
local nMasteryAstralInvocationNature = 0
local nMasteryAstralInvocationAstral = 0

-- Init trait data
local nAstronomicalImpact = 0
local nBoundlessMoonlight, nBoundlessMoonlightCap, nBoundlessMoonlightFullCap = 0, 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status 
        or wan.CheckUnitBuff(nil, wan.spellData.CatForm.formattedName)
        or wan.CheckUnitBuff(nil, wan.spellData.BearForm.formattedName)
        or not wan.IsSpellUsable(wan.spellData.NewMoon.id)
    then
        wan.UpdateAbilityData(wan.spellData.NewMoon.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.NewMoon.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.NewMoon.basename)
        return
    end

    -- Base values
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

    local cMoonMoonInstantDmg = nMoonMoonDmg * cMasteryAstralInvocationAstral

    local cBoundlessMoonlight = 0
    if wan.traitData.BoundlessMoonlight.known then
        local cBoundlessMoonlightCap = wan.spellData.NewMoon.name == "Full Moon" and nBoundlessMoonlightFullCap or nBoundlessMoonlightCap
        cBoundlessMoonlight = cBoundlessMoonlight + (nBoundlessMoonlight * cBoundlessMoonlightCap * cMasteryAstralInvocationAstral)
    end

    -- AoE values
    local cMoonMoonInstantDmgAoE = 0
    if countValidUnit > 1 then
        local cMoonMoonUnitOverflow = wan.SoftCapOverflow(1, countValidUnit)

        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then

                local cMasteryAstralInvocationUnitAstral = 1
                if wan.spellData.MasteryAstralInvocation.known then
                    local cMasteryAstralInvocationUnitNatureValue = wan.auraData[nameplateUnitToken]["debuff_" .. wan.spellData.Sunfire.basename] and nMasteryAstralInvocationNature or 0
                    local cMasteryAstralInvocationUnitArcaneValue = wan.auraData[nameplateUnitToken]["debuff_" .. wan.spellData.Moonfire.basename] and nMasteryAstralInvocationArcane or 0
                    local cMasteryAstralInvocationUnitAstralValue = cMasteryAstralInvocationUnitNatureValue + cMasteryAstralInvocationUnitArcaneValue
                    cMasteryAstralInvocationUnitAstral = 1 + cMasteryAstralInvocationUnitAstralValue
                end

                local cFullMoon = 0
                if wan.spellData.NewMoon.name == "Full Moon" then
                    cFullMoon = cFullMoon + (nMoonMoonDmg * cMoonMoonUnitOverflow * cMasteryAstralInvocationUnitAstral)
                end

                local cUnitBoundlessMoonlight = 0
                if wan.traitData.BoundlessMoonlight.known then
                    local cUnitBoundlessMoonlightCap = wan.spellData.NewMoon.name == "Full Moon" and nBoundlessMoonlightFullCap or nBoundlessMoonlightCap
                    cUnitBoundlessMoonlight = cUnitBoundlessMoonlight + (nBoundlessMoonlight * cMoonMoonUnitOverflow * cUnitBoundlessMoonlightCap * cMasteryAstralInvocationUnitAstral)
                end

                cMoonMoonInstantDmgAoE = cMoonMoonInstantDmgAoE + cFullMoon + cUnitBoundlessMoonlight
            end
        end
    end

    -- Astronomical Impact
    if wan.traitData.AstronomicalImpact.known then
        critDamageMod = critDamageMod + nAstronomicalImpact
    end

    -- Crit layer
    local cMoonMoonCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    -- Cast time layer
    local castEfficiency = wan.CheckCastEfficiency(wan.spellData.NewMoon.id, wan.spellData.NewMoon.castTime)

    cMoonMoonInstantDmg = (cMoonMoonInstantDmg + cBoundlessMoonlight) * cMoonMoonCritValue * castEfficiency
    cMoonMoonInstantDmgAoE = cMoonMoonInstantDmgAoE * cMoonMoonCritValue * castEfficiency

    local cMoonMoonDmg = cMoonMoonInstantDmg + cMoonMoonInstantDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cMoonMoonDmg)
    wan.UpdateAbilityData(wan.spellData.NewMoon.basename, abilityValue, wan.spellData.NewMoon.icon, wan.spellData.NewMoon.name)
end

local frameMoonMoon = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nMoonMoonDmg = wan.GetSpellDescriptionNumbers(wan.spellData.NewMoon.id, { 1 })

            local nMasteryAstralInvocationValues = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryAstralInvocation.id, { 2, 4 })
            nMasteryAstralInvocationArcane = nMasteryAstralInvocationValues[1] * 0.01
            nMasteryAstralInvocationNature = nMasteryAstralInvocationValues[2] * 0.01

            local nBoundlessMoonlightValues = wan.GetTraitDescriptionNumbers(wan.traitData.BoundlessMoonlight.entryid, { 6, 7, 8 })
            nBoundlessMoonlightCap = nBoundlessMoonlightValues[1]
            nBoundlessMoonlightFullCap = nBoundlessMoonlightValues[2]
            nBoundlessMoonlight = nBoundlessMoonlightValues[3]
        end
    end)
end
frameMoonMoon:RegisterEvent("ADDON_LOADED")
frameMoonMoon:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings & data update on traits
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.NewMoon.known and wan.spellData.NewMoon.id
        wan.BlizzardEventHandler(frameMoonMoon, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameMoonMoon, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nAstronomicalImpact = wan.GetTraitDescriptionNumbers(wan.traitData.AstronomicalImpact.entryid, { 1 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameMoonMoon, CheckAbilityValue, abilityActive)
    end
end)
