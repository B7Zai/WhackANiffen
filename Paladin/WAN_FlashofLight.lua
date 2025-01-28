local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local playerUnitToken = "player"
local abilityActive = false
local nFlashofLightInstantHeal, nFlashofLightMaxRange = 0, 0

-- Init trait data
local nMasteryLightbringer, nMasteryLightbringerMaxRange = 0, 0
local nSelflessHealer = 0
local nAwestruck = 0
local nMomentofCompassion = 0
local nDivineFavor = 0
local nDivineRevelations = 0
local nTyrsDeliverance = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.FlashofLight.id)
    then
        wan.UpdateMechanicData(wan.spellData.FlashofLight.basename)
        wan.UpdateHealingData(nil, wan.spellData.FlashofLight.basename)
        return
    end

    -- Cast time layer
    local castEfficiency = wan.CheckCastEfficiency(wan.spellData.FlashofLight.id, wan.spellData.FlashofLight.castTime)
    if castEfficiency == 0 then
        wan.UpdateMechanicData(wan.spellData.FlashofLight.basename)
        wan.UpdateHealingData(nil, wan.spellData.FlashofLight.basename)
        return
    end

    if wan.PlayerState.Role == "TANK" then
        local isTanking = wan.IsTanking()
        if isTanking then
            wan.UpdateMechanicData(wan.spellData.FlashofLight.basename)
            wan.UpdateHealingData(nil, wan.spellData.FlashofLight.basename)
            return
        end
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cFlashofLightCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    ---- CLASS TRAITS ----

    local bSelflessHealer = wan.traitData.SelflessHealer.known

    ---- HOLY TRAITS ----

    local bMasteryLightbringer = wan.spellData.MasteryLightbringer.known
    local bMomentofCompassion = wan.traitData.MomentofCompassion.known
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

    local cDivineRevelations = 1
    if wan.traitData.DivineRevelations.known then
        local checkInfusionofLightBuff = wan.CheckUnitBuff(nil, wan.spellData.InfusionofLight.basename)
        if checkInfusionofLightBuff then
            cDivineRevelations = cDivineRevelations + nDivineRevelations
        end
    end

    -- Update ability data
    if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()

        for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

            if idValidGroupUnit[groupUnitToken] then

                local cFlashofLightInstantHeal = 0
                local cFlashofLightHotHeal = 0

                local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1

                local cMasteryLightbringer = 1
                if bMasteryLightbringer then
                    local _, maxRange = wan.GetRangeBracket(groupUnitToken)
                    local cMasteryLightbringerRangeCap = math.min(nFlashofLightMaxRange, maxRange)
                    local cMasteryLightbringerRatio = 1 - (cMasteryLightbringerRangeCap / nFlashofLightMaxRange)

                    cMasteryLightbringer = cMasteryLightbringer + (nMasteryLightbringer * cMasteryLightbringerRatio)
                end

                local cSelflessHealer = 1
                if bSelflessHealer and groupUnitGUID ~= playerGUID then
                    cSelflessHealer = cSelflessHealer + nSelflessHealer
                end

                local cMomentofCompassion = 1
                if bMomentofCompassion then
                    local checkBeaconofLightBuff = wan.spellData.BeaconofLight.known and wan.CheckUnitBuff(groupUnitToken, wan.spellData.BeaconofLight.basename)
                    local checkBeaconofFaithBuff = wan.traitData.BeaconofFaith.known and wan.CheckUnitBuff(groupUnitToken, wan.traitData.BeaconofFaith.traitkey)

                    if checkBeaconofLightBuff or checkBeaconofFaithBuff then
                        cMomentofCompassion = cMomentofCompassion + nMomentofCompassion
                    end
                end

                local cTyrsDeliverance = 1
                if bTyrsDeliverance then
                    local checkTyrsDeliveranceBuff = wan.CheckUnitBuff(nil, wan.traitData.TyrsDeliverance.traitkey)
                    if checkTyrsDeliveranceBuff then
                        cTyrsDeliverance = cTyrsDeliverance + nTyrsDeliverance
                    end
                end

                cFlashofLightInstantHeal = cFlashofLightInstantHeal
                    + (nFlashofLightInstantHeal * cMasteryLightbringer * cSelflessHealer * cMomentofCompassion * cDivineRevelations * cDivineFavor * cTyrsDeliverance * cFlashofLightCritValue)

                cFlashofLightHotHeal = cFlashofLightHotHeal

                local cFlashofLightHeal = (cFlashofLightInstantHeal + cFlashofLightHotHeal) * castEfficiency

                local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cFlashofLightHeal, currentPercentHealth)
                wan.UpdateHealingData(groupUnitToken, wan.spellData.FlashofLight.basename, abilityValue, wan.spellData.FlashofLight.icon, wan.spellData.FlashofLight.name)
            else
                wan.UpdateHealingData(groupUnitToken, wan.spellData.FlashofLight.basename)
            end
        end
    else

        local cFlashofLightInstantHeal = 0
        local cFlashofLightHotHeal = 0

        local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1

        local cMasteryLightbringer = 1
        if bMasteryLightbringer then
            cMasteryLightbringer = cMasteryLightbringer + nMasteryLightbringer
        end

        local cMomentofCompassion = 1
        if bMomentofCompassion then
            local checkBeaconofLightBuff = wan.spellData.BeaconofLight.known and wan.CheckUnitBuff(playerUnitToken, wan.spellData.BeaconofLight.basename)
            local checkBeaconofFaithBuff = wan.traitData.BeaconofFaith.known and wan.CheckUnitBuff(playerUnitToken, wan.traitData.BeaconofFaith.traitkey)

            if checkBeaconofLightBuff or checkBeaconofFaithBuff then
                cMomentofCompassion = cMomentofCompassion + nMomentofCompassion
            end
        end

        local cTyrsDeliverance = 1
        if bTyrsDeliverance then
            local checkTyrsDeliveranceBuff = wan.CheckUnitBuff(nil, wan.traitData.TyrsDeliverance.traitkey)
            if checkTyrsDeliveranceBuff then
                cTyrsDeliverance = cTyrsDeliverance + nTyrsDeliverance
            end
        end

        cFlashofLightInstantHeal = cFlashofLightInstantHeal
            + (nFlashofLightInstantHeal * cMasteryLightbringer * cMomentofCompassion * cDivineRevelations * cDivineFavor * cTyrsDeliverance * cFlashofLightCritValue)

        cFlashofLightHotHeal = cFlashofLightHotHeal

        local cFlashofLightHeal = (cFlashofLightInstantHeal + cFlashofLightHotHeal) * castEfficiency

        local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cFlashofLightHeal, currentPercentHealth)
        wan.UpdateMechanicData(wan.spellData.FlashofLight.basename, abilityValue, wan.spellData.FlashofLight.icon, wan.spellData.FlashofLight.name)
    end
end

-- Init frame 
local frameFlashofLight = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nFlashofLightInstantHeal = wan.GetSpellDescriptionNumbers(wan.spellData.FlashofLight.id, { 1 })
            nFlashofLightMaxRange = wan.spellData.FlashofLight.maxRange

            nMasteryLightbringer = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryLightbringer.id, { 1 }) * 0.01
        end
    end)
end
frameFlashofLight:RegisterEvent("ADDON_LOADED")
frameFlashofLight:SetScript("OnEvent", AddonLoad)

wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.FlashofLight.known and wan.spellData.FlashofLight.id
        wan.BlizzardEventHandler(frameFlashofLight, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameFlashofLight, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nSelflessHealer = wan.GetTraitDescriptionNumbers(wan.traitData.SelflessHealer.entryid, { 1 }) * 0.01

        nAwestruck = wan.GetTraitDescriptionNumbers(wan.traitData.Awestruck.entryid, { 1 })

        nMomentofCompassion = wan.GetTraitDescriptionNumbers(wan.traitData.MomentofCompassion.entryid, { 1 }) * 0.01

        nDivineFavor = wan.GetTraitDescriptionNumbers(wan.traitData.DivineFavor.entryid, { 1 }) * 0.01

        nDivineRevelations = wan.GetTraitDescriptionNumbers(wan.traitData.DivineRevelations.entryid, { 1 }) * 0.01

        nTyrsDeliverance = wan.GetTraitDescriptionNumbers(wan.traitData.TyrsDeliverance.entryid, { 6 }) * 0.01
    end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.FlashofLight.basename)
        else
            wan.UpdateHealingData(nil, wan.spellData.FlashofLight.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameFlashofLight, CheckAbilityValue, abilityActive)
    end
end)
