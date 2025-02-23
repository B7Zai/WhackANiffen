local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nBlazingBarrier = 0

-- Init trait data


-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status
        or (wan.PlayerState.Resting and not wan.PlayerState.Combat)
        or not wan.IsSpellUsable(wan.spellData.BlazingBarrier.id)
    then
        wan.UpdateMechanicData(wan.spellData.BlazingBarrier.basename)
        return
    end

    local formattedBuffName = wan.spellData.BlazingBarrier.basename
    local checkBlazingBarrierBuff = wan.CheckUnitBuff(nil, formattedBuffName)
    local bBlazingBarrierDesaturation = false
    if checkBlazingBarrierBuff then
        local checkTime = GetTime()
        local nBarrierDurationThreshold = checkBlazingBarrierBuff.duration / 4
        local nBarrierRemainingTime = checkBlazingBarrierBuff.expirationTime - checkTime
        if nBarrierRemainingTime > nBarrierDurationThreshold then
            wan.UpdateMechanicData(wan.spellData.BlazingBarrier.basename)
            return
        end

        bBlazingBarrierDesaturation = true
    end

    -- Base values
    local cBarrier = nBlazingBarrier

    local nAbilityValue = math.floor(cBarrier)

    wan.UpdateMechanicData(wan.spellData.BlazingBarrier.basename, nAbilityValue, wan.spellData.BlazingBarrier.icon, wan.spellData.BlazingBarrier.name, bBlazingBarrierDesaturation)
end


local frameBlazingBarrier = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED"then
            nBlazingBarrier = wan.GetSpellDescriptionNumbers(wan.spellData.BlazingBarrier.id, { 1 })

        end
    end)
end
frameBlazingBarrier:RegisterEvent("ADDON_LOADED")
frameBlazingBarrier:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.BlazingBarrier.known and wan.spellData.BlazingBarrier.id
        wan.BlizzardEventHandler(frameBlazingBarrier, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameBlazingBarrier, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameBlazingBarrier, CheckAbilityValue, abilityActive)
    end
end)
