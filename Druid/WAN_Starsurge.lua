local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameStarsurge = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init spell data
    local abilityActive = false
    local nStarsurgeDmg = 0
    local nMasteryAstralInvocationArcane = 0
    local nMasteryAstralInvocationNature = 0
    local nMasteryAstralInvocationAstral = 0

    -- Init trait data
    local nAstronomicalImpact = 0
    local nPowerOfGoldrinn, nPowerOfGoldrinnProcChance = 0, 0.33

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or wan.auraData.player.buff_CatForm or wan.auraData.player.buff_BearForm
            or (wan.spellData.Starfall.known and not wan.IsSpellUsable(wan.spellData.Starfall.id) or not wan.IsSpellUsable(wan.spellData.Starsurge.id))
        then
            wan.UpdateAbilityData(wan.spellData.Starsurge.basename)
            return
        end

        -- Check for valid unit
        local isValidUnit  = wan.ValidUnitBoolCounter(wan.spellData.Starsurge.id)
        if not isValidUnit then
            wan.UpdateAbilityData(wan.spellData.Starsurge.basename)
            return
        end

        -- Base values
        local critChanceMod = 0
        local critDamageMod = 0

        -- check mastery layer
        local cMasteryAstralInvocationAstral = 1
        if wan.spellData.MasteryAstralInvocation.known then
            local cMasteryAstralInvocationNatureValue = wan.auraData[wan.TargetUnitID]["debuff_" .. wan.spellData.Sunfire.basename] and nMasteryAstralInvocationNature or 0
            local cMasteryAstralInvocationArcaneValue = wan.auraData[wan.TargetUnitID]["debuff_" .. wan.spellData.Moonfire.basename] and nMasteryAstralInvocationArcane or 0
            local cMasteryAstralInvocationAstralValue = cMasteryAstralInvocationNatureValue + cMasteryAstralInvocationArcaneValue
            cMasteryAstralInvocationAstral = 1 + cMasteryAstralInvocationAstralValue
        end
        
        local cStarsurgeDmg = nStarsurgeDmg

        -- Astronomical Impact
        if wan.traitData.AstronomicalImpact.known then
            critDamageMod = critDamageMod + nAstronomicalImpact
        end

        -- Power of Goldrinn
        if wan.traitData.PowerofGoldrinn.known then
            local cPowerOfGoldrinn = nPowerOfGoldrinn * nPowerOfGoldrinnProcChance
            cStarsurgeDmg = cStarsurgeDmg + cPowerOfGoldrinn
        end

        cStarsurgeDmg = cStarsurgeDmg * cMasteryAstralInvocationAstral

        -- Crit layer
        cStarsurgeDmg = cStarsurgeDmg * wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

        -- Update ability data
        local abilityValue = math.floor(cStarsurgeDmg)
        
        wan.UpdateAbilityData(wan.spellData.Starsurge.basename, abilityValue, wan.spellData.Starsurge.icon, wan.spellData.Starsurge.name)
    end


    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED"then
            nStarsurgeDmg = wan.GetSpellDescriptionNumbers(wan.spellData.Starsurge.id, { 1 })

            nPowerOfGoldrinn = wan.GetTraitDescriptionNumbers(wan.traitData.PowerofGoldrinn.entryid, { 1 })

            local nMasteryAstralInvocationValues = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryAstralInvocation.id, { 2, 4 })
            nMasteryAstralInvocationArcane = nMasteryAstralInvocationValues[1] * 0.01
            nMasteryAstralInvocationNature = nMasteryAstralInvocationValues[2] * 0.01
        end
    end)

    -- Set update rate based on settings & data update on traits
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.Starsurge.known and wan.spellData.Starsurge.id
            wan.BlizzardEventHandler(frameStarsurge, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameStarsurge, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then
            nAstronomicalImpact = wan.GetTraitDescriptionNumbers(wan.traitData.AstronomicalImpact.entryid, { 1 })
         end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameStarsurge, CheckAbilityValue, abilityActive)
        end
    end)
end

frameStarsurge:RegisterEvent("ADDON_LOADED")
frameStarsurge:SetScript("OnEvent", AddonLoad)