local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nLightofDawnInstantHeal, nLightofDawnMaxRange, nLightofDawnUnitCap = 0, 14, 5
local nMasteryHarmony = 0

-- Init triat data
local nMasteryLightbringer = 0
local nExtrication = 0
local nDawnlightHotHeal = 0
local nLuminosity = 0
local nSunSearHotHeal, nSunSearProcChance = 0, 0
local nSecondSunriseProcChance, nSecondSunrise = 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.InGroup or not wan.PlayerState.InHealerMode
        or not wan.IsSpellUsable(wan.spellData.LightofDawn.id)
    then
        wan.UpdateMechanicData(wan.spellData.LightofDawn.basename)
        wan.UpdateHealingData(nil, wan.spellData.LightofDawn.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    -- check crit layer
    local cLightofDawnCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cLightofDawnCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    ---- HOLY TRAITS ----

    local bMasteryLightbringer = wan.spellData.MasteryLightbringer.known

    if wan.traitData.Extrication.known then
        critChanceMod = critChanceMod + nExtrication
    end

    ---- HERALD OF THE SUN TRAITS ----

    local bDawnlight = wan.traitData.Dawnlight.known
    local sDawnlightFormattedBuffName = wan.traitData.Dawnlight.traitkey

    if wan.traitData.Luminosity.known then
        critChanceMod = critChanceMod + nLuminosity
    end

    local cSunSearHotHeal = 0
    if wan.traitData.SunSear.known then
        cSunSearHotHeal = cSunSearHotHeal + (nSunSearHotHeal * nSunSearProcChance)
    end

    local cSecondSunriseInstantHeal = 0
    if wan.traitData.SecondSunrise.known then
        cSecondSunriseInstantHeal = cSecondSunriseInstantHeal + (nLightofDawnInstantHeal * nSecondSunriseProcChance * nSecondSunrise)
    end

    local hotKeys = sDawnlightFormattedBuffName
    local cLightofDawnCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cLightofDawnCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)
    local _, _, idValidGroupUnit = wan.ValidGroupMembersInSpellRange(nil, nLightofDawnMaxRange)
    local currentTime = GetTime()
    
    local unitsNeedHeal = 0
    wan.HealUnitCountAoE[wan.spellData.LightofDawn.basename] = wan.HealUnitCountAoE[wan.spellData.LightofDawn.basename] or 1

    -- run check over all group units in range
    for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

        if idValidGroupUnit[groupUnitToken] then

            local cLightofDawnInstantHeal = 0
            local cLightofDawnHotHeal = 0
            wan.HotValue[groupUnitToken] = wan.HotValue[groupUnitToken] or {}

            local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1

            local cMasteryLightbringer = 1
            if bMasteryLightbringer then
                local _, maxRange = wan.GetRangeBracket(groupUnitToken)
                local cMasteryLightbringerRangeCap = math.min(nLightofDawnMaxRange, maxRange)
                local cMasteryLightbringerRatio = 1 - (cMasteryLightbringerRangeCap / nLightofDawnMaxRange)

                cMasteryLightbringer = cMasteryLightbringer + (nMasteryLightbringer * cMasteryLightbringerRatio)
            end

            local cDawnlightHotHeal = 0
            if bDawnlight then
                cDawnlightHotHeal = cDawnlightHotHeal + (nDawnlightHotHeal / wan.HealUnitCountAoE[wan.spellData.LightofDawn.basename])

                wan.HotValue[groupUnitToken][sDawnlightFormattedBuffName] = cDawnlightHotHeal
            end

            cLightofDawnInstantHeal = cLightofDawnInstantHeal
                + (nLightofDawnInstantHeal * cMasteryLightbringer * cLightofDawnCritValue)
                + (cSecondSunriseInstantHeal * cMasteryLightbringer * cLightofDawnCritValue)

            cLightofDawnHotHeal = cLightofDawnHotHeal
                + (cDawnlightHotHeal * cLightofDawnCritValueBase)
                + (cSunSearHotHeal * cLightofDawnCritValueBase)

            local cLightofDawnHeal = cLightofDawnInstantHeal + cLightofDawnHotHeal

            local aura = wan.auraData[groupUnitToken]["buff_" .. hotKeys]
            if aura then
                local reminingDuration = aura.expirationTime - currentTime
                if reminingDuration < 0 then
                    wan.auraData[groupUnitToken]["buff_" .. hotKeys] = nil
                else
                    local hotValue = wan.HotValue[groupUnitToken][hotKeys]
                    cLightofDawnHeal = cLightofDawnHeal - hotValue
                end
            end

            local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cLightofDawnHeal, currentPercentHealth)
            if abilityValue > 0 then unitsNeedHeal = unitsNeedHeal + 1 end
            wan.UpdateHealingData(groupUnitToken, wan.spellData.LightofDawn.basename, abilityValue, wan.spellData.LightofDawn.icon, wan.spellData.LightofDawn.name)
        else
            wan.UpdateHealingData(groupUnitToken, wan.spellData.LightofDawn.basename)
        end
    end

    if unitsNeedHeal > 0 then

        if unitsNeedHeal > nLightofDawnUnitCap then
            unitsNeedHeal = nLightofDawnUnitCap
        end
        wan.HealUnitCountAoE[wan.spellData.LightofDawn.basename] = unitsNeedHeal
        
    else
        wan.HealUnitCountAoE[wan.spellData.LightofDawn.basename] = 1
    end
end

-- Init frame 
local frameLightofDawn = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nLightofDawnValues = wan.GetSpellDescriptionNumbers(wan.spellData.LightofDawn.id, { 1, 2, 3 })
            nLightofDawnUnitCap = nLightofDawnValues[1]
            nLightofDawnMaxRange = nLightofDawnValues[2]
            nLightofDawnInstantHeal = nLightofDawnValues[3]

            nMasteryLightbringer = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryLightbringer.id, { 1 }) * 0.01

            nDawnlightHotHeal = wan.GetTraitDescriptionNumbers(wan.traitData.Dawnlight.entryid, { 2 })

            nSunSearHotHeal = wan.GetTraitDescriptionNumbers(wan.traitData.SunSear.entryid, { 1 })
            nSunSearProcChance = wan.CritChance * 0.01
        end
    end)
end
frameLightofDawn:RegisterEvent("ADDON_LOADED")
frameLightofDawn:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.LightofDawn.known and wan.spellData.LightofDawn.id
        wan.BlizzardEventHandler(frameLightofDawn, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameLightofDawn, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nExtrication = wan.GetTraitDescriptionNumbers(wan.traitData.Extrication.entryid, { 1 })

        nLuminosity = wan.GetTraitDescriptionNumbers(wan.traitData.Luminosity.entryid, { 1 })

        local nSecondSunriseValues = wan.GetTraitDescriptionNumbers(wan.traitData.SecondSunrise.entryid, { 1, 2 })
        nSecondSunriseProcChance = nSecondSunriseValues[1] * 0.01
        nSecondSunrise = nSecondSunriseValues[2] * 0.01
    end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if not wan.PlayerState.InHealerMode then
            wan.UpdateHealingData(nil, wan.spellData.LightofDawn.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameLightofDawn, CheckAbilityValue, abilityActive)
    end
end)