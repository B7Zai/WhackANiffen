local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MONK" then return end

-- Init spell data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local aTigerPalmData, nTigerPalmDmg = {}, 0

-- Init trait data
local aMasteryComboStrikes, aMasteryComboStrikesEnablerIDs, bMasteryComboStrikes, nMasteryComboStrikes = {},{}, false, 0
local aAcclamationData, nAcclamation = {}, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status
        or not wan.IsSpellUsable(aTigerPalmData.id)
    then
        wan.UpdateAbilityData(aTigerPalmData.basename)
        return
    end

    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(aTigerPalmData.id)
    if not isValidUnit then
        wan.UpdateAbilityData(aTigerPalmData.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cTigerPalmInstantDmg = 0
    local cTigerPalmDmg = 0
    local cTigerPalmInstantDmgAoE = 0
    local cTigerPalmDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- WINDWALKER TRAITS ----

    local cMasterComboStrikes = 1
    if aMasteryComboStrikes.known then
        if bMasteryComboStrikes then
            cMasterComboStrikes = cMasterComboStrikes + nMasteryComboStrikes
        end
    end

    local cAcclamation = 1
    if aAcclamationData.known then
        local checkAcclamationDebuff = wan.CheckUnitDebuff(nil, aAcclamationData.traitkey)

        if checkAcclamationDebuff then
            local cAcclamationStacks = checkAcclamationDebuff.applications

            if cAcclamationStacks == 0 then cAcclamationStacks = 1 end

            cAcclamation = cAcclamation + (nAcclamation * cAcclamationStacks)
        end
    end

    local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction()
    local cTigerPalmCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cTigerPalmCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cTigerPalmInstantDmg = cTigerPalmInstantDmg
        + (nTigerPalmDmg * cTigerPalmCritValue * checkUnitPhysicalDR * cMasterComboStrikes * cAcclamation)

    cTigerPalmDmg = cTigerPalmDmg

    cTigerPalmInstantDmgAoE = cTigerPalmInstantDmgAoE

    cTigerPalmDotDmgAoE = cTigerPalmDotDmgAoE

    local cTigerPalmDmg = cTigerPalmInstantDmg + cTigerPalmDmg + cTigerPalmInstantDmgAoE + cTigerPalmDotDmgAoE

    -- Update ability data
    local abilityDmg = math.floor(cTigerPalmDmg)
    wan.UpdateAbilityData(aTigerPalmData.basename, abilityDmg, aTigerPalmData.icon, aTigerPalmData.name)
end

local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, unit, _, spellID)
        if (event == "UNIT_AURA" and unit == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nTigerPalmDmg = wan.GetSpellDescriptionNumbers(aTigerPalmData.id, { 1 })

            nMasteryComboStrikes = wan.GetSpellDescriptionNumbers(aMasteryComboStrikes.id, { 1 }) * 0.01
        end

        if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and aMasteryComboStrikes.known then
            if spellID == aTigerPalmData.id then
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

local frameTigerPalm = CreateFrame("Frame")
frameTigerPalm:RegisterEvent("ADDON_LOADED")
frameTigerPalm:SetScript("OnEvent", AddonLoad)

wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        aTigerPalmData = wan.spellData.TigerPalm

        abilityActive = aTigerPalmData.known and aTigerPalmData.id
        wan.BlizzardEventHandler(frameTigerPalm, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED", "UNIT_SPELLCAST_SUCCEEDED")
        wan.SetUpdateRate(frameTigerPalm, CheckAbilityValue, abilityActive)

        aMasteryComboStrikes = wan.spellData.MasteryComboStrikes
        aMasteryComboStrikesEnablerIDs = {
            wan.spellData.BlackoutKick.id,
            wan.spellData.RisingSunKick.id,
            wan.spellData.SpinningCraneKick.id,
            wan.spellData.FistsofFury.id,
            wan.spellData.CracklingJadeLightning.id,
            wan.spellData.StrikeoftheWindlord.id,
            wan.spellData.WhirlingDragonPunch.id,
            wan.spellData.SlicingWinds.id
        }
    end

    if event == "TRAIT_DATA_READY" then

        aAcclamationData = wan.traitData.Acclamation
        nAcclamation = wan.GetTraitDescriptionNumbers(aAcclamationData.entryid, { 1 }, aAcclamationData.rank) * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameTigerPalm, CheckAbilityValue, abilityActive)
    end
end)