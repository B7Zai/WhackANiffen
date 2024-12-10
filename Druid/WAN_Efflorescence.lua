local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameEfflorescence = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init data
    local abilityActive = false
    local nEfflorescenceHotHeal, nEfflorescenceTickRate, nEfflorescenceDuration, nEfflorescenceHotTick, nEfflorescenceUnitCap  = 0, 0, 0, 0, 3
    local nMasteryHarmony = 0

    -- Init triat data
    local nHarmoniousBlooming = 0
    local nSpringBlossoms = 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or wan.auraData.player.buff_CatForm
        or wan.auraData.player.buff_BearForm or wan.auraData.player.buff_MoonkinForm
        or not wan.PlayerState.InGroup or not wan.PlayerState.InHealerMode
        or wan.auraData.player.buff_Efflorescence or not wan.IsSpellUsable(wan.spellData.Efflorescence.id)
        then
            wan.UpdateMechanicData(wan.spellData.Efflorescence.basename)
            wan.UpdateHealingData(nil, wan.spellData.Efflorescence.basename)
            return
        end

        -- check crit layer
        local critMod = wan.ValueFromCritical(wan.CritChance)

        -- Update ability data
        if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
            local _, _, idValidGroupUnit = wan.ValidGroupMembers()

            local unitsNeedHeal = 0
            wan.HealUnitCountAoE[wan.spellData.Efflorescence.basename] = wan.HealUnitCountAoE[wan.spellData.Efflorescence.basename] or unitsNeedHeal

            -- run check over all group units in range
            for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

                if idValidGroupUnit[groupUnitToken] then

                    local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                    local cEfflorescenceInstantHeal = 0
                    local cEfflorescenceHotHeal = nEfflorescenceHotHeal
                    local hotPotency = wan.HotPotency(groupUnitToken, currentPercentHealth)

                    local cSprintBlossomsHotHeal = 0
                    if wan.traitData.SprintBlossoms.known then
                        cSprintBlossomsHotHeal = nSpringBlossoms
                    end

                    -- calculate estimated hot value
                    cEfflorescenceHotHeal = cEfflorescenceHotHeal * critMod * hotPotency
                    cSprintBlossomsHotHeal = cSprintBlossomsHotHeal * critMod * hotPotency

                    -- cache hot value on unit
                    wan.HotValue[groupUnitToken] = wan.HotValue[groupUnitToken] or {}
                    wan.HotValue[groupUnitToken][wan.spellData.Efflorescence.basename] = cEfflorescenceHotHeal
                    wan.HotValue[groupUnitToken][wan.traitData.SpringBlossoms.traitkey] = cSprintBlossomsHotHeal

                    -- add mastery layer
                    if wan.spellData.MasteryHarmony.known and wan.traitData.SprintBlossoms.known then
                        local _, countHots = wan.GetUnitHotValues(groupUnitToken, wan.HotValue[groupUnitToken])

                        -- add base mastery mod for ability's hot
                        if countHots == 0 then countHots = 1 end

                        -- Harmonious Blooming trait layer
                        if wan.traitData.HarmoniousBlooming.known and wan.auraData[groupUnitToken].buff_Lifebloom then
                            countHots = countHots + nHarmoniousBlooming
                        end

                        -- add mastery layer to hot value and update array with max hot value
                        local cMasteryHarmony = countHots > 0 and 1 + (nMasteryHarmony * countHots) or 1
                        cSprintBlossomsHotHeal = cSprintBlossomsHotHeal * cMasteryHarmony
                        wan.HotValue[groupUnitToken][wan.traitData.SpringBlossoms.traitkey] = cSprintBlossomsHotHeal
                    end

                    -- max healing values
                    local maxEfflorescenceHeal = cEfflorescenceInstantHeal + cEfflorescenceHotHeal +
                    cSprintBlossomsHotHeal
                    -- max healing value under 1 cast
                    local cEfflorescenceHeal = cEfflorescenceInstantHeal + cEfflorescenceHotHeal + cSprintBlossomsHotHeal

                    -- subtract healing value of ability's hot from ability's max healing value
                    if wan.auraData[groupUnitToken]["buff_" .. wan.traitData.SpringBlossoms.traitkey] then
                        local hotValue = wan.HotValue[groupUnitToken][wan.traitData.SpringBlossoms.traitkey]
                        cEfflorescenceHeal = cEfflorescenceHeal - hotValue
                    end

                    -- exit early when ability doesn't contribute toward healing
                    if cEfflorescenceHeal / maxEfflorescenceHeal < 0.5 then
                        wan.UpdateHealingData(groupUnitToken, wan.spellData.Efflorescence.basename)
                    else
                        local unitHotValues = wan.GetUnitHotValues(groupUnitToken, wan.HotValue[groupUnitToken])
                        local maxHealth = wan.UnitMaxHealth[groupUnitToken]
                        local abilityPercentageValue = (cEfflorescenceHeal / maxHealth) or 0
                        local hotPercentageValue = (unitHotValues / maxHealth) or 0
                        local abilityValue = (math.floor(cEfflorescenceHeal) or 0) *
                        wan.HealUnitCountAoE[wan.spellData.Efflorescence.basename]

                        -- check if the value of the healing ability exceeds the unit's missing health
                        if (currentPercentHealth + abilityPercentageValue + hotPercentageValue) < 1 and currentPercentHealth ~= 0 then
                            unitsNeedHeal = unitsNeedHeal + 1
                            wan.UpdateHealingData(groupUnitToken, wan.spellData.Efflorescence.basename, abilityValue,
                                wan.spellData.Efflorescence.icon, wan.spellData.Efflorescence.name)

                            -- check on units that are too lvl compared to the player
                        elseif cEfflorescenceHeal > maxHealth and currentPercentHealth ~= 0 then
                            unitsNeedHeal = unitsNeedHeal + 1

                            -- convert heal scaling on player when group member is low lvl
                            local playerMaxHealth = wan.UnitMaxHealth["player"]
                            local abilityPercentageValueLowLvl = (cEfflorescenceHeal / playerMaxHealth) or 0
                            local hotPercentageValueLowLvl = (unitHotValues / playerMaxHealth) or 0
                            if (currentPercentHealth + abilityPercentageValueLowLvl + hotPercentageValueLowLvl) < 1 then
                                wan.UpdateHealingData(groupUnitToken, wan.spellData.Efflorescence.basename, abilityValue,
                                    wan.spellData.Efflorescence.icon, wan.spellData.Efflorescence.name)
                            end
                        else
                            wan.UpdateHealingData(groupUnitToken, wan.spellData.Efflorescence.basename)
                        end
                    end
                else
                    wan.UpdateHealingData(groupUnitToken, wan.spellData.Efflorescence.basename)
                end
            end

            if unitsNeedHeal > nEfflorescenceUnitCap then
                unitsNeedHeal = nEfflorescenceUnitCap
            end
            wan.HealUnitCountAoE[wan.spellData.Efflorescence.basename] = unitsNeedHeal
        end
    end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nEfflorescenceValues= wan.GetSpellDescriptionNumbers(wan.spellData.Efflorescence.id, { 1, 3, 4 })
            nEfflorescenceHotTick = nEfflorescenceValues[1]
            nEfflorescenceTickRate = nEfflorescenceValues[2]
            nEfflorescenceDuration = nEfflorescenceValues[3]
            nEfflorescenceHotHeal = nEfflorescenceHotTick * ( nEfflorescenceDuration / nEfflorescenceTickRate )

            nSpringBlossoms = wan.GetTraitDescriptionNumbers(wan.traitData.SpringBlossoms.entryid, { 1 })

            nMasteryHarmony = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryHarmony.id, { 1 }) * 0.01
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.Efflorescence.known and wan.spellData.Efflorescence.id
            wan.BlizzardEventHandler(frameEfflorescence, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameEfflorescence, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then 
            nHarmoniousBlooming = wan.GetTraitDescriptionNumbers(wan.traitData.HarmoniousBlooming.entryid, { 1 }) - 1
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameEfflorescence, CheckAbilityValue, abilityActive)
        end
    end)
end

frameEfflorescence:RegisterEvent("ADDON_LOADED")
frameEfflorescence:SetScript("OnEvent", AddonLoad)