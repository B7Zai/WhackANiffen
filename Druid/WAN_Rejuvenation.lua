local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameRejuvenation = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init data
    local abilityActive = false
    local nRejuvenationHotHeal = 0
    local nMasteryHarmony = 0

    -- Init trait data
    local nThrivingVegetation = 0
    local sGerminationKey = "RejuvenationGermination"

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or wan.auraData.player.buff_CatForm
        or wan.auraData.player.buff_BearForm or wan.auraData.player.buff_MoonkinForm
            or not wan.IsSpellUsable(wan.spellData.Rejuvenation.id)
        then
            wan.UpdateMechanicData(wan.spellData.Rejuvenation.basename)
            wan.UpdateHealingData(nil, wan.spellData.Rejuvenation.basename)
            return
        end

        local cRejuvenationInstantHeal = 0
        local cRejuvenationHotHeal = nRejuvenationHotHeal

        --add Thriving Vegetation trait layer
        if wan.traitData.ThrivingVegetation.known then
            local cThrivingVegetation = nRejuvenationHotHeal * nThrivingVegetation
            cRejuvenationInstantHeal = cRejuvenationInstantHeal + cThrivingVegetation
        end

        -- add Germination trait layer
        local cGerminationHotHeal = 0
        if wan.traitData.Germination.known then
            cGerminationHotHeal = nRejuvenationHotHeal
        end

        -- define crit layer
        local critValue = wan.ValueFromCritical(wan.CritChance)

        -- Update ability data
        if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then

            local hotKeys = {wan.spellData.Rejuvenation.basename, sGerminationKey}
            local _, _, idValidGroupUnit = wan.ValidGroupMembers()
            
            -- run check over all group units in range
            for groupUnitToken, groupUnitGUID in pairs(idValidGroupUnit) do

                cRejuvenationHotHeal = cRejuvenationHotHeal * critValue
                cGerminationHotHeal = cGerminationHotHeal * critValue
                cRejuvenationInstantHeal = cRejuvenationInstantHeal * critValue

                wan.HotValue[groupUnitToken] = wan.HotValue[groupUnitToken] or {}
                wan.HotValue[groupUnitToken]["buff_" .. wan.spellData.Rejuvenation.basename] = math.floor(cRejuvenationHotHeal)
                wan.HotValue[groupUnitToken]["buff_" .. sGerminationKey] = math.floor(cGerminationHotHeal)

                if wan.spellData.MasteryHarmony.known then
                    local _, countHots = wan.GetUnitHotValues(groupUnitToken, wan.HotValue[groupUnitToken])
                    local cMasteryHarmony = nMasteryHarmony * countHots
                    cRejuvenationHotHeal = cRejuvenationHotHeal * cMasteryHarmony
                    cGerminationHotHeal = cGerminationHotHeal * cMasteryHarmony
                    wan.HotValue[groupUnitToken]["buff_" .. wan.spellData.Rejuvenation.basename] = math.floor(cRejuvenationHotHeal)
                    wan.HotValue[groupUnitToken]["buff_" .. sGerminationKey] = math.floor(cGerminationHotHeal)
                end

                local baseRejuvenationHeal = cRejuvenationInstantHeal + cRejuvenationHotHeal + cGerminationHotHeal
                local cRejuvenationHeal = cRejuvenationInstantHeal + cRejuvenationHotHeal + cGerminationHotHeal

                -- subtract healing value of ability's hot from ability's max healing value
                for _, auraKey in pairs(hotKeys) do
                    if wan.auraData[groupUnitToken][auraKey] then
                        local hotValue = wan.HotValue[groupUnitToken][auraKey]
                        cRejuvenationHeal = cRejuvenationHeal - hotValue
                    end
                end

                -- exit early when ability doesn't contribute toward healing
                if cRejuvenationHeal / baseRejuvenationHeal < 0.5 then
                    wan.UpdateHealingData(groupUnitToken, wan.spellData.Rejuvenation.basename)
                    break
                end

                local unitHotValues = wan.GetUnitHotValues(groupUnitToken, wan.HotValue[groupUnitToken])

                -- check health of the unit
                local currentPercentHealth = (UnitPercentHealthFromGUID(groupUnitGUID) or 0)
                local maxHealth = wan.UnitMaxHealth[groupUnitToken]
                local abilityPercentageValue = (cRejuvenationHeal / maxHealth) or 0
                local hotPercentageValue = (unitHotValues / maxHealth) or 0
                local abilityValue = math.floor(cRejuvenationHeal) or 0

                -- check if the value of the healing ability exceeds the unit's missing health
                if (currentPercentHealth + abilityPercentageValue + hotPercentageValue) < 1 then
                    wan.UpdateHealingData(groupUnitToken, wan.spellData.Rejuvenation.basename, abilityValue, wan.spellData.Rejuvenation.icon, wan.spellData.Rejuvenation.name)

                    -- check on units that are too lvl compared to the player
                elseif cRejuvenationHeal > maxHealth then
                    -- convert heal scaling on player when group member is low lvl
                    local playerMaxHealth = wan.UnitMaxHealth["player"]
                    local abilityPercentageValueLowLvl = (cRejuvenationHeal / playerMaxHealth) or 0
                    local hotPercentageValueLowLvl = (unitHotValues / playerMaxHealth) or 0
                    if (currentPercentHealth + abilityPercentageValueLowLvl + hotPercentageValueLowLvl) < 1 then
                        wan.UpdateHealingData(groupUnitToken, wan.spellData.Rejuvenation.basename, abilityValue, wan.spellData.Rejuvenation.icon, wan.spellData.Rejuvenation.name)
                    end
                end
            end
        else
            -- define max healing value
            local cRejuvenationHealThreshold = cRejuvenationInstantHeal + cRejuvenationHotHeal + cGerminationHotHeal

            -- define current healing value
            local cGermination = wan.auraData.player["buff_" .. sGerminationKey] and cGerminationHotHeal or 0
            local cRejuvenationHotValue = wan.auraData.player.buff_Rejuvenation and nRejuvenationHotHeal or 0
            local cRejuvenationHeal = cRejuvenationInstantHeal + cRejuvenationHotValue + cGermination

            -- add crit layer
            cRejuvenationHeal = cRejuvenationHeal * critValue

            local abilityValue =  wan.HealThreshold() > cRejuvenationHealThreshold and math.floor(cRejuvenationHeal) or 0
            wan.UpdateMechanicData(wan.spellData.Rejuvenation.basename, abilityValue, wan.spellData.Rejuvenation.icon, wan.spellData.Rejuvenation.name)
        end
    end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nRejuvenationHotHeal = wan.GetSpellDescriptionNumbers(wan.spellData.Rejuvenation.id, { 1 })
            local nMasteryHarmonyValue = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryHarmony.id, { 1 })
            nMasteryHarmony = 1 + (nMasteryHarmonyValue * 0.01)
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.Rejuvenation.known and wan.spellData.Rejuvenation.id
            wan.BlizzardEventHandler(frameRejuvenation, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameRejuvenation, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then 
            nThrivingVegetation = wan.GetTraitDescriptionNumbers(wan.traitData.ThrivingVegetation.entryid, { 1 }) * 0.01
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameRejuvenation, CheckAbilityValue, abilityActive)
        end
    end)
end

frameRejuvenation:RegisterEvent("ADDON_LOADED")
frameRejuvenation:SetScript("OnEvent", AddonLoad)