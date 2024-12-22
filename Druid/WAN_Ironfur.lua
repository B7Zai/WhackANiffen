local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameIronfur = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init spell data
    local abilityActive = false
    local nIronfur, drIronfur, nIronfurHeal = 0, 0, 0

    -- Init trait data
    local nThornsOfIron, nThornsOfIronValue, nThornsOfIronMaxRange, nThornsOfIronSoftCap = 0, 0, 0, 0
    local nMasterShapeshifter = 0


    -- Ability value calculation
    local function CheckAbilityValue()
         -- Early exits
        if not wan.PlayerState.Status or not wan.auraData.player.buff_BearForm
            or not wan.IsSpellUsable(wan.spellData.Ironfur.id)
        then
            wan.UpdateAbilityData(wan.spellData.Ironfur.basename)
            wan.UpdateMechanicData(wan.spellData.Ironfur.basename)
            return
        end

        -- Base values
        local cIronfurHeal = nIronfurHeal
        local cIronfurDmg = 0

        if wan.traitData.MasterShapeshifter.known then
            local cMasterShapeshifter = cIronfurHeal * nMasterShapeshifter
            cIronfurHeal = cIronfurHeal + cMasterShapeshifter
        end

        -- Thorns of Iron
        if wan.traitData.ThornsofIron.known then
            local cThornsOfIron = 0
            local _, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nThornsOfIronMaxRange)
            local softCapOverflow = wan.SoftCapOverflow(nThornsOfIronSoftCap, countValidUnit)
            for unitToken, _ in pairs (idValidUnit) do
                local checkPhysicalDRAoE = wan.CheckUnitPhysicalDamageReduction(unitToken)
                cThornsOfIron = cThornsOfIron + (nThornsOfIron * softCapOverflow * checkPhysicalDRAoE)
            end
            
            cIronfurDmg = cIronfurDmg + cThornsOfIron

            -- Crit layer
            cIronfurDmg = cIronfurDmg * wan.ValueFromCritical(wan.CritChance)
        end

        -- Threat situation
        local isTanking = wan.IsTanking()

        local damageValue = math.floor(cIronfurDmg) -- Update Ability Data
        local healValue = isTanking and math.floor(cIronfurHeal) or 0 -- Update Mechanic Data

        wan.UpdateMechanicData(wan.spellData.Ironfur.basename, healValue, wan.spellData.Ironfur.icon, wan.spellData.Ironfur.name)
        wan.UpdateAbilityData(wan.spellData.Ironfur.basename, damageValue, wan.spellData.Ironfur.icon, wan.spellData.Ironfur.name)
    end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED"then
            nIronfur = wan.GetSpellDescriptionNumbers(wan.spellData.Ironfur.id, { 1 })
            drIronfur = wan.GetArmorDamageReductionFromSpell(nIronfur)
            nIronfurHeal = wan.AbilityPercentageToValue(drIronfur)

            local _, _, armor = UnitArmor("player")
            nThornsOfIron = armor * nThornsOfIronValue
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.Ironfur.known and wan.spellData.Ironfur.id
            wan.BlizzardEventHandler(frameIronfur, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameIronfur, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then
            local thornsOfIronValues = wan.GetTraitDescriptionNumbers(wan.traitData.ThornsofIron.entryid, { 1, 2, 3 })
            nThornsOfIronValue = thornsOfIronValues[1] / 100
            nThornsOfIronMaxRange = thornsOfIronValues[2]
            nThornsOfIronSoftCap = thornsOfIronValues[3]

            nMasterShapeshifter = wan.GetTraitDescriptionNumbers(wan.traitData.MasterShapeshifter.entryid, { 5 }) * 0.01
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameIronfur, CheckAbilityValue, abilityActive)
        end
    end)
end

frameIronfur:RegisterEvent("ADDON_LOADED")
frameIronfur:SetScript("OnEvent", AddonLoad)