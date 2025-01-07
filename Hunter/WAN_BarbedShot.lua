local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local abilityActive = false
local nBarbedShotDmg = 0
local checkDebuffs = {}

-- Init trait data
local nFuriousAssault = 0
local nStomp = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.BarbedShot.id)
    then
        wan.UpdateAbilityData(wan.spellData.BarbedShot.basename)
        wan.UpdateMechanicData(wan.spellData.BarbedShot.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit ,idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.BarbedShot.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.BarbedShot.basename)
        wan.UpdateMechanicData(wan.spellData.BarbedShot.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0

    local cBarbedShotInstantDmg = 0
    local cBarbedShotDotDmg = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local checkBarbedShotDebuff = wan.auraData[targetUnitToken] and wan.auraData[targetUnitToken]["debuff_" .. wan.spellData.BarbedShot.basename]
    if not checkBarbedShotDebuff then
        cBarbedShotDotDmg = cBarbedShotDotDmg + nBarbedShotDmg
    end

    local cStomp = 0
    if wan.traitData.Stomp.known then
        cStomp = cStomp + nStomp
    end

    local cFuriousAssault = 1
    if wan.traitData.FuriousAssault.known and wan.auraData.player.buff_FuriousAssault then
        cFuriousAssault = cFuriousAssault + nFuriousAssault
    end

    local cBarbedShotInstantAoEDmg = 0
    local cBarbedShotDotDmgAoE = 0
    if wan.traitData.Stomp.known and countValidUnit > 1 then

        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then

                local checkDebuff = wan.CheckForAnyDebuff(nameplateUnitToken, checkDebuffs)
                if checkDebuff then
                    local cUnitStomp = nStomp

                    cBarbedShotInstantAoEDmg = cBarbedShotInstantAoEDmg + cUnitStomp
                end
            end
        end
    end

    -- Crit layer
    local cBarbedShotCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cBarbedShotInstantDmg = (cBarbedShotInstantDmg + cStomp) * cBarbedShotCritValue
    cBarbedShotDotDmg = cBarbedShotDotDmg * cFuriousAssault * cBarbedShotCritValue
    cBarbedShotInstantAoEDmg = cBarbedShotInstantAoEDmg * cBarbedShotCritValue
    cBarbedShotDotDmgAoE = cBarbedShotDotDmgAoE * cBarbedShotCritValue

    local cBarbedShotDmg = cBarbedShotInstantDmg + cBarbedShotDotDmg + cBarbedShotInstantAoEDmg + cBarbedShotDotDmgAoE

    local mechanicPrio = false
    if wan.traitData.ThrilloftheHunt.known then
        local checkThrillOfTheHuntBuff = wan.auraData.player.buff_ThrilloftheHunt
        if not checkThrillOfTheHuntBuff then
            mechanicPrio = true
        else
            local expirationTime = checkThrillOfTheHuntBuff.expirationTime - GetTime()

            if expirationTime < 2.5 then
                mechanicPrio = true
            end
        end
    end

    local abilityValue = not mechanicPrio and math.floor(cBarbedShotDmg) or 0
    local mechanicValue = mechanicPrio and math.floor(cBarbedShotDmg) or 0
    wan.UpdateAbilityData(wan.spellData.BarbedShot.basename, abilityValue, wan.spellData.BarbedShot.icon, wan.spellData.BarbedShot.name)
    wan.UpdateMechanicData(wan.spellData.BarbedShot.basename, mechanicValue, wan.spellData.BarbedShot.icon, wan.spellData.BarbedShot.name)
end

-- Init frame 
local frameBarbedShot = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nBarbedShotDmg = wan.GetSpellDescriptionNumbers(wan.spellData.BarbedShot.id, { 1 })

            nStomp = wan.GetTraitDescriptionNumbers(wan.traitData.Stomp.entryid, { 1 })
        end
    end)
end
frameBarbedShot:RegisterEvent("ADDON_LOADED")
frameBarbedShot:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.BarbedShot.known and wan.spellData.BarbedShot.id
        wan.BlizzardEventHandler(frameBarbedShot, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameBarbedShot, CheckAbilityValue, abilityActive)

        checkDebuffs = {
            wan.traitData.Laceration.traitkey,
            "SerpentSting",
            wan.traitData.Bloodshed.traitkey,
            wan.traitData.BlackArrow.traitkey,
        }
    end

    if event == "TRAIT_DATA_READY" then
        nFuriousAssault = wan.GetTraitDescriptionNumbers(wan.traitData.FuriousAssault.entryid, { 1 }) * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameBarbedShot, CheckAbilityValue, abilityActive)
    end
end)