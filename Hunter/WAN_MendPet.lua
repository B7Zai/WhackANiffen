local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local playerUnitToken = "player"
local petUnitToken = "pet"
local abilityActive = false
local nMendPetInstantHeal, nMendPetHotHeal = 0, 0

-- Init traid data
local nDenRecovery = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not UnitExists("pet")
    or not wan.IsSpellUsable(wan.spellData.MendPet.id)
    then
        wan.UpdateMechanicData(wan.spellData.MendPet.basename)
        return
    end

    local hotKeys = { wan.spellData.MendPet.basename, wan.traitData.DenRecovery.traitkey }
    local petGUID = wan.UnitState.GUID[petUnitToken]
    local currentPercentHealth = petGUID and UnitPercentHealthFromGUID(petGUID) or 1

    -- Base values
    local cMendPetInstantHeal = 0
    local cMendPetHotHeal = nMendPetHotHeal
    
    local hotPotency = wan.HotPotency(petUnitToken, currentPercentHealth)

    local cDenRecovery = 0
    if wan.traitData.DenRecovery.known then
        cDenRecovery = cDenRecovery + nDenRecovery
    end

    cMendPetHotHeal = cMendPetHotHeal * hotPotency
    cDenRecovery = cDenRecovery * hotPotency

    wan.HotValue[petUnitToken] = wan.HotValue[petUnitToken] or {}
    wan.HotValue[petUnitToken][wan.spellData.MendPet.basename] = cMendPetHotHeal
    wan.HotValue[petUnitToken][wan.traitData.DenRecovery.traitkey] = cDenRecovery

    local cMendPetHeal = cMendPetInstantHeal + cMendPetHotHeal + cDenRecovery

    local currentTime = GetTime()
    for _, auraKey in pairs(hotKeys) do
        local aura = wan.auraData[petUnitToken]["buff_" .. auraKey]
        if aura then
            local reminingDuration = aura.expirationTime - currentTime
            if reminingDuration < 0 then
                wan.auraData[petUnitToken]["buff_" .. auraKey] = nil
            else
                local hotValue = wan.HotValue[petUnitToken][auraKey]
                cMendPetHeal = cMendPetHeal - hotValue
            end
        end
    end

    -- update healing data
    local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cMendPetHeal, currentPercentHealth)
    wan.UpdateMechanicData(wan.spellData.MendPet.basename, abilityValue, wan.spellData.MendPet.icon, wan.spellData.MendPet.name)
end

-- Init frame 
local frameMendPet = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nMendPetValues = wan.GetSpellDescriptionNumbers(wan.spellData.MendPet.id, { 1 }) * 0.5
            nMendPetHotHeal = wan.UnitAbilityPercentageToValue(petUnitToken, nMendPetValues)
        end
    end)
end
frameMendPet:RegisterEvent("ADDON_LOADED")
frameMendPet:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.MendPet.known and wan.spellData.MendPet.id
        wan.BlizzardEventHandler(frameMendPet, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameMendPet, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        local nDenRecoveryValues = wan.GetTraitDescriptionNumbers(wan.traitData.DenRecovery.entryid, { 1 }) * 0.5
        nDenRecovery = wan.UnitAbilityPercentageToValue(petUnitToken, nDenRecoveryValues)
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameMendPet, CheckAbilityValue, abilityActive)
    end
end)
