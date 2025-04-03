local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DEMONHUNTER" then return end

-- Init spell data
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nDemonSpikes = 0

-- Init trait data

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.DemonSpikes.id)
    then
        wan.UpdateMechanicData(wan.spellData.DemonSpikes.basename)
        return
    end

    local cDemonSpikes = 0

    local currentTime = GetTime()
    local isTanking = wan.IsTanking()
    local checkDemonSpikesBuff = wan.CheckUnitBuff(nil, wan.spellData.DemonSpikes.formattedName)
    local cDemonSpikesExpiration = checkDemonSpikesBuff and checkDemonSpikesBuff.expirationTime - currentTime or 0

    if isTanking and (not checkDemonSpikesBuff or cDemonSpikesExpiration < 1.2) then
        cDemonSpikes = cDemonSpikes + nDemonSpikes
    end

    local abilityValue = math.floor(cDemonSpikes)
    wan.UpdateMechanicData(wan.spellData.DemonSpikes.basename, abilityValue, wan.spellData.DemonSpikes.icon, wan.spellData.DemonSpikes.name)
end


local frameDemonSpikes = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED"then
            local nDemonSpikesValue = wan.GetSpellDescriptionNumbers(wan.spellData.DemonSpikes.id, { 1 })
            local checkPhysicalDR = wan.GetArmorDamageReductionFromSpell(nDemonSpikesValue)
            nDemonSpikes = wan.AbilityPercentageToValue(checkPhysicalDR)
        end
    end)
end
frameDemonSpikes:RegisterEvent("ADDON_LOADED")
frameDemonSpikes:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.DemonSpikes.known and wan.spellData.DemonSpikes.id
        wan.BlizzardEventHandler(frameDemonSpikes, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameDemonSpikes, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameDemonSpikes, CheckAbilityValue, abilityActive)
    end
end)
