local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MONK" then return end

-- Init spell data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local aRisingSunKickData, nRisingSunKickDmg = {}, 0

-- Init trait data
local aMasteryComboStrikes, aMasteryComboStrikesEnablerIDs, bMasteryComboStrikes, nMasteryComboStrikes = {},{}, false, 0


-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status
        or not wan.IsSpellUsable(aRisingSunKickData.id)
    then
        wan.UpdateAbilityData(aRisingSunKickData.basename)
        return
    end

    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(aRisingSunKickData.id)
    if not isValidUnit then
        wan.UpdateAbilityData(aRisingSunKickData.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cRisingSunKickInstantDmg = 0
    local cRisingSunKickDmg = 0
    local cRisingSunKickInstantDmgAoE = 0
    local cRisingSunKickDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- WINDWALKER TRAITS ----

    local cMasterComboStrikes = 1
    if aMasteryComboStrikes.known then
        if bMasteryComboStrikes then
            cMasterComboStrikes = cMasterComboStrikes + nMasteryComboStrikes
        end
    end

    local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction()
    local cRisingSunKickCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cRisingSunKickCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cRisingSunKickInstantDmg = cRisingSunKickInstantDmg
        + (nRisingSunKickDmg * cRisingSunKickCritValue * checkUnitPhysicalDR * cMasterComboStrikes)

    cRisingSunKickDmg = cRisingSunKickDmg

    cRisingSunKickInstantDmgAoE = cRisingSunKickInstantDmgAoE

    cRisingSunKickDotDmgAoE = cRisingSunKickDotDmgAoE

    local cRisingSunKickDmg = cRisingSunKickInstantDmg + cRisingSunKickDmg + cRisingSunKickInstantDmgAoE + cRisingSunKickDotDmgAoE

    -- Update ability data
    local abilityDmg = math.floor(cRisingSunKickDmg)
    wan.UpdateAbilityData(aRisingSunKickData.basename, abilityDmg, aRisingSunKickData.icon, aRisingSunKickData.name)
end

local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, unit, _, spellID)
        if (event == "UNIT_AURA" and unit == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nRisingSunKickDmg = wan.GetSpellDescriptionNumbers(aRisingSunKickData.id, { 1 })

        end

        if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and aMasteryComboStrikes.known then
            if spellID == aRisingSunKickData.id then
                bMasteryComboStrikes = false
            else
                for _, enablerID in pairs(aMasteryComboStrikesEnablerIDs) do
                    if spellID == enablerID then
                        bMasteryComboStrikes = true

                        break
                    end
                end
            end
        end
    end)
end

local frameRisingSunKick = CreateFrame("Frame")
frameRisingSunKick:RegisterEvent("ADDON_LOADED")
frameRisingSunKick:SetScript("OnEvent", AddonLoad)

wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        aRisingSunKickData = wan.spellData.RisingSunKick

        abilityActive = aRisingSunKickData.known and aRisingSunKickData.id
        wan.BlizzardEventHandler(frameRisingSunKick, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameRisingSunKick, CheckAbilityValue, abilityActive)

        aMasteryComboStrikes = wan.spellData.MasteryComboStrikes
        aMasteryComboStrikesEnablerIDs = {
            wan.spellData.TigerPalm.id,
            wan.spellData.BlackoutKick.id,
            wan.spellData.SpinningCraneKick.id,
            wan.spellData.FistsofFury.id,
            wan.spellData.CracklingJadeLightning.id,
            wan.spellData.StrikeoftheWindlord.id,
            wan.spellData.WhirlingDragonPunch.id,
            wan.spellData.SlicingWinds.id
        }
    end

    if event == "TRAIT_DATA_READY" then

    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameRisingSunKick, CheckAbilityValue, abilityActive)
    end
end)