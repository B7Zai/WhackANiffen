local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init data
local abilityActive = false
local nDireBeast, fDireBeast, fDireBeastPercentage = 0, 0, 0
local currentFocus, focusMax, focusPercentage = 0, 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or wan.auraData.player.buff_DireBeast
    or not wan.IsSpellUsable(wan.spellData.DireBeast.id)
    then
        wan.UpdateMechanicData(wan.spellData.DireBeast.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.DireBeast.id)
    if countValidUnit == 0 then
        wan.UpdateMechanicData(wan.spellData.DireBeast.basename)
        return
    end

    -- Energy check and early exit
    currentFocus = UnitPower("player", 2) or 0
    focusPercentage = (currentFocus / focusMax) * 100
    if focusPercentage >= (100 - fDireBeastPercentage)
    then
        wan.UpdateMechanicData(wan.spellData.DireBeast.basename)
        return
    end

    -- Base value
    local cDireBeast = nDireBeast
    local cdPotency = wan.CheckOffensiveCooldownPotency(cDireBeast, isValidUnit, idValidUnit)

    -- Update ability data
    local abilityValue = cdPotency and math.floor(cDireBeast) or 0
    wan.UpdateMechanicData(wan.spellData.DireBeast.basename, abilityValue, wan.spellData.DireBeast.icon, wan.spellData.DireBeast.name)
end

-- Init frame 
local frameDireBeast = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)

        if event == "SPELLS_CHANGED" then
            focusMax = UnitPowerMax("player", 2) or 100
        end

        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            fDireBeast = wan.GetSpellDescriptionNumbers(wan.spellData.DireBeast.id, { 3 })
            fDireBeastPercentage = (fDireBeast / focusMax) * 100
            nDireBeast = wan.OffensiveCooldownToValue(wan.spellData.DireBeast.id)
        end
    end)
end
frameDireBeast:RegisterEvent("ADDON_LOADED")
frameDireBeast:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.DireBeast.known and wan.spellData.DireBeast.id
        wan.BlizzardEventHandler(frameDireBeast, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameDireBeast, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameDireBeast, CheckAbilityValue, abilityActive)
    end
end)