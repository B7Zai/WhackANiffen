local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local abilityActive = false
local nBloodshedDotDmg, nBloodshedInstantDmg = 0, 0

-- Init trait data
local nShowerofBloodUnitCap = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsPetUsable()
    or not wan.IsSpellUsable(wan.spellData.Bloodshed.id)
    then
        wan.UpdateAbilityData(wan.spellData.Bloodshed.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit ,idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.Bloodshed.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.Bloodshed.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0

    local cBloodshedInstantDmg = nBloodshedInstantDmg
    local cBloodshedDotDmg = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local checkBloodshedDebuff = wan.auraData[targetUnitToken] and wan.auraData[targetUnitToken]["debuff_" .. wan.spellData.Bloodshed.basename]
    if not checkBloodshedDebuff then
        local dotPotency = wan.CheckDotPotency()
        cBloodshedDotDmg = cBloodshedDotDmg + (nBloodshedDotDmg * dotPotency)
    end

    local cBloodshedInstantDmgAoE = 0
    local cBloodshedDotDmgAoE = 0
    if wan.traitData.ShowerofBlood.known and countValidUnit > 1 then
        local countShowerOfBlood = 0

        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then

                local cShowerOfBlood = 0
                local checkBloodshedDebuff = wan.auraData[nameplateUnitToken]["debuff_" .. wan.spellData.Bloodshed.basename]

                if not checkBloodshedDebuff then
                    local unitDotPotency = wan.CheckDotPotency()
                    cShowerOfBlood = cShowerOfBlood + (nBloodshedDotDmg * unitDotPotency)
                end

                cBloodshedInstantDmgAoE = cBloodshedInstantDmgAoE + nBloodshedInstantDmg
                cBloodshedDotDmgAoE = cBloodshedDotDmgAoE + cShowerOfBlood

                countShowerOfBlood = countShowerOfBlood + 1

                if countShowerOfBlood >= nShowerofBloodUnitCap then break end
            end
        end
    end

    -- Crit layer
    local cBloodshedCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cBloodshedInstantDmg = cBloodshedInstantDmg
    cBloodshedDotDmg = cBloodshedDotDmg * cBloodshedCritValue
    cBloodshedInstantDmgAoE = cBloodshedInstantDmgAoE
    cBloodshedDotDmgAoE = cBloodshedDotDmgAoE * cBloodshedCritValue

    local cBloodshedDmg = cBloodshedInstantDmg + cBloodshedDotDmg + cBloodshedInstantDmgAoE
    local cdPotency = wan.CheckOffensiveCooldownPotency(cBloodshedDmg, isValidUnit, idValidUnit)

    -- Update ability data
    local abilityValue = cdPotency and  math.floor(cBloodshedDmg) or 0
    wan.UpdateAbilityData(wan.spellData.Bloodshed.basename, abilityValue, wan.spellData.Bloodshed.icon, wan.spellData.Bloodshed.name)
end

-- Init frame 
local frameBloodshed = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nBloodshedValues = wan.GetSpellDescriptionNumbers(wan.spellData.Bloodshed.id, { 1, 3 })
            nBloodshedDotDmg = nBloodshedValues[1]
            nBloodshedInstantDmg = wan.AbilityPercentageToValue(nBloodshedValues[2])
        end
    end)
end
frameBloodshed:RegisterEvent("ADDON_LOADED")
frameBloodshed:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Bloodshed.known and wan.spellData.Bloodshed.id
        wan.BlizzardEventHandler(frameBloodshed, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameBloodshed, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nShowerofBloodUnitCap = wan.GetTraitDescriptionNumbers(wan.traitData.ShowerofBlood.entryid, { 1 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameBloodshed, CheckAbilityValue, abilityActive)
    end
end)