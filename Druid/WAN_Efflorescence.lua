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
        or not wan.PlayerState.InGroup or not wan.PlayerState.InHealerMode or not wan.PlayerState.Combat
        or wan.auraData.player.buff_Efflorescence or not wan.IsSpellUsable(wan.spellData.Efflorescence.id)
        then
            wan.UpdateHealingData(nil, wan.spellData.Efflorescence.basename)
            return
        end

        local castTime = 0.1

        -- Cast time layer
        local castEfficiency = wan.CheckCastEfficiency(wan.spellData.Efflorescence.id, castTime)
        if castEfficiency == 0 then
            wan.UpdateHealingData(nil, wan.spellData.Efflorescence.basename)
            return
        end

        local cSprintBlossomsHotHeal = 0
        if wan.traitData.SprintBlossoms.known then
            cSprintBlossomsHotHeal = nSpringBlossoms
        end

        -- check crit layer
        local critMod = wan.ValueFromCritical(wan.CritChance)

        local currentTime = GetTime()

        -- Update ability data
        if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
            local _, _, idValidGroupUnit = wan.ValidGroupMembers()

            local unitsNeedHeal = 0
            wan.HealUnitCountAoE[wan.spellData.Efflorescence.basename] = wan.HealUnitCountAoE[wan.spellData.Efflorescence.basename] or 1

            -- run check over all group units in range
            for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

                if idValidGroupUnit[groupUnitToken] then

                    local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                    local cEfflorescenceInstantHeal = 0
                    local cEfflorescenceHotHeal = nEfflorescenceHotHeal
                    local hotPotency = wan.HotPotency(groupUnitToken, currentPercentHealth)

                    -- calculate estimated hot value
                    cEfflorescenceHotHeal = cEfflorescenceHotHeal * critMod * hotPotency * wan.UnitState.LevelScale[groupUnitToken] 
                    cSprintBlossomsHotHeal = cSprintBlossomsHotHeal * critMod * hotPotency * wan.UnitState.LevelScale[groupUnitToken] 

                    -- cache hot value on unit
                    wan.HotValue[groupUnitToken] = wan.HotValue[groupUnitToken] or {}
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

                    -- max healing value under 1 cast
                    local cEfflorescenceHeal = cEfflorescenceInstantHeal + cEfflorescenceHotHeal + cSprintBlossomsHotHeal

                    -- subtract healing value of ability's hot from ability's max healing value
                    local aura = wan.auraData[groupUnitToken]["buff_" .. wan.traitData.SpringBlossoms.traitkey]
                    if aura then
                        local remainingDuration = aura.expirationTime - currentTime
                        if remainingDuration < 0 then
                            wan.auraData[groupUnitToken]["buff_" .. wan.traitData.SpringBlossoms.traitkey] = nil
                        else
                            local hotValue = wan.HotValue[groupUnitToken][wan.traitData.SpringBlossoms.traitkey]
                            cEfflorescenceHeal = cEfflorescenceHeal - hotValue
                        end
                    end

                    cEfflorescenceHeal = cEfflorescenceHeal * wan.HealUnitCountAoE[wan.spellData.Efflorescence.basename]

                    local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cEfflorescenceHeal, currentPercentHealth, wan.HealUnitCountAoE[wan.spellData.Efflorescence.basename])
                    if abilityValue > 0 then unitsNeedHeal = unitsNeedHeal + 1 end
                    wan.UpdateHealingData(groupUnitToken, wan.spellData.Efflorescence.basename, abilityValue, wan.spellData.Efflorescence.icon, wan.spellData.Efflorescence.name)
                else
                    wan.UpdateHealingData(groupUnitToken, wan.spellData.Efflorescence.basename)
                end
            end

            if unitsNeedHeal > 0 then
                if unitsNeedHeal > nEfflorescenceUnitCap  then
                    unitsNeedHeal = nEfflorescenceUnitCap 
                end
                wan.HealUnitCountAoE[wan.spellData.Efflorescence.basename] = unitsNeedHeal
            else
                wan.HealUnitCountAoE[wan.spellData.Efflorescence.basename] = 1
            end
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