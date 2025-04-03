local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DEMONHUNTER" then return end

-- Init spell data
local abilityActive = false
local nVengefulRetreat = 0
local currentPower, currentPowerPercentage = 0, 0
local checkMaxPower = 0

-- Init trait data
local sDarknessBuff = "Darkness"
local bTacticalRetreat, nTactivalRetreatPowerGain = false, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or (bTacticalRetreat and ((checkMaxPower - currentPower) < nTactivalRetreatPowerGain))
        or wan.CheckUnitBuff(nil, sDarknessBuff)
        or not wan.IsSpellUsable(wan.spellData.VengefulRetreat.id)
    then
        wan.UpdateMechanicData(wan.spellData.VengefulRetreat.basename)
        return
    end

    local cVengefulRetreatDmg = nVengefulRetreat

    local abilityValue = math.floor(cVengefulRetreatDmg)
    wan.UpdateMechanicData(wan.spellData.VengefulRetreat.basename, abilityValue, wan.spellData.VengefulRetreat.icon, wan.spellData.VengefulRetreat.name)
end

-- Init frame 
local frameVengefulRetreat = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)

        if event == "SPELLS_CHANGED" then
            checkMaxPower = wan.CheckUnitMaxPower("player", 17) or wan.CheckUnitMaxPower("player", 18) or 0
            currentPower = wan.CheckUnitPower("player", 17) or wan.CheckUnitPower("player", 18) or 0
        end

        if event == "UNIT_POWER_UPDATE" then
            local unitID, powerType = ...
            if unitID == "player" and (powerType == "FURY" or powerType == "PAIN") then
                currentPower = wan.CheckUnitPower("player", 17) or wan.CheckUnitPower("player", 18) or 0
            end
        end

        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nVengefulRetreat = wan.DefensiveCooldownToValue(wan.spellData.VengefulRetreat.id)

            sDarknessBuff = wan.spellData.Darkness.formattedName
        end
    end)
end
frameVengefulRetreat:RegisterEvent("ADDON_LOADED")
frameVengefulRetreat:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = bTacticalRetreat and not wan.spellData.VengefulRetreat.isPassive and wan.spellData.VengefulRetreat.known and wan.spellData.VengefulRetreat.id
        wan.BlizzardEventHandler(frameVengefulRetreat, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED", "UNIT_POWER_UPDATE")
        wan.SetUpdateRate(frameVengefulRetreat, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then

        bTacticalRetreat = wan.traitData.TacticalRetreat.known
        nTactivalRetreatPowerGain = wan.GetTraitDescriptionNumbers(wan.traitData.TacticalRetreat.entryid, { 2 }, wan.traitData.TacticalRetreat.rank) * 0.5
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameVengefulRetreat, CheckAbilityValue, abilityActive)
    end
end)