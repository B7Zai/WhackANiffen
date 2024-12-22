local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame
local frameRake = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init data
    local abilityActive = false
    local nRakeInstantDmg, nRakeDotDmg = 0, 0

    -- Init trait
    local nPouncingStrikes = 0
    local nDoubleClawedRakeAoeCap = 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or not wan.auraData.player.buff_CatForm
            or not wan.IsSpellUsable(wan.spellData.Rake.id)
        then
            wan.UpdateAbilityData(wan.spellData.Rake.basename)
            return
        end

        -- Check for valid unit
        local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, wan.spellData.Swipe.maxRange)
        if not isValidUnit then
            wan.UpdateAbilityData(wan.spellData.Rake.basename)
            return
        end

        -- Base values
        local cRakeInstantDmg = nRakeInstantDmg
        local cRakeDotDmg = 0

        -- Check for Rake debuff
        local checkRakeDebuff = wan.auraData[wan.TargetUnitID]["debuff_" .. wan.spellData.Rake.basename]
        if not checkRakeDebuff then
            local dotPotency = wan.CheckDotPotency(nRakeInstantDmg)
            cRakeDotDmg = cRakeDotDmg + (nRakeDotDmg * dotPotency)
        end

        -- Double-Clawed Rake
        local cDoubleClawedRakeInstantDmg = 0
        local cDoubleClawedRakeDotDmg = 0
        if wan.traitData.DoubleClawedRake.known and countValidUnit > 1 then
            cDoubleClawedRakeInstantDmg = nRakeInstantDmg
            local countRake = 0
            for unitToken, unitGUID in pairs(idValidUnit) do
                if unitGUID ~= wan.UnitState.GUID[wan.TargetUnitID] then
                    local checkDoubleClawedDebuff = wan.auraData[unitToken]["debuff_" .. wan.spellData.Rake.basename]
                    if not checkDoubleClawedDebuff then
                        local unitDotPotency = wan.CheckDotPotency(cDoubleClawedRakeInstantDmg, unitToken)
                        cDoubleClawedRakeDotDmg = nRakeDotDmg * unitDotPotency
                        countRake = countRake + 1
                    end
                end
                if countRake >= nDoubleClawedRakeAoeCap then break end  
            end
        end

        -- Pouncing Strikes
        local cPouncingStrikes = 1
        if wan.auraData.player.buff_SuddenAmbush or
            ((wan.traitData.PouncingStrikes.known or wan.PlayerState.SpecializationName ~= "Feral") and wan.auraData.player.buff_Prowl) then
            cPouncingStrikes = cPouncingStrikes + nPouncingStrikes
        end

        -- Crit value
        local cRakeCritValue = wan.ValueFromCritical(wan.CritChance)

        cRakeInstantDmg = (cRakeInstantDmg + cDoubleClawedRakeInstantDmg) * cPouncingStrikes * cRakeCritValue
        cRakeDotDmg = (cRakeDotDmg + cDoubleClawedRakeDotDmg) * cPouncingStrikes * cRakeCritValue

        -- Base values
        local cRakeDmg = cRakeInstantDmg + cRakeDotDmg

        -- Update ability data
        local abilityValue = math.floor(cRakeDmg)
        wan.UpdateAbilityData(wan.spellData.Rake.basename, abilityValue, wan.spellData.Rake.icon, wan.spellData.Rake.name)
    end


    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local rakeValues = wan.GetSpellDescriptionNumbers(wan.spellData.Rake.id, { 1, 2, 3 })
            nRakeInstantDmg = rakeValues[1]
            nRakeDotDmg = rakeValues[2]
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.Rake.known and wan.spellData.Rake.id
            wan.BlizzardEventHandler(frameRake, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameRake, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then
            nPouncingStrikes = wan.GetTraitDescriptionNumbers(wan.traitData.PouncingStrikes.entryid, { 3 }) * 0.01
            nDoubleClawedRakeAoeCap = wan.GetTraitDescriptionNumbers(wan.traitData.DoubleClawedRake.entryid, { 1 })
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameRake, CheckAbilityValue, abilityActive)
        end
    end)
end

frameRake:RegisterEvent("ADDON_LOADED")
frameRake:SetScript("OnEvent", AddonLoad)