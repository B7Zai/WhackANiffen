local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nWarriorOfElune, nWarriorofEluneMaxRange = 0, 40

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status 
        or wan.CheckUnitBuff(nil, wan.spellData.CatForm.formattedName)
        or wan.CheckUnitBuff(nil, wan.spellData.BearForm.formattedName)
        or not wan.IsSpellUsable(wan.spellData.WarriorofElune.id)
    then
        wan.UpdateMechanicData(wan.spellData.WarriorofElune.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nWarriorofEluneMaxRange)
    if countValidUnit == 0 then
        wan.UpdateMechanicData(wan.spellData.WarriorofElune.basename)
        return
    end

    -- Base value
    local cWarriorOfElune = nWarriorOfElune
    local cdPotency = wan.CheckOffensiveCooldownPotency(cWarriorOfElune, isValidUnit, idValidUnit)

    -- Update ability data
    local abilityValue = cdPotency and math.floor(cWarriorOfElune) or 0
    wan.UpdateMechanicData(wan.spellData.WarriorofElune.basename, abilityValue, wan.spellData.WarriorofElune.icon, wan.spellData.WarriorofElune.name)
end

-- Init frame 
local frameWarriorOfElune = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nWarriorOfElune = wan.OffensiveCooldownToValue(wan.spellData.WarriorofElune.id)
        end
    end)
end
frameWarriorOfElune:RegisterEvent("ADDON_LOADED")
frameWarriorOfElune:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.WarriorofElune.known and wan.spellData.WarriorofElune.id
        wan.BlizzardEventHandler(frameWarriorOfElune, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameWarriorOfElune, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameWarriorOfElune, CheckAbilityValue, abilityActive)
    end
end)