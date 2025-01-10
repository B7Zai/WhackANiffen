local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local abilityActive = false
local nSalvo, nSalvoUnitCap, nSalvoMaxRange = 0, 0, 60

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.Salvo.id)
    then
        wan.UpdateMechanicData(wan.spellData.Salvo.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit ,idValidUnit = wan.ValidUnitBoolCounter(nil, nSalvoMaxRange)
    if countValidUnit <= nSalvoUnitCap then
        wan.UpdateMechanicData(wan.spellData.Salvo.basename)
        return
    end

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cSalvoDmg = nSalvo
    local cdPotency = wan.CheckOffensiveCooldownPotency(cSalvoDmg, isValidUnit, idValidUnit)

    -- Update ability data
    local abilityValue = cdPotency and math.floor(cSalvoDmg) or 0
    wan.UpdateMechanicData(wan.spellData.Salvo.basename, abilityValue, wan.spellData.Salvo.icon, wan.spellData.Salvo.name)
end

-- Init frame 
local frameSalvo = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nSalvo = wan.OffensiveCooldownToValue(wan.spellData.Salvo.id)
        end
    end)
end
frameSalvo:RegisterEvent("ADDON_LOADED")
frameSalvo:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Salvo.known and wan.spellData.Salvo.id
        wan.BlizzardEventHandler(frameSalvo, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameSalvo, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nSalvoUnitCap = wan.GetTraitDescriptionNumbers(wan.traitData.Salvo.entryid, { 1 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameSalvo, CheckAbilityValue, abilityActive)
    end
end)