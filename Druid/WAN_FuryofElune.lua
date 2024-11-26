local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameFuryOfElune = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init data
    local abilityActive = false
    local nFuryOfEluneDmg = 0

    -- Init trait data
    local nAstronomicalImpact = 0

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
        local cFuryOfEluneDmg = nFuryOfEluneDmg

        -- AoE values
        if countValidUnit > 1 then
            local furyOFEluneUnitAoE = countValidUnit - 1
            local softCappedValidUnit = math.sqrt(1 / countValidUnit)
            local cFuryOfEluneAoEDmg = (nFuryOfEluneDmg * softCappedValidUnit) * furyOFEluneUnitAoE
            cFuryOfEluneDmg = cFuryOfEluneDmg + cFuryOfEluneAoEDmg
        end

        -- Astronomical Impact
        if wan.traitData.AstronomicalImpact.known then
            critDamageMod = critDamageMod + nAstronomicalImpact
        end

        -- Crit layer
        cFuryOfEluneDmg = cFuryOfEluneDmg * wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

        -- Update ability data
        local cdPotency = wan.CheckOffensiveCooldownPotency(cFuryOfEluneDmg, isValidUnit, idValidUnit)
        local abilityValue = cdPotency and math.floor(cFuryOfEluneDmg) or 0
        wan.UpdateAbilityData(wan.spellData.FuryofElune.basename, abilityValue, wan.spellData.FuryofElune.icon, wan.spellData.FuryofElune.name)
    end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nFuryOfEluneDmg = wan.GetSpellDescriptionNumbers(wan.spellData.FuryofElune.id, { 1 })
        end
    end)

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
end

frameFuryOfElune:RegisterEvent("ADDON_LOADED")
frameFuryOfElune:SetScript("OnEvent", AddonLoad)