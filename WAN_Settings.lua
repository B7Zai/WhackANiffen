local _, wan = ...

_G["WhackANiffen"] = wan or {}
wan.UpdateRate = wan.UpdateRate or {}
wan.EventFrame = wan.EventFrame or CreateFrame("Frame")

-- Event handler function
local function OnEvent(self, event, addonname)
    if addonname == "WhackANiffen" then

        WhackANiffenDB = _G.WhackANiffenDB or {}
        _G.WhackANiffenDB = WhackANiffenDB
        wan.Options = WhackANiffenDB

        local category = Settings.RegisterVerticalLayoutCategory("Whack-A-Niffen")
        local subcategory = Settings.RegisterVerticalLayoutSubcategory(category, "Icon Display Settings");

        do -- toggle to show ability names on the frames
            wan.Options.ShowName = wan.Options.ShowName or {}
            wan.Options.ShowName.Toggle = wan.Options.ShowName.Toggle or false
            local function GetValueShowNameToggle() return wan.Options.ShowName.Toggle end
            local function SetValueShowNameToggle(value)
                wan.Options.ShowName.Toggle = value
                wan.CustomEvents("NAME_TEXT_TOGGLE")
            end
            local tooltipShowNameToggle = "Enable this to display the name of abilities."
            local settingShowNameToggle = Settings.RegisterProxySetting(
                category,
                "Show_Ability_Name_Toggle",
                Settings.VarType.Boolean,
                "Show Ability Names",
                wan.Options.ShowName.Toggle,
                GetValueShowNameToggle,
                SetValueShowNameToggle
            )

            local initShowNameToggle = Settings.CreateCheckbox(category, settingShowNameToggle, tooltipShowNameToggle)
        end

        do -- toggle to switch between updating on a tick timer or every frame with throttling, unlock update rate slider
            wan.Options.UpdateRate = wan.Options.UpdateRate or {}
            wan.Options.UpdateRate.Toggle = wan.Options.UpdateRate.Toggle or false
            local function GetValueUpdateRateToggle() return wan.Options.UpdateRate.Toggle end
            local function SetValueUpdateRateToggle(value)
                wan.Options.UpdateRate.Toggle = value
                wan.CustomEvents("CUSTOM_UPDATE_RATE_TOGGLE")
            end
            local tooltipUpdateRateToggle = "Switch to a more resource-intensive mode with a customizable update rate."
            local settingUpdateRateToggle = Settings.RegisterProxySetting(
                category,
                "Custom_Update_Rate_Toggle",
                Settings.VarType.Boolean,
                "Custom Update Rate",
                wan.Options.UpdateRate.Toggle,
                GetValueUpdateRateToggle,
                SetValueUpdateRateToggle
            )

            local initUpdateRateToggle = Settings.CreateCheckbox(category, settingUpdateRateToggle, tooltipUpdateRateToggle)

            local function IsParentSelectedUpdateRateToggle() return settingUpdateRateToggle:GetValue() end

            do -- slider that set the throttle timer while its updating on every frame
                wan.Options.UpdateRate.Slider = wan.Options.UpdateRate.Slider or 4
                local function GetValueUpdateRateSlider() return wan.Options.UpdateRate.Slider end
                local function SetValueUpdateRateSlider(value)
                    wan.Options.UpdateRate.Slider = value
                    wan.CustomEvents("CUSTOM_UPDATE_RATE_SLIDER")
                end
                local tooltipUpdateRateSlider =
                "Lowering this value may improve game performance but reduce accuracy. The setting determines how frequently the addon updates, by dividing the Global Cooldown values of abilities."
                local minValue, maxValue, stepValue = 1, 10, 0.5
                local settingUpdateRateSlider = Settings.RegisterProxySetting(
                    category,
                    "UPDATE_RATE_SLIDER",
                    Settings.VarType.Number,
                    "Update Rate",
                    wan.Options.UpdateRate.Slider,
                    GetValueUpdateRateSlider,
                    SetValueUpdateRateSlider
                )
                local optionsUpdateRateSlider = Settings.CreateSliderOptions(minValue, maxValue, stepValue)
                local initUpdateRateSlider = Settings.CreateSlider(category, settingUpdateRateSlider, optionsUpdateRateSlider, tooltipUpdateRateSlider)
                optionsUpdateRateSlider:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
                initUpdateRateSlider:SetParentInitializer(initUpdateRateToggle, IsParentSelectedUpdateRateToggle)
            end
        end

        do
            wan.Options.HealerMode = wan.Options.HealerMode or {}
            wan.Options.HealerMode.Toggle = wan.Options.HealerMode.Toggle or false
            local function GetValueHealerModeToggle() return wan.Options.HealerMode.Toggle end
            local function SetValueHealerModeToggle(value)
                wan.Options.HealerMode.Toggle = value
                wan.CustomEvents("HEALERMODE_FRAME_TOGGLE")
            end
            local tooltipHealerModeToggle = "Enables healing frames for non healer specializations."
            local settingHealerModeToggle = Settings.RegisterProxySetting(
                category,
                "Healer_Mode_Frame_Toggle",
                Settings.VarType.Boolean,
                "Healer Mode",
                wan.Options.HealerMode.Toggle,
                GetValueHealerModeToggle,
                SetValueHealerModeToggle
            )
            local initHealerModeToggle = Settings.CreateCheckbox(category, settingHealerModeToggle, tooltipHealerModeToggle)
        end

        -------- subcatergory settings
        -------- 
        --------
        --------
        --------
        --------
        --------
        --------
        --------

        do -- toggle for the damage frame to enable dragging and enable further customization
            wan.Options.Damage = wan.Options.Damage or {}
            wan.Options.Damage.Toggle = wan.Options.Damage.Toggle or false
            local function GetValueDamageToggle() return wan.Options.Damage.Toggle end
            local function SetValueDamageToggle(value)
                wan.Options.Damage.Toggle = value
                wan.CustomEvents("DAMAGE_FRAME_TOGGLE")
            end
            local tooltipDamageToggle = "Enables dragging and unlocks settings for the Damage Priority display."
            local settingDamageToggle = Settings.RegisterProxySetting(
                subcategory,
                "Damage_Frame_Toggle",
                Settings.VarType.Boolean,
                "Unlock Damage Frame",
                wan.Options.Damage.Toggle,
                GetValueDamageToggle,
                SetValueDamageToggle
            )
            local initDamageToggle = Settings.CreateCheckbox(subcategory, settingDamageToggle, tooltipDamageToggle)

            local function IsParentSelectedDamageToggle() return settingDamageToggle:GetValue() end
            do
                -- Transparency Slider
                wan.Options.Damage.AlphaSlider = wan.Options.Damage.AlphaSlider or 0.75
                local function GetValueDamageAlphaSlider() return wan.Options.Damage.AlphaSlider end
                local function SetValueDamageAlphaSlider(value) wan.Options.Damage.AlphaSlider = value end
                local tooltipDamageAlphaSlider = "Sets how visible the frame appears."
                local minValue, maxValue, stepValue = 0, 1, 0.01
                local settingDamageAlphaSlider = Settings.RegisterProxySetting(
                    subcategory,
                    "Damage_Frame_Alpha_Slider",
                    Settings.VarType.Number,
                    "Visibility",
                    wan.Options.Damage.AlphaSlider,
                    GetValueDamageAlphaSlider,
                    SetValueDamageAlphaSlider
                )
                local optionsDamageAlphaSlider = Settings.CreateSliderOptions(minValue, maxValue, stepValue)
                local initDamageAlphaSlider = Settings.CreateSlider(subcategory, settingDamageAlphaSlider, optionsDamageAlphaSlider, tooltipDamageAlphaSlider)
                optionsDamageAlphaSlider:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatPercentage)
                initDamageAlphaSlider:SetParentInitializer(initDamageToggle, IsParentSelectedDamageToggle)
            end

            do
                -- Horizontal Position Slider
                wan.Options.Damage.HorizontalPosition = wan.Options.Damage.HorizontalPosition or 120
                local function GetValueDamageHorizontalPosition() return wan.Options.Damage.HorizontalPosition end
                local function SetValueDamageHorizontalPosition(value)
                    wan.Options.Damage.HorizontalPosition = value
                    wan.CustomEvents("DAMAGE_FRAME_HORIZONTAL_SLIDER")
                end
                local tooltipDamageHorizontalPosition = "Manually adjust the frame's horizontal position."
                local minValue, maxValue, stepValue = -500, 500, 1
                local settingDamageHorizontalPosition = Settings.RegisterProxySetting(
                    subcategory,
                    "Damage_Frame_Horizontal_Position_Slider",
                    Settings.VarType.Number,
                    "Horizontal Position",
                    wan.Options.Damage.HorizontalPosition,
                    GetValueDamageHorizontalPosition,
                    SetValueDamageHorizontalPosition
                )
                local optionsDamageHorizontalPosition = Settings.CreateSliderOptions(minValue, maxValue, stepValue)
                local initDamageHorizontalPosition = Settings.CreateSlider(subcategory, settingDamageHorizontalPosition, optionsDamageHorizontalPosition, tooltipDamageHorizontalPosition)
                optionsDamageHorizontalPosition:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, wan.FormatDecimalNumbers)
                initDamageHorizontalPosition:SetParentInitializer(initDamageToggle, IsParentSelectedDamageToggle)
            end

            do
                -- Vertical Position Slider
                wan.Options.Damage.VerticalPosition = wan.Options.Damage.VerticalPosition or -30
                local function GetValueDamageVerticalPosition() return wan.Options.Damage.VerticalPosition end
                local function SetValueDamageVerticalPosition(value)
                    wan.Options.Damage.VerticalPosition = value
                    wan.CustomEvents("DAMAGE_FRAME_VERTICAL_SLIDER")
                end
                local tooltipDamageVerticalPosition = "Manually adjust the frame's vertical position."
                local minValue, maxValue, stepValue = -500, 500, 1
                local settingDamageVerticalPosition = Settings.RegisterProxySetting(
                    subcategory,
                    "Damage_Frame_Vertical_Position_Slider",
                    Settings.VarType.Number,
                    "Vertical Position",
                    wan.Options.Damage.VerticalPosition,
                    GetValueDamageVerticalPosition,
                    SetValueDamageVerticalPosition
                )
                local optionsDamageVerticalPosition = Settings.CreateSliderOptions(minValue, maxValue, stepValue)
                local initDamageVerticalPosition = Settings.CreateSlider(subcategory, settingDamageVerticalPosition, optionsDamageVerticalPosition, tooltipDamageVerticalPosition)
                optionsDamageVerticalPosition:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, wan.FormatDecimalNumbers)
                initDamageVerticalPosition:SetParentInitializer(initDamageToggle, IsParentSelectedDamageToggle)
            end

            do
                -- Out of Combat Transparency Slider
                wan.Options.Damage.CombatAlphaSlider = wan.Options.Damage.CombatAlphaSlider or 0.4
                local function GetValueDamageCombatAlphaSlider() return wan.Options.Damage.CombatAlphaSlider end
                local function SetValueDamageCombatAlphaSlider(value) wan.Options.Damage.CombatAlphaSlider = value end
                local tooltipDamageCombatAlphaSlider = "Sets how visible the frame appears outside combat."
                local minValue, maxValue, stepValue = 0, 1, 0.01
                local settingDamageCombatAlphaSlider = Settings.RegisterProxySetting(
                    subcategory,
                    "Damage_Frame_Combat_Alpha_Slider",
                    Settings.VarType.Number,
                    "Visiblity Outside Combat",
                    wan.Options.Damage.CombatAlphaSlider,
                    GetValueDamageCombatAlphaSlider,
                    SetValueDamageCombatAlphaSlider
                )
                local optionsDamageCombatAlphaSlider = Settings.CreateSliderOptions(minValue, maxValue, stepValue)
                local initDamageCombatAlphaSlider = Settings.CreateSlider(subcategory, settingDamageCombatAlphaSlider, optionsDamageCombatAlphaSlider, tooltipDamageCombatAlphaSlider)
                optionsDamageCombatAlphaSlider:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatPercentage)
                initDamageCombatAlphaSlider:SetParentInitializer(initDamageToggle, IsParentSelectedDamageToggle)
            end
        end


        -- Mechanic Frame Toggle
        do
            wan.Options.Mechanic = wan.Options.Mechanic or {}
            wan.Options.Mechanic.Toggle = wan.Options.Mechanic.Toggle or false
            local function GetValueMechanicToggle() return wan.Options.Mechanic.Toggle end
            local function SetValueMechanicToggle(value)
                wan.Options.Mechanic.Toggle = value
                wan.CustomEvents("MECHANIC_FRAME_TOGGLE")
            end
            local tooltipMechanicToggle = "Enables dragging and unlocks settings for the Mechanic Priority display."
            local settingMechanicToggle = Settings.RegisterProxySetting(
                subcategory,
                "Mechanic_Frame_Toggle",
                Settings.VarType.Boolean,
                "Unlock Mechanics Frame",
                wan.Options.Mechanic.Toggle,
                GetValueMechanicToggle,
                SetValueMechanicToggle
            )

            local initMechanicToggle = Settings.CreateCheckbox(subcategory, settingMechanicToggle, tooltipMechanicToggle)

            local function IsParentSelectedMechanicToggle() return settingMechanicToggle:GetValue() end
            do
                -- Transparency Slider
                wan.Options.Mechanic.AlphaSlider = wan.Options.Mechanic.AlphaSlider or 0.75
                local function GetValueMechanicAlphaSlider() return wan.Options.Mechanic.AlphaSlider end
                local function SetValueMechanicAlphaSlider(value) wan.Options.Mechanic.AlphaSlider = value end
                local tooltipMechanicAlphaSlider = "Sets how visible the frame appears."
                local minValue, maxValue, stepValue = 0, 1, 0.01
                local settingMechanicAlphaSlider = Settings.RegisterProxySetting(
                    subcategory,
                    "Mechanic_Frame_Alpha_Slider",
                    Settings.VarType.Number,
                    "Visibility",
                    wan.Options.Mechanic.AlphaSlider,
                    GetValueMechanicAlphaSlider,
                    SetValueMechanicAlphaSlider
                )
                local optionsMechanicAlphaSlider = Settings.CreateSliderOptions(minValue, maxValue, stepValue)
                local initMechanicAlphaSlider = Settings.CreateSlider(subcategory, settingMechanicAlphaSlider, optionsMechanicAlphaSlider, tooltipMechanicAlphaSlider)
                optionsMechanicAlphaSlider:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatPercentage)
                initMechanicAlphaSlider:SetParentInitializer(initMechanicToggle, IsParentSelectedMechanicToggle)
            end

            do
                -- Horizontal Position Slider
                wan.Options.Mechanic.HorizontalPosition = wan.Options.Mechanic.HorizontalPosition or 190
                local function GetValueMechanicHorizontalPosition() return wan.Options.Mechanic.HorizontalPosition end
                local function SetValueMechanicHorizontalPosition(value)
                    wan.Options.Mechanic.HorizontalPosition = value
                    wan.CustomEvents("MECHANIC_FRAME_HORIZONTAL_SLIDER")
                end
                local tooltipMechanicHorizontalPosition = "Manually adjust the frame's horizontal position."
                local minValue, maxValue, stepValue = -500, 500, 1
                local settingMechanicHorizontalPosition = Settings.RegisterProxySetting(
                    subcategory,
                    "Mechanic_Frame_Horizontal_Position_Slider",
                    Settings.VarType.Number,
                    "Horizontal Position",
                    wan.Options.Mechanic.HorizontalPosition,
                    GetValueMechanicHorizontalPosition,
                    SetValueMechanicHorizontalPosition
                )
                local optionsMechanicHorizontalPosition = Settings.CreateSliderOptions(minValue, maxValue, stepValue)
                local initMechanicHorizontalPosition = Settings.CreateSlider(subcategory, settingMechanicHorizontalPosition, optionsMechanicHorizontalPosition, tooltipMechanicHorizontalPosition)
                optionsMechanicHorizontalPosition:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, wan.FormatDecimalNumbers)
                initMechanicHorizontalPosition:SetParentInitializer(initMechanicToggle, IsParentSelectedMechanicToggle)
            end

            do
                -- Vertical Position Slider
                wan.Options.Mechanic.VerticalPosition = wan.Options.Mechanic.VerticalPosition or -30
                local function GetValueMechanicVerticalPosition() return wan.Options.Mechanic.VerticalPosition end
                local function SetValueMechanicVerticalPosition(value)
                    wan.Options.Mechanic.VerticalPosition = value
                    wan.CustomEvents("MECHANIC_FRAME_VERTICAL_SLIDER")
                end
                local tooltipMechanicVerticalPosition = "Manually adjust the frame's vertical position."
                local minValue, maxValue, stepValue = -500, 500, 1
                local settingMechanicVerticalPosition = Settings.RegisterProxySetting(
                    subcategory,
                    "Mechanic_Frame_Vertical_Position_Slider",
                    Settings.VarType.Number,
                    "Vertical Position",
                    wan.Options.Mechanic.VerticalPosition,
                    GetValueMechanicVerticalPosition,
                    SetValueMechanicVerticalPosition
                )
                local optionsMechanicVerticalPosition = Settings.CreateSliderOptions(minValue, maxValue, stepValue)
                local initMechanicVerticalPosition = Settings.CreateSlider(subcategory, settingMechanicVerticalPosition, optionsMechanicVerticalPosition, tooltipMechanicVerticalPosition)
                optionsMechanicVerticalPosition:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, wan.FormatDecimalNumbers)
                initMechanicVerticalPosition:SetParentInitializer(initMechanicToggle, IsParentSelectedMechanicToggle)
            end

            do
                -- Out of Combat Transparency Slider
                wan.Options.Mechanic.CombatAlphaSlider = wan.Options.Mechanic.CombatAlphaSlider or 0.4
                local function GetValueMechanicCombatAlphaSlider() return wan.Options.Mechanic.CombatAlphaSlider end
                local function SetValueMechanicCombatAlphaSlider(value) wan.Options.Mechanic.CombatAlphaSlider = value end
                local tooltipMechanicCombatAlphaSlider = "Sets how visible the frame appears outside combat."
                local minValue, maxValue, stepValue = 0, 1, 0.01
                local settingMechanicCombatAlphaSlider = Settings.RegisterProxySetting(
                    subcategory,
                    "Mechanic_Frame_Combat_Alpha_Slider",
                    Settings.VarType.Number,
                    "Visibility Outside Combat",
                    wan.Options.Mechanic.CombatAlphaSlider,
                    GetValueMechanicCombatAlphaSlider ,
                    SetValueMechanicCombatAlphaSlider
                )
                local optionsMechanicCombatAlphaSlider = Settings.CreateSliderOptions(minValue, maxValue, stepValue)
                local initMechanicCombatAlphaSlider = Settings.CreateSlider(subcategory, settingMechanicCombatAlphaSlider, optionsMechanicCombatAlphaSlider, tooltipMechanicCombatAlphaSlider)
                optionsMechanicCombatAlphaSlider:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatPercentage)
                initMechanicCombatAlphaSlider:SetParentInitializer(initMechanicToggle, IsParentSelectedMechanicToggle)
            end
        end

        do -- toggle for the heal frame to enable dragging and enable further customization
            wan.Options.Heal = wan.Options.Heal or {}
            wan.Options.Heal.Toggle = wan.Options.Heal.Toggle or false
            local function GetValueHealToggle() return wan.Options.Heal.Toggle end
            local function SetValueHealToggle(value)
                wan.Options.Heal.Toggle = value
                wan.CustomEvents("Heal_FRAME_TOGGLE")
            end
            local tooltipHealToggle = "Enables dragging and unlocks settings for the Heal Priority display."
            local settingHealToggle = Settings.RegisterProxySetting(
                subcategory,
                "Heal_Frame_Toggle",
                Settings.VarType.Boolean,
                "Unlock Healing Frames",
                wan.Options.Heal.Toggle,
                GetValueHealToggle,
                SetValueHealToggle
            )
            local initHealToggle = Settings.CreateCheckbox(subcategory, settingHealToggle, tooltipHealToggle)

            local function IsParentSelectedHealToggle() return settingHealToggle:GetValue() end
            do
                -- Transparency Slider
                wan.Options.Heal.AlphaSlider = wan.Options.Heal.AlphaSlider or 0.75
                local function GetValueHealAlphaSlider() return wan.Options.Heal.AlphaSlider end
                local function SetValueHealAlphaSlider(value) wan.Options.Heal.AlphaSlider = value end
                local tooltipHealAlphaSlider = "Sets how visible the frame appears."
                local minValue, maxValue, stepValue = 0, 1, 0.01
                local settingHealAlphaSlider = Settings.RegisterProxySetting(
                    subcategory,
                    "Heal_Frame_Alpha_Slider",
                    Settings.VarType.Number,
                    "Visibility",
                    wan.Options.Heal.AlphaSlider,
                    GetValueHealAlphaSlider,
                    SetValueHealAlphaSlider
                )
                local optionsHealAlphaSlider = Settings.CreateSliderOptions(minValue, maxValue, stepValue)
                local initHealAlphaSlider = Settings.CreateSlider(subcategory, settingHealAlphaSlider, optionsHealAlphaSlider, tooltipHealAlphaSlider)
                optionsHealAlphaSlider:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatPercentage)
                initHealAlphaSlider:SetParentInitializer(initHealToggle, IsParentSelectedHealToggle)
            end

            do
                -- Horizontal Position Slider
                wan.Options.Heal.HorizontalPosition = wan.Options.Heal.HorizontalPosition or 120
                local function GetValueHealHorizontalPosition() return wan.Options.Heal.HorizontalPosition end
                local function SetValueHealHorizontalPosition(value)
                    wan.Options.Heal.HorizontalPosition = value
                    wan.CustomEvents("Heal_FRAME_HORIZONTAL_SLIDER")
                end
                local tooltipHealHorizontalPosition = "Manually adjust the frame's horizontal position."
                local minValue, maxValue, stepValue = -500, 500, 1
                local settingHealHorizontalPosition = Settings.RegisterProxySetting(
                    subcategory,
                    "Heal_Frame_Horizontal_Position_Slider",
                    Settings.VarType.Number,
                    "Horizontal Position",
                    wan.Options.Heal.HorizontalPosition,
                    GetValueHealHorizontalPosition,
                    SetValueHealHorizontalPosition
                )
                local optionsHealHorizontalPosition = Settings.CreateSliderOptions(minValue, maxValue, stepValue)
                local initHealHorizontalPosition = Settings.CreateSlider(subcategory, settingHealHorizontalPosition, optionsHealHorizontalPosition, tooltipHealHorizontalPosition)
                optionsHealHorizontalPosition:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, wan.FormatDecimalNumbers)
                initHealHorizontalPosition:SetParentInitializer(initHealToggle, IsParentSelectedHealToggle)
            end

            do
                -- Vertical Position Slider
                wan.Options.Heal.VerticalPosition = wan.Options.Heal.VerticalPosition or -30
                local function GetValueHealVerticalPosition() return wan.Options.Heal.VerticalPosition end
                local function SetValueHealVerticalPosition(value)
                    wan.Options.Heal.VerticalPosition = value
                    wan.CustomEvents("Heal_FRAME_VERTICAL_SLIDER")
                end
                local tooltipHealVerticalPosition = "Manually adjust the frame's vertical position."
                local minValue, maxValue, stepValue = -500, 500, 1
                local settingHealVerticalPosition = Settings.RegisterProxySetting(
                    subcategory,
                    "Heal_Frame_Vertical_Position_Slider",
                    Settings.VarType.Number,
                    "Vertical Position",
                    wan.Options.Heal.VerticalPosition,
                    GetValueHealVerticalPosition,
                    SetValueHealVerticalPosition
                )
                local optionsHealVerticalPosition = Settings.CreateSliderOptions(minValue, maxValue, stepValue)
                local initHealVerticalPosition = Settings.CreateSlider(subcategory, settingHealVerticalPosition, optionsHealVerticalPosition, tooltipHealVerticalPosition)
                optionsHealVerticalPosition:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, wan.FormatDecimalNumbers)
                initHealVerticalPosition:SetParentInitializer(initHealToggle, IsParentSelectedHealToggle)
            end

            do
                -- Out of Combat Transparency Slider
                wan.Options.Heal.CombatAlphaSlider = wan.Options.Heal.CombatAlphaSlider or 0.4
                local function GetValueHealCombatAlphaSlider() return wan.Options.Heal.CombatAlphaSlider end
                local function SetValueHealCombatAlphaSlider(value) wan.Options.Heal.CombatAlphaSlider = value end
                local tooltipHealCombatAlphaSlider = "Sets how visible the frame appears outside combat."
                local minValue, maxValue, stepValue = 0, 1, 0.01
                local settingHealCombatAlphaSlider = Settings.RegisterProxySetting(
                    subcategory,
                    "Heal_Frame_Combat_Alpha_Slider",
                    Settings.VarType.Number,
                    "Visiblity Outside Combat",
                    wan.Options.Heal.CombatAlphaSlider,
                    GetValueHealCombatAlphaSlider,
                    SetValueHealCombatAlphaSlider
                )
                local optionsHealCombatAlphaSlider = Settings.CreateSliderOptions(minValue, maxValue, stepValue)
                local initHealCombatAlphaSlider = Settings.CreateSlider(subcategory, settingHealCombatAlphaSlider, optionsHealCombatAlphaSlider, tooltipHealCombatAlphaSlider)
                optionsHealCombatAlphaSlider:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatPercentage)
                initHealCombatAlphaSlider:SetParentInitializer(initHealToggle, IsParentSelectedHealToggle)
            end
        end

        Settings.RegisterAddOnCategory(category)

        SLASH_WANOPTION1 = "/wan"
        SlashCmdList["WANOPTION"] = function()
            Settings.OpenToCategory(category:GetID(), "Whack-A-Niffen")
        end

        SLASH_WANDISPLAY1 = "/wanmove"
        SlashCmdList["WANDISPLAY"] = function()
            Settings.OpenToCategory(subcategory:GetID(), "Icon Display Settings")
        end

    end
end

local settingsFrame = CreateFrame("Frame")
settingsFrame:RegisterEvent("ADDON_LOADED")
settingsFrame:SetScript("OnEvent", OnEvent)