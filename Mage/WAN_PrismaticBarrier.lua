local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nPrismaticBarrier = 0

-- Init trait data


-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status
        or (wan.PlayerState.Resting and not wan.PlayerState.Combat)
        or not wan.IsSpellUsable(wan.spellData.PrismaticBarrier.id)
    then
        wan.UpdateMechanicData(wan.spellData.PrismaticBarrier.basename)
        return
    end

    local formattedBuffName = wan.spellData.PrismaticBarrier.basename
    local checkPrismaticBarrierBuff = wan.CheckUnitBuff(nil, formattedBuffName)
    local bPrismaticBarrierDesaturation = false
    if checkPrismaticBarrierBuff then
        local checkTime = GetTime()
        local nBarrierDurationThreshold = checkPrismaticBarrierBuff.duration / 4
        local nBarrierRemainingTime = checkPrismaticBarrierBuff.expirationTime - checkTime
        if nBarrierRemainingTime > nBarrierDurationThreshold then
            wan.UpdateMechanicData(wan.spellData.PrismaticBarrier.basename)
            return
        end

        bPrismaticBarrierDesaturation = true
    end

    -- Base values
    local cBarrier = nPrismaticBarrier

    local nAbilityValue = math.floor(cBarrier)

    wan.UpdateMechanicData(wan.spellData.PrismaticBarrier.basename, nAbilityValue, wan.spellData.PrismaticBarrier.icon, wan.spellData.PrismaticBarrier.name, bPrismaticBarrierDesaturation)
end


local framePrismaticBarrier = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED"then
            nPrismaticBarrier = wan.GetSpellDescriptionNumbers(wan.spellData.PrismaticBarrier.id, { 1 })

        end
    end)
end
framePrismaticBarrier:RegisterEvent("ADDON_LOADED")
framePrismaticBarrier:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.PrismaticBarrier.known and wan.spellData.PrismaticBarrier.id
        wan.BlizzardEventHandler(framePrismaticBarrier, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(framePrismaticBarrier, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(framePrismaticBarrier, CheckAbilityValue, abilityActive)
    end
end)
