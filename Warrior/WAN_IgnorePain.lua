local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init spell data
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nIgnorePain = 0

-- Init trait data

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.IgnorePain.id)
        or (not wan.CheckUnitBuff(nil, wan.spellData.ShieldBlock.formattedName) and wan.IsSpellUsable(wan.spellData.ShieldBlock.id))
    then
        wan.UpdateMechanicData(wan.spellData.IgnorePain.basename)
        return
    end

    local cIgnorePain = 0

    local isTanking = wan.IsTanking()
    local checkIgnorePainBuff = wan.CheckUnitBuff(nil, wan.spellData.IgnorePain.formattedName)
    local checkIgnorePainStacks = checkIgnorePainBuff and checkIgnorePainBuff.applications
    if isTanking and (not checkIgnorePainBuff or checkIgnorePainStacks < 30) then
        cIgnorePain = cIgnorePain + nIgnorePain
    end

    local abilityValue = math.floor(cIgnorePain)
    wan.UpdateMechanicData(wan.spellData.IgnorePain.basename, abilityValue, wan.spellData.IgnorePain.icon, wan.spellData.IgnorePain.name)
end


local frameIgnorePain = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED"then
            local nIgnorePainValue = wan.GetSpellDescriptionNumbers(wan.spellData.IgnorePain.id, { 1 })
            nIgnorePain = wan.AbilityPercentageToValue(nIgnorePainValue)
        end
    end)
end
frameIgnorePain:RegisterEvent("ADDON_LOADED")
frameIgnorePain:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.IgnorePain.known and wan.spellData.IgnorePain.id
        wan.BlizzardEventHandler(frameIgnorePain, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameIgnorePain, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameIgnorePain, CheckAbilityValue, abilityActive)
    end
end)
