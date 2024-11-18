local _, wan = ...

local frameShred = CreateFrame("Frame")
local function OnEvent(self, event, addonName)
    -- Early Exits
    if addonName ~= "WhackANiffen" or wan.PlayerState.Class ~= "DRUID" then return end

    -- Init spell data
    local abilityActive = false
    local checkDebuffs = {"Rake", "Thrash", "Rip", "Feral Frenzy", "Tear", "Frenzied Assault"}
    local nShredDmg, nPouncingStrikes, nMercilessClaws, nThrashingClaws, nThrashDotDmg = 0, 0, 0, 0, 0

    -- Ability value calculation
    local function CheckAbilityValue()
        if not wan.PlayerState.Status or not wan.auraData.player.buff_CatForm
        or not wan.IsSpellUsable(wan.spellData.Shred.id) 
        then wan.UpdateAbilityData(wan.spellData.Shred.basename) return end -- Early exits

        local isValidUnit = wan.ValidUnitBoolCounter(wan.spellData.Shred.id)
        if not isValidUnit then wan.UpdateAbilityData(wan.spellData.Shred.basename) return end -- Check for valid unit

        local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction(wan.classificationData)
        local cShredDmg = nShredDmg * checkPhysicalDR -- Base values

        local critChanceMod = 0
        if wan.auraData.player.buff_SuddenAmbush or
            (wan.traitData.PouncingStrikes.known and wan.auraData.player.buff_Prowl) then -- Pouncing Strikes
            critChanceMod = wan.CritChance
            local cPouncingStrikes = nShredDmg * nPouncingStrikes * checkPhysicalDR
            cShredDmg = cShredDmg + cPouncingStrikes
        end
        
        if wan.traitData.MercilessClaws.known
        and wan.CheckForAnyDebuff(wan.auraData, checkDebuffs, wan.TargetUnitID)
        then -- Merciless Claws
            local cMercilessClaws = nShredDmg * nMercilessClaws
            cShredDmg = cShredDmg + cMercilessClaws
        end

        if wan.traitData.ThrashingClaws.known then --Thrashing Claws
            local bThrashingDebuffs = wan.CheckForAnyDebuff(wan.auraData, checkDebuffs, wan.TargetUnitID)
            local bThrashDebuff = wan.CheckForDebuff(wan.auraData, wan.spellData.Thrash.name, wan.TargetUnitID)
            local dotPotency = wan.CheckDotPotency(cShredDmg)
            local cThrashingClaws = 0

            if bThrashingDebuffs then
                cThrashingClaws = nShredDmg * nThrashingClaws
            end

            if not bThrashDebuff then
                cThrashingClaws = cThrashingClaws + (nThrashDotDmg * dotPotency)
            end
            cShredDmg = cShredDmg + cThrashingClaws
        end

        cShredDmg = cShredDmg * wan.ValueFromCritical(wan.CritChance, critChanceMod) -- Crit Mod

        local abilityValue = math.floor(cShredDmg) -- Update AbilityData
        if abilityValue == 0 then wan.UpdateAbilityData(wan.spellData.Shred.basename) return end
        wan.UpdateAbilityData(wan.spellData.Shred.basename, abilityValue, wan.spellData.Shred.icon, wan.spellData.Shred.name)
    end


    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            nShredDmg = wan.GetSpellDescriptionNumbers(wan.spellData.Shred.id, { 1 })
            nThrashDotDmg = wan.GetSpellDescriptionNumbers(wan.spellData.Thrash.id, { 2 })
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.Shred.known and wan.spellData.Shred.id
            wan.BlizzardEventHandler(frameShred, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
            wan.SetUpdateRate(frameShred, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then
            nPouncingStrikes = wan.GetSpellDescriptionNumbers(wan.traitData.PouncingStrikes.id, { 3 }) / 100
            nMercilessClaws = wan.GetSpellDescriptionNumbers(wan.traitData.MercilessClaws.id, { 1 }) / 100
            nThrashingClaws = wan.GetSpellDescriptionNumbers(wan.traitData.ThrashingClaws.id, { 1 }) / 100
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameShred, CheckAbilityValue, abilityActive)
        end
    end)
end

frameShred:RegisterEvent("ADDON_LOADED")
frameShred:SetScript("OnEvent", OnEvent)