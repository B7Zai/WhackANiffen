local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameNourish = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init data
    local abilityActive = false
    local nNourishInstantHeal, nNourishHotHeal, nNourishMastery = 0, 0, 0
    local nMasteryHarmony = 0

    -- Init trait data
    local nHarmoniousBlooming = 0
    local nWildSynthesis = 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or wan.auraData.player.buff_CatForm
        or wan.auraData.player.buff_BearForm or wan.auraData.player.buff_MoonkinForm
            or not wan.IsSpellUsable(wan.spellData.Nourish.id)
        then
            wan.UpdateMechanicData(wan.spellData.Nourish.basename)
            wan.UpdateHealingData(nil, wan.spellData.Nourish.basename)
            return
        end

        -- Cast time layer
        local castEfficiency = wan.CheckCastEfficiency(wan.spellData.Nourish.id, wan.spellData.Nourish.castTime)
        if castEfficiency == 0 then
            wan.UpdateMechanicData(wan.spellData.Nourish.basename)
            wan.UpdateHealingData(nil, wan.spellData.Nourish.basename)
            return
        end

        -- Update ability data
        if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
            local _, _, idValidGroupUnit = wan.ValidGroupMembers()

            for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

                if idValidGroupUnit[groupUnitToken] then
                    local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                    local critChanceModInstant = 0
                    local critInstantValue = wan.ValueFromCritical(wan.CritChance, critChanceModInstant)

                    local countHots = 0
                    if wan.spellData.MasteryHarmony.known then
                        _, countHots = wan.GetUnitHotValues(groupUnitToken, wan.HotValue[groupUnitToken])
                    end

                    if wan.traitData.HarmoniousBlooming.known and wan.auraData[groupUnitToken].buff_Lifebloom then
                        countHots = countHots + nHarmoniousBlooming
                    end

                    local cWildSynthesis = 0
                    if wan.traitData.WildSynthesis.known and wan.auraData.player.buff_WildSynthesis then
                        local cWildSynthesisStacks = wan.auraData.player.buff_WildSynthesis.applications
                        cWildSynthesis = nWildSynthesis * cWildSynthesisStacks
                    end

                    local cMasteryHarmony = ((nMasteryHarmony + cWildSynthesis) * countHots) or 0
                    local cNourishInstantHeal = (nNourishInstantHeal + (nNourishInstantHeal * cMasteryHarmony * nNourishMastery)) * critInstantValue

                    -- add cast efficiency layer
                    local cNourishHeal = cNourishInstantHeal * castEfficiency

                    local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cNourishHeal, currentPercentHealth)
                    wan.UpdateHealingData(groupUnitToken, wan.spellData.Nourish.basename, abilityValue, wan.spellData.Nourish.icon, wan.spellData.Nourish.name)
                else
                    wan.UpdateHealingData(groupUnitToken, wan.spellData.Nourish.basename)
                end
            end
        else
            local unitToken = "player"
            local playerGUID = wan.PlayerState.GUID
            local currentPercentHealth = playerGUID and (UnitPercentHealthFromGUID(playerGUID) or 0)
            local critChanceModInstant = 0
            local critInstantValue = wan.ValueFromCritical(wan.CritChance, critChanceModInstant)

            local countHots = 0
            if wan.spellData.MasteryHarmony.known then
                _, countHots = wan.GetUnitHotValues(unitToken, wan.HotValue[unitToken])
            end

            if wan.traitData.HarmoniousBlooming.known and wan.auraData[unitToken].buff_Lifebloom then
                countHots = countHots + nHarmoniousBlooming
            end

            local cWildSynthesis = 0
            if wan.traitData.WildSynthesis.known and wan.auraData.player.buff_WildSynthesis then
                local cWildSynthesisStacks = wan.auraData.player.buff_WildSynthesis.applications
                cWildSynthesis = nWildSynthesis * cWildSynthesisStacks
            end

            local cMasteryHarmony = ((nMasteryHarmony + cWildSynthesis) * countHots) or 0
            local cNourishInstantHeal = (nNourishInstantHeal + (nNourishInstantHeal * cMasteryHarmony * nNourishMastery)) * critInstantValue

            local cNourishHeal = cNourishInstantHeal * castEfficiency

            local abilityValue = wan.UnitAbilityHealValue(unitToken, cNourishHeal, currentPercentHealth)
            wan.UpdateMechanicData(wan.spellData.Nourish.basename, abilityValue, wan.spellData.Nourish.icon, wan.spellData.Nourish.name)
        end
    end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nNourishValues = wan.GetSpellDescriptionNumbers(wan.spellData.Nourish.id, { 1, 2 })
            nNourishInstantHeal = nNourishValues[1]
            nNourishMastery = nNourishValues[2] * 0.01

            nMasteryHarmony = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryHarmony.id, { 1 }) * 0.01
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.Nourish.known and wan.spellData.Nourish.id
            wan.BlizzardEventHandler(frameNourish, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameNourish, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then 
            nHarmoniousBlooming = wan.GetTraitDescriptionNumbers(wan.traitData.HarmoniousBlooming.entryid, { 1 }) - 1

            nWildSynthesis = wan.GetTraitDescriptionNumbers(wan.traitData.HarmoniousBlooming.entryid, { 2 }) 
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameNourish, CheckAbilityValue, abilityActive)
        end
    end)
end

frameNourish:RegisterEvent("ADDON_LOADED")
frameNourish:SetScript("OnEvent", AddonLoad)