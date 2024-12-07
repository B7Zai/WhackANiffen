local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameLifebloom = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init data
    local abilityActive = false
    local nLifebloomInstantHeal, nLifebloomHotHeal, nLifebloomHeal = 0, 0, 0
    local nMasteryHarmony = 0

    -- Init triat data
    local nHarmoniousBlooming = 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or wan.auraData.player.buff_CatForm
        or wan.auraData.player.buff_BearForm or wan.auraData.player.buff_MoonkinForm
            or not wan.IsSpellUsable(wan.spellData.Lifebloom.id)
        then
            wan.UpdateMechanicData(wan.spellData.Lifebloom.basename)
            wan.UpdateHealingData(nil, wan.spellData.Lifebloom.basename)
            return
        end

        local nLifebloomCap = wan.traitData.Undergrowth.known and 2 or 1

        -- array of hots applied by this ability as key value
        local hotKey = wan.spellData.Lifebloom.basename

        local critMod = wan.ValueFromCritical(wan.CritChance)

        -- Update ability data
        if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
            local _, _, idValidGroupUnit = wan.ValidGroupMembers()

            local nLifebloomCount = 0
            for groupUnitToken, _ in pairs(idValidGroupUnit) do
                if wan.auraData[groupUnitToken].buff_Lifebloom then
                    nLifebloomCount = nLifebloomCount + 1
                end
            end
            if nLifebloomCount >= nLifebloomCap then
                wan.UpdateHealingData(nil, wan.spellData.Lifebloom.basename)
                return
            end

            -- run check over all group units in range
            for groupUnitToken, groupUnitGUID in pairs(idValidGroupUnit) do

                local currentPercentHealth = (UnitPercentHealthFromGUID(groupUnitGUID) or 0)

                -- base value
                local cLifebloomInstantHeal = 0
                local cLifebloomHotHeal = nLifebloomHotHeal
                local hotPotency = wan.HotPotency(groupUnitToken, currentPercentHealth)

                cLifebloomHotHeal = cLifebloomHotHeal * critMod * hotPotency

                wan.HotValue[groupUnitToken] = wan.HotValue[groupUnitToken] or {}
                wan.HotValue[groupUnitToken][hotKey] = cLifebloomHotHeal

                -- add mastery layer
                if wan.spellData.MasteryHarmony.known then
                    local _, countHots = wan.GetUnitHotValues(groupUnitToken, wan.HotValue[groupUnitToken])

                    if wan.traitData.HarmoniousBlooming.known then
                        if countHots == 0 then
                            countHots = 1 + nHarmoniousBlooming
                        end
                    else
                        if countHots == 0 then
                            countHots = 1
                        end
                    end

                    if wan.traitData.HarmoniousBlooming.known and wan.auraData[groupUnitToken].buff_Lifebloom then
                        countHots = countHots + nHarmoniousBlooming
                    end

                    local cMasteryHarmony = countHots > 0 and 1 + (nMasteryHarmony * countHots) or 1
                    cLifebloomHotHeal = cLifebloomHotHeal * cMasteryHarmony
                    wan.HotValue[groupUnitToken][hotKey] = cLifebloomHotHeal
                end

                -- max healing value
                local maxLifebloomHeal = cLifebloomInstantHeal + cLifebloomHotHeal
                local cLifebloomHeal = cLifebloomInstantHeal + cLifebloomHotHeal 

                -- subtract healing value of ability's hot from ability's max healing value
                if wan.auraData[groupUnitToken]["buff_" .. hotKey] then
                    local hotValue = wan.HotValue[groupUnitToken][hotKey]
                    cLifebloomHeal = cLifebloomHeal - hotValue
                end

                -- exit early when ability doesn't contribute toward healing
                if cLifebloomHeal / maxLifebloomHeal < 0.5 then
                    wan.UpdateHealingData(groupUnitToken, wan.spellData.Lifebloom.basename)
                else
                    local unitHotValues = wan.GetUnitHotValues(groupUnitToken, wan.HotValue[groupUnitToken])
                    local maxHealth = wan.UnitMaxHealth[groupUnitToken]
                    local abilityPercentageValue = (cLifebloomHeal / maxHealth) or 0
                    local hotPercentageValue = (unitHotValues / maxHealth) or 0
                    local abilityValue = math.floor(cLifebloomHeal) or 0

                    -- check if the value of the healing ability exceeds the unit's missing health
                    if (currentPercentHealth + abilityPercentageValue + hotPercentageValue) < 1 then
                        wan.UpdateHealingData(groupUnitToken, wan.spellData.Lifebloom.basename, abilityValue, wan.spellData.Lifebloom.icon, wan.spellData.Lifebloom.name)

                        -- check on units that are too lvl compared to the player
                    elseif cLifebloomHeal > maxHealth then
                        -- convert heal scaling on player when group member is low lvl
                        local playerMaxHealth = wan.UnitMaxHealth["player"]
                        local abilityPercentageValueLowLvl = (cLifebloomHeal / playerMaxHealth) or 0
                        local hotPercentageValueLowLvl = (unitHotValues / playerMaxHealth) or 0
                        if (currentPercentHealth + abilityPercentageValueLowLvl + hotPercentageValueLowLvl) < 1 then
                            wan.UpdateHealingData(groupUnitToken, wan.spellData.Lifebloom.basename, abilityValue, wan.spellData.Lifebloom.icon, wan.spellData.Lifebloom.name)
                        end
                    else
                        wan.UpdateHealingData(groupUnitToken, wan.spellData.Lifebloom.basename)
                    end
                end
            end
        else
            local unitToken = "player"
            local playerGUID =  wan.PlayerState.GUID
            local currentPercentHealth = playerGUID and UnitPercentHealthFromGUID(playerGUID) or 0
            local hotPotency = wan.HotPotency(unitToken, currentPercentHealth)
            local cLifebloomInstantHeal = 0
            local cLifebloomHotHeal = nLifebloomHotHeal

            cLifebloomHotHeal = cLifebloomHotHeal * critMod * hotPotency

            wan.HotValue[unitToken] = wan.HotValue[unitToken] or {}
            wan.HotValue[unitToken][wan.spellData.Lifebloom.basename] = cLifebloomHotHeal

            -- add mastery layer
            if wan.spellData.MasteryHarmony.known then
                local _, countHots = wan.GetUnitHotValues(unitToken, wan.HotValue[unitToken])

                if wan.traitData.HarmoniousBlooming.known then
                    if countHots == 0 then
                        countHots = 1 + nHarmoniousBlooming
                    end
                else
                    if countHots == 0 then
                        countHots = 1
                    end
                end

                if wan.traitData.HarmoniousBlooming.known and wan.auraData[unitToken].buff_Lifebloom then
                    countHots = countHots + nHarmoniousBlooming
                end

                local cMasteryHarmony = countHots > 0 and 1 + (nMasteryHarmony * countHots) or 1
                cLifebloomHotHeal = cLifebloomHotHeal * cMasteryHarmony
                wan.HotValue[unitToken][wan.spellData.Lifebloom.basename] = cLifebloomHotHeal
            end

            -- max healing value
            local maxLifebloomHeal = cLifebloomInstantHeal + cLifebloomHotHeal 
            local cLifebloomHeal = cLifebloomInstantHeal + cLifebloomHotHeal

            -- subtract healing value of ability's hot from ability's max healing value
            if wan.auraData[unitToken]["buff_" .. hotKey] then
                local hotValue = wan.HotValue[unitToken][hotKey]
                cLifebloomHeal = cLifebloomHeal - hotValue
            end

            -- exit early when ability doesn't contribute toward healing
            if cLifebloomHeal / maxLifebloomHeal < 0.5 then
                wan.UpdateMechanicData(wan.spellData.Lifebloom.basename)
            else
                local unitHotValues = wan.GetUnitHotValues(unitToken, wan.HotValue[unitToken])
                local maxHealth = wan.UnitMaxHealth[unitToken]
                local abilityPercentageValue = (cLifebloomHeal / maxHealth) or 0
                local hotPercentageValue = (unitHotValues / maxHealth) or 0
                local abilityValue = math.floor(cLifebloomHeal) or 0

                if (currentPercentHealth + abilityPercentageValue + hotPercentageValue) < 1 then
                    wan.UpdateMechanicData(wan.spellData.Lifebloom.basename, abilityValue, wan.spellData.Lifebloom.icon, wan.spellData.Lifebloom.name)
                else
                    wan.UpdateMechanicData(wan.spellData.Lifebloom.basename)
                end
            end
        end
    end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nLifebloomValues = wan.GetSpellDescriptionNumbers(wan.spellData.Lifebloom.id, { 1, 3 })
            nLifebloomHotHeal = nLifebloomValues[1] + nLifebloomValues[2]

            nMasteryHarmony = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryHarmony.id, { 1 }) * 0.01
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.Lifebloom.known and wan.spellData.Lifebloom.id
            wan.BlizzardEventHandler(frameLifebloom, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameLifebloom, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then 
            nHarmoniousBlooming = wan.GetTraitDescriptionNumbers(wan.traitData.HarmoniousBlooming.entryid, { 1 }) - 1
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameLifebloom, CheckAbilityValue, abilityActive)
        end
    end)
end

frameLifebloom:RegisterEvent("ADDON_LOADED")
frameLifebloom:SetScript("OnEvent", AddonLoad)