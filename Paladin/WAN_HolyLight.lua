local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local playerUnitToken = "player"
local abilityActive = false
local nHolyLightInstantHeal, nHolyLightMaxRange = 0, 0

-- Init trait data
local nMasteryLightbringer = 0
local nSelflessHealer = 0
local nAwestruck = 0
local nDivineFavor = 0
local nTyrsDeliverance = 0

-- Ability value calculation
local function CheckAbilityValue()
    local checkInfusion = wan.auraData.player.buff_InfusionofLight

    -- Early exits
    if not wan.PlayerState.Status or not checkInfusion
     or (checkInfusion and checkInfusion.applications < 2 and wan.UnitIsCasting("player", wan.spellData.HolyLight.name))
     or not wan.IsSpellUsable(wan.spellData.HolyLight.id)
    then
        wan.UpdateMechanicData(wan.spellData.HolyLight.basename)
        wan.UpdateHealingData(nil, wan.spellData.HolyLight.basename)
        return
    end

    -- Cast time layer
    local castEfficiency = wan.CheckCastEfficiency(wan.spellData.HolyLight.id, wan.spellData.HolyLight.castTime)
    if castEfficiency == 0 then
        wan.UpdateMechanicData(wan.spellData.HolyLight.basename)
        wan.UpdateHealingData(nil, wan.spellData.HolyLight.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cHolyLightCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    ---- CLASS TRAITS ----

    local bSelflessHealer = wan.traitData.SelflessHealer.known

    ---- HOLY TRAITS ----

    local bMasteryLightbringer = wan.spellData.MasteryLightbringer.known
    local bTyrsDeliverance = wan.traitData.TyrsDeliverance.known

    if wan.traitData.Awestruck.known then
        critDamageMod = critDamageMod + nAwestruck
    end

    local cDivineFavor = 1
    if wan.traitData.DivineFavor.known then
        local checkDivineFavorBuff = wan.CheckUnitBuff(nil, wan.traitData.DivineFavor.traitkey)
        if checkDivineFavorBuff then
            cDivineFavor = cDivineFavor + nDivineFavor
        end
    end

    -- Update ability data
    if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()

        for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

            if idValidGroupUnit[groupUnitToken] then

                local cHolyLightInstantHeal = 0
                local cHolyLightHotHeal = 0

                local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                local levelScale = wan.UnitState.LevelScale[groupUnitToken] or 1

                local cMasteryLightbringer = 1
                if bMasteryLightbringer then
                    local _, maxRange = wan.GetRangeBracket(groupUnitToken)
                    local cMasteryLightbringerRangeCap = math.min(nHolyLightMaxRange, maxRange)
                    local cMasteryLightbringerRatio = 1 - (cMasteryLightbringerRangeCap / nHolyLightMaxRange)

                    cMasteryLightbringer = cMasteryLightbringer + (nMasteryLightbringer * cMasteryLightbringerRatio)
                end

                local cSelflessHealer = 1
                if bSelflessHealer and groupUnitGUID ~= playerGUID then
                    cSelflessHealer = cSelflessHealer + nSelflessHealer
                end

                local cTyrsDeliverance = 1
                if bTyrsDeliverance then
                    local checkTyrsDeliveranceBuff = wan.CheckUnitBuff(nil, wan.traitData.TyrsDeliverance.traitkey)
                    if checkTyrsDeliveranceBuff then
                        cTyrsDeliverance = cTyrsDeliverance + nTyrsDeliverance
                    end
                end

                cHolyLightInstantHeal = cHolyLightInstantHeal
                    + (nHolyLightInstantHeal * cMasteryLightbringer * cSelflessHealer * cDivineFavor * cTyrsDeliverance * cHolyLightCritValue * levelScale)

                cHolyLightHotHeal = cHolyLightHotHeal

                local cHolyLightHeal = (cHolyLightInstantHeal + cHolyLightHotHeal) * castEfficiency

                local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cHolyLightHeal, currentPercentHealth)
                wan.UpdateHealingData(groupUnitToken, wan.spellData.HolyLight.basename, abilityValue, wan.spellData.HolyLight.icon, wan.spellData.HolyLight.name)
            else
                wan.UpdateHealingData(groupUnitToken, wan.spellData.HolyLight.basename)
            end
        end
    else

        local cHolyLightInstantHeal = 0
        local cHolyLightHotHeal = 0

        local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1

        local cMasteryLightbringer = 1
        if bMasteryLightbringer then
            cMasteryLightbringer = cMasteryLightbringer + nMasteryLightbringer
        end

        local cTyrsDeliverance = 1
        if bTyrsDeliverance then
            local checkTyrsDeliveranceBuff = wan.CheckUnitBuff(nil, wan.traitData.TyrsDeliverance.traitkey)
            if checkTyrsDeliveranceBuff then
                cTyrsDeliverance = cTyrsDeliverance + nTyrsDeliverance
            end
        end

        cHolyLightInstantHeal = cHolyLightInstantHeal
            + (nHolyLightInstantHeal * cMasteryLightbringer * cDivineFavor * cTyrsDeliverance * cHolyLightCritValue)

        cHolyLightHotHeal = cHolyLightHotHeal

        local cFlashofLightHeal = (cHolyLightInstantHeal + cHolyLightHotHeal) * castEfficiency

        local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cFlashofLightHeal, currentPercentHealth)
        wan.UpdateMechanicData(wan.spellData.HolyLight.basename, abilityValue, wan.spellData.HolyLight.icon, wan.spellData.HolyLight.name)
    end
end

-- Init frame 
local frameHolyLight = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nHolyLightInstantHeal = wan.GetSpellDescriptionNumbers(wan.spellData.HolyLight.id, { 1 })
            nHolyLightMaxRange = wan.spellData.HolyLight.maxRange

            nMasteryLightbringer = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryLightbringer.id, { 1 }) * 0.01
        end
    end)
end
frameHolyLight:RegisterEvent("ADDON_LOADED")
frameHolyLight:SetScript("OnEvent", AddonLoad)

wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.HolyLight.known and wan.spellData.HolyLight.id
        wan.BlizzardEventHandler(frameHolyLight, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameHolyLight, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nSelflessHealer = wan.GetTraitDescriptionNumbers(wan.traitData.SelflessHealer.entryid, { 1 }) * 0.01

        nAwestruck = wan.GetTraitDescriptionNumbers(wan.traitData.Awestruck.entryid, { 1 })

        nDivineFavor = wan.GetTraitDescriptionNumbers(wan.traitData.DivineFavor.entryid, { 1 }) * 0.01

        nTyrsDeliverance = wan.GetTraitDescriptionNumbers(wan.traitData.TyrsDeliverance.entryid, { 6 }) * 0.01
    end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.HolyLight.basename)
        else
            wan.UpdateHealingData(nil, wan.spellData.HolyLight.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameHolyLight, CheckAbilityValue, abilityActive)
    end
end)
