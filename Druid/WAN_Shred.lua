local _, wan = ...

local frameShred = CreateFrame("Frame")
local function OnEvent(self, event, addonName)
    -- Early Exits
    if addonName ~= "WhackANiffen" or wan.PlayerState.Class ~= "DRUID" then return end

    -- Init spell data
    local abilityActive = false
    local checkDebuffs = {"Rake", "Thrash", "Rip", "Feral Frenzy", "Tear", "Frenzied Assault"}
    local nShredDmg, nThrashDotDmg = 0, 0

    -- Init trait data
    local nPouncingStrikes = 0
    local nMercilessClaws, nThrashingClaws = 0, 0
    local nStrikeForTheHeart = 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or not wan.auraData.player.buff_CatForm
            or not wan.IsSpellUsable(wan.spellData.Shred.id)
        then
            wan.UpdateAbilityData(wan.spellData.Shred.basename)
            return
        end

        -- Check for valid unit
        local isValidUnit = wan.ValidUnitBoolCounter(wan.spellData.Shred.id)
        if not isValidUnit then
            wan.UpdateAbilityData(wan.spellData.Shred.basename)
            return
        end

        -- Base values
        local critChanceMod = 0
        local critDamageMod = 0
        local cShredDmg = nShredDmg

        -- Pouncing Strikes
        if wan.auraData.player.buff_SuddenAmbush or (wan.traitData.PouncingStrikes.known and wan.auraData.player.buff_Prowl) then 
            critChanceMod = critChanceMod + wan.CritChance
            local cPouncingStrikes = nShredDmg * nPouncingStrikes
            cShredDmg = cShredDmg + cPouncingStrikes
        end

        -- Merciless Claws
        if wan.traitData.MercilessClaws.known and wan.CheckForAnyDebuff(wan.auraData, checkDebuffs, wan.TargetUnitID) then
            local cMercilessClaws = nShredDmg * nMercilessClaws
            cShredDmg = cShredDmg + cMercilessClaws
        end

        -- Remove physical layer
        local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction(wan.classificationData)
        cShredDmg = cShredDmg * checkPhysicalDR

        --Thrashing Claws
        if wan.traitData.ThrashingClaws.known then                                    
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

        -- Strike for the Heart
        if wan.traitData.StrikefortheHeart.known then
            critChanceMod = critChanceMod + nStrikeForTheHeart
            critDamageMod = critDamageMod + nStrikeForTheHeart
        end

        -- Crit layer
        cShredDmg = cShredDmg * wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

        -- Update ability data
        local abilityValue = math.floor(cShredDmg)                                                  
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
            nPouncingStrikes = wan.GetTraitDescriptionNumbers(wan.traitData.PouncingStrikes.entryid, { 3 }) / 100
            nMercilessClaws = wan.GetTraitDescriptionNumbers(wan.traitData.MercilessClaws.entryid, { 1 }) / 100
            nThrashingClaws = wan.GetTraitDescriptionNumbers(wan.traitData.ThrashingClaws.entryid, { 1 }) / 100
            nStrikeForTheHeart = wan.GetTraitDescriptionNumbers(wan.traitData.StrikefortheHeart.entryid, { 1 })
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameShred, CheckAbilityValue, abilityActive)
        end
    end)
end

frameShred:RegisterEvent("ADDON_LOADED")
frameShred:SetScript("OnEvent", OnEvent)