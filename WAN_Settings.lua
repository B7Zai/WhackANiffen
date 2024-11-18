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

        do
            wan.Options.Damage = wan.Options.Damage or {}
            wan.Options.Damage.Toggle = wan.Options.Damage.Toggle or false
            local function GetValueC1() return wan.Options.Damage.Toggle end
            local function SetValueC1(value)
                wan.Options.Damage.Toggle = value
                wan.CustomEvents("DAMAGE_FRAME_TOGGLE")
            end
            local tooltipC1 = "Enables dragging and unlocks settings for the Damage Priority display."
            local settingC1 = Settings.RegisterProxySetting(
                category,
                "Damage_Frame_Toggle",
                Settings.VarType.Boolean,
                "Unlock Damage Frame",
                wan.Options.Damage.Toggle,
                GetValueC1,
                SetValueC1
            )
            local initC1 = Settings.CreateCheckbox(category, settingC1, tooltipC1)

            local function IsParentSelectedC1() return settingC1:GetValue() end
            do
                -- Transparency Slider
                wan.Options.Damage.AlphaSlider = wan.Options.Damage.AlphaSlider or 0.75
                local function GetValueC1S1() return wan.Options.Damage.AlphaSlider end
                local function SetValueC1S1(value) wan.Options.Damage.AlphaSlider = value end
                local tooltipS1 = "Sets how visible the frame appears."
                local minValue, maxValue, stepValue = 0, 1, 0.01
                local settingS1 = Settings.RegisterProxySetting(
                    category,
                    "Damage_Frame_Alpha_Slider",
                    Settings.VarType.Number,
                    "Visibility",
                    wan.Options.Damage.AlphaSlider,
                    GetValueC1S1,
                    SetValueC1S1
                )
                local optionsS1 = Settings.CreateSliderOptions(minValue, maxValue, stepValue)
                local initS1 = Settings.CreateSlider(category, settingS1, optionsS1, tooltipS1)
                optionsS1:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatPercentage)
                initS1:SetParentInitializer(initC1, IsParentSelectedC1)
            end

            do
                -- Horizontal Position Slider
                wan.Options.Damage.HorizontalPosition = wan.Options.Damage.HorizontalPosition or 120
                local function GetValueC1S2() return wan.Options.Damage.HorizontalPosition end
                local function SetValueC1S2(value)
                    wan.Options.Damage.HorizontalPosition = value
                    wan.CustomEvents("DAMAGE_FRAME_HORIZONTAL_SLIDER")
                end
                local tooltipS2 = "Manually adjust the frame's horizontal position."
                local minValue, maxValue, stepValue = -500, 500, 1
                local settingS2 = Settings.RegisterProxySetting(
                    category,
                    "Damage_Frame_Horizontal_Position_Slider",
                    Settings.VarType.Number,
                    "Horizontal Position",
                    wan.Options.Damage.HorizontalPosition,
                    GetValueC1S2,
                    SetValueC1S2
                )
                local optionsS2 = Settings.CreateSliderOptions(minValue, maxValue, stepValue)
                local initS2 = Settings.CreateSlider(category, settingS2, optionsS2, tooltipS2)
                optionsS2:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, wan.FormatDecimalNumbers)
                initS2:SetParentInitializer(initC1, IsParentSelectedC1)
            end

            do
                -- Vertical Position Slider
                wan.Options.Damage.VerticalPosition = wan.Options.Damage.VerticalPosition or -30
                local function GetValueC1S3() return wan.Options.Damage.VerticalPosition end
                local function SetValueC1S3(value)
                    wan.Options.Damage.VerticalPosition = value
                    wan.CustomEvents("DAMAGE_FRAME_VERTICAL_SLIDER")
                end
                local tooltipS3 = "Manually adjust the frame's vertical position."
                local minValue, maxValue, stepValue = -500, 500, 1
                local settingS3 = Settings.RegisterProxySetting(
                    category,
                    "Damage_Frame_Vertical_Position_Slider",
                    Settings.VarType.Number,
                    "Vertical Position",
                    wan.Options.Damage.VerticalPosition,
                    GetValueC1S3,
                    SetValueC1S3
                )
                local optionsS3 = Settings.CreateSliderOptions(minValue, maxValue, stepValue)
                local initS3 = Settings.CreateSlider(category, settingS3, optionsS3, tooltipS3)
                optionsS3:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, wan.FormatDecimalNumbers)
                initS3:SetParentInitializer(initC1, IsParentSelectedC1)
            end

            do
                -- Out of Combat Transparency Slider
                wan.Options.Damage.CombatAlphaSlider = wan.Options.Damage.CombatAlphaSlider or 0.4
                local function GetValueC1S4() return wan.Options.Damage.CombatAlphaSlider end
                local function SetValueC1S4(value) wan.Options.Damage.CombatAlphaSlider = value end
                local tooltipS4 = "Sets how visible the frame appears outside combat."
                local minValue, maxValue, stepValue = 0, 1, 0.01
                local settingS4 = Settings.RegisterProxySetting(
                    category,
                    "Damage_Frame_Combat_Alpha_Slider",
                    Settings.VarType.Number,
                    "Visiblity Outside Combat",
                    wan.Options.Damage.CombatAlphaSlider,
                    GetValueC1S4,
                    SetValueC1S4
                )
                local optionsS4 = Settings.CreateSliderOptions(minValue, maxValue, stepValue)
                local initS4 = Settings.CreateSlider(category, settingS4, optionsS4, tooltipS4)
                optionsS4:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatPercentage)
                initS4:SetParentInitializer(initC1, IsParentSelectedC1)
            end
        end


        -- Mechanic Frame Toggle
        do
            wan.Options.Mechanic = wan.Options.Mechanic or {}
            wan.Options.Mechanic.Toggle = wan.Options.Mechanic.Toggle or false
            local function GetValueC2() return wan.Options.Mechanic.Toggle end
            local function SetValueC2(value)
                wan.Options.Mechanic.Toggle = value
                wan.CustomEvents("MECHANIC_FRAME_TOGGLE")
            end
            local tooltipC2 = "Enables you to drag the frame that displays Mechanic Priority Icons."
            local settingC2 = Settings.RegisterProxySetting(
                category,
                "Mechanic_Frame_Toggle",
                Settings.VarType.Boolean,
                "Unlock Mechanics Frame",
                wan.Options.Mechanic.Toggle,
                GetValueC2,
                SetValueC2
            )

            local initC2 = Settings.CreateCheckbox(category, settingC2, tooltipC2)

            local function IsParentSelectedC2() return settingC2:GetValue() end
            do
                -- Transparency Slider
                wan.Options.Mechanic.AlphaSlider = wan.Options.Mechanic.AlphaSlider or 0.75
                local function GetValueC2S1() return wan.Options.Mechanic.AlphaSlider end
                local function SetValueC2S1(value) wan.Options.Mechanic.AlphaSlider = value end
                local tooltipS1 = "Sets how visible the frame appears."
                local minValue, maxValue, stepValue = 0, 1, 0.01
                local settingS1 = Settings.RegisterProxySetting(
                    category,
                    "Mechanic_Frame_Alpha_Slider",
                    Settings.VarType.Number,
                    "Visibility",
                    wan.Options.Mechanic.AlphaSlider,
                    GetValueC2S1,
                    SetValueC2S1
                )
                local optionsS1 = Settings.CreateSliderOptions(minValue, maxValue, stepValue)
                local initS1 = Settings.CreateSlider(category, settingS1, optionsS1, tooltipS1)
                optionsS1:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatPercentage)
                initS1:SetParentInitializer(initC2, IsParentSelectedC2)
            end

            do
                -- Horizontal Position Slider
                wan.Options.Mechanic.HorizontalPosition = wan.Options.Mechanic.HorizontalPosition or 190
                local function GetValueC2S2() return wan.Options.Mechanic.HorizontalPosition end
                local function SetValueC2S2(value)
                    wan.Options.Mechanic.HorizontalPosition = value
                    wan.CustomEvents("MECHANIC_FRAME_HORIZONTAL_SLIDER")
                end
                local tooltipS2 = "Manually adjust the frame's horizontal position."
                local minValue, maxValue, stepValue = -500, 500, 1
                local settingS2 = Settings.RegisterProxySetting(
                    category,
                    "Mechanic_Frame_Horizontal_Position_Slider",
                    Settings.VarType.Number,
                    "Horizontal Position",
                    wan.Options.Mechanic.HorizontalPosition,
                    GetValueC2S2,
                    SetValueC2S2
                )
                local optionsS2 = Settings.CreateSliderOptions(minValue, maxValue, stepValue)
                local initS2 = Settings.CreateSlider(category, settingS2, optionsS2, tooltipS2)
                optionsS2:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, wan.FormatDecimalNumbers)
                initS2:SetParentInitializer(initC2, IsParentSelectedC2)
            end

            do
                -- Vertical Position Slider
                wan.Options.Mechanic.VerticalPosition = wan.Options.Mechanic.VerticalPosition or -30
                local function GetValueC2S3() return wan.Options.Mechanic.VerticalPosition end
                local function SetValueC2S3(value)
                    wan.Options.Mechanic.VerticalPosition = value
                    wan.CustomEvents("MECHANIC_FRAME_VERTICAL_SLIDER")
                end
                local tooltipS3 = "Manually adjust the frame's vertical position."
                local minValue, maxValue, stepValue = -500, 500, 1
                local settingS3 = Settings.RegisterProxySetting(
                    category,
                    "Mechanic_Frame_Vertical_Position_Slider",
                    Settings.VarType.Number,
                    "Vertical Position",
                    wan.Options.Mechanic.VerticalPosition,
                    GetValueC2S3,
                    SetValueC2S3
                )
                local optionsS3 = Settings.CreateSliderOptions(minValue, maxValue, stepValue)
                local initS3 = Settings.CreateSlider(category, settingS3, optionsS3, tooltipS3)
                optionsS3:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, wan.FormatDecimalNumbers)
                initS3:SetParentInitializer(initC2, IsParentSelectedC2)
            end

            do
                -- Out of Combat Transparency Slider
                wan.Options.Mechanic.CombatAlphaSlider = wan.Options.Mechanic.CombatAlphaSlider or 0.4
                local function GetValueC2S4() return wan.Options.Mechanic.CombatAlphaSlider end
                local function SetValueC2S4(value) wan.Options.Mechanic.CombatAlphaSlider = value end
                local tooltipS4 = "Sets how visible the frame appears outside combat."
                local minValue, maxValue, stepValue = 0, 1, 0.01
                local settingS4 = Settings.RegisterProxySetting(
                    category,
                    "Mechanic_Frame_Combat_Alpha_Slider",
                    Settings.VarType.Number,
                    "Visibility Outside Combat",
                    wan.Options.Mechanic.CombatAlphaSlider,
                    GetValueC2S4,
                    SetValueC2S4
                )
                local optionsS4 = Settings.CreateSliderOptions(minValue, maxValue, stepValue)
                local initS4 = Settings.CreateSlider(category, settingS4, optionsS4, tooltipS4)
                optionsS4:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatPercentage)
                initS4:SetParentInitializer(initC2, IsParentSelectedC2)
            end
        end

        -- Custom Update Rate Toggle
        do
            wan.Options.UpdateRate = wan.Options.UpdateRate or {}
            wan.Options.UpdateRate.Toggle = wan.Options.UpdateRate.Toggle or false
            local function GetValueC3() return wan.Options.UpdateRate.Toggle end
            local function SetValueC3(value)
                wan.Options.UpdateRate.Toggle = value
                wan.CustomEvents("CUSTOM_UPDATE_RATE_TOGGLE")
            end
            local tooltipC3 = "Switch to a more resource-intensive mode with a customizable update rate."
            local settingC3 = Settings.RegisterProxySetting(
                category,
                "Custom_Update_Rate_Toggle",
                Settings.VarType.Boolean,
                "Custom Update Rate",
                wan.Options.UpdateRate.Toggle,
                GetValueC3,
                SetValueC3
            )

            local initC3 = Settings.CreateCheckbox(category, settingC3, tooltipC3)

            local function IsParentSelectedC3() return settingC3:GetValue() end
            do
                -- Update Rate Slider
                wan.Options.UpdateRate.Slider = wan.Options.UpdateRate.Slider or 4
                local function GetValueC3S1() return wan.Options.UpdateRate.Slider end
                local function SetValueC3S1(value)
                    wan.Options.UpdateRate.Slider = value
                    wan.CustomEvents("CUSTOM_UPDATE_RATE_SLIDER")
                end
                local tooltipS =
                "Lowering this value may improve game performance but reduce accuracy. The setting determines how frequently the addon updates, by dividing the Global Cooldown values of abilities."
                local minValue, maxValue, stepValue = 1, 10, 0.5
                local settingS = Settings.RegisterProxySetting(
                    category,
                    "UPDATE_RATE_SLIDER",
                    Settings.VarType.Number,
                    "Update Rate",
                    wan.Options.UpdateRate.Slider,
                    GetValueC3S1,
                    SetValueC3S1
                )
                local optionsS = Settings.CreateSliderOptions(minValue, maxValue, stepValue)
                local initS1 = Settings.CreateSlider(category, settingS, optionsS, tooltipS)
                optionsS:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
                initS1:SetParentInitializer(initC3, IsParentSelectedC3)
            end
        end

        do
            wan.Options.ShowName = wan.Options.ShowName or {}
            wan.Options.ShowName.Toggle = wan.Options.ShowName.Toggle or false
            local function GetValueC4() return wan.Options.ShowName.Toggle end
            local function SetValueC4(value)
                wan.Options.ShowName.Toggle = value
                wan.CustomEvents("NAME_TEXT_TOGGLE")
            end
            local tooltipC4 = "Enable this to display the name of abilities."
            local settingC4 = Settings.RegisterProxySetting(
                category,
                "Show_Ability_Name_Toggle",
                Settings.VarType.Boolean,
                "Show Ability Names",
                wan.Options.ShowName.Toggle,
                GetValueC4,
                SetValueC4
            )

            local initC4 = Settings.CreateCheckbox(category, settingC4, tooltipC4)
        end

        Settings.RegisterAddOnCategory(category)

        SLASH_WANOPTIONS1 = "/wan"
        SlashCmdList["WANOPTIONS"] = function()
            Settings.OpenToCategory(category:GetID(), "Whack-A-Niffen")
        end
    end
end

local settingsFrame = CreateFrame("Frame")
settingsFrame:RegisterEvent("ADDON_LOADED")
settingsFrame:SetScript("OnEvent", OnEvent)