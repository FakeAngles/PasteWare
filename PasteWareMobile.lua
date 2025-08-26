if not game:IsLoaded() then 
    game.Loaded:Wait()
end

if not syn or not protectgui then
    getgenv().protectgui = function() end
end

if bypass_adonis then
    task.spawn(function()
        local g = getinfo or debug.getinfo
        local d = false
        local h = {}

        local x, y

        setthreadidentity(2)

        for i, v in getgc(true) do
            if typeof(v) == "table" then
                local a = rawget(v, "Detected")
                local b = rawget(v, "Kill")
            
                if typeof(a) == "function" and not x then
                    x = a
                    local o; o = hookfunction(x, function(c, f, n)
                        if c ~= "_" then
                            if d then
                            end
                        end
                        
                        return true
                    end)
                    table.insert(h, x)
                end

                if rawget(v, "Variables") and rawget(v, "Process") and typeof(b) == "function" and not y then
                    y = b
                    local o; o = hookfunction(y, function(f)
                        if d then
                        end
                    end)
                    table.insert(h, y)
                end
            end
        end

        local o; o = hookfunction(getrenv().debug.info, newcclosure(function(...)
            local a, f = ...

            if x and a == x then
                if d then
                    warn(`zins | adonis bypassed`)
                end

                return coroutine.yield(coroutine.running())
            end
            
            return o(...)
        end))

        setthreadidentity(7)
    end)
end

if not getgenv().ScriptState then
    getgenv().ScriptState = {
        isLockedOn = false,
        targetPlayer = nil,
        lockEnabled = false,
        aimLockEnabled = false,
        smoothingFactor = 0.1,
        predictionFactor = 0.0,
        bodyPartSelected = "Head",
        ClosestHitPart = nil,
        previousHighlight = nil,
        lockedTime = 12,
        reverseResolveIntensity = 5,
        Desync = false,
        DesyncEnabled = false,
        antiLockEnabled = false,
        resolverIntensity = 1.0,
        resolverMethod = "Recalculate",
        shellNumber = 1,
        isTankSpamEnabled = false,
        spamSpeed = 1,
        shellsToFire = 1,
        masterToggle = false,
        fovEnabled = false,
        nebulaEnabled = false,
        fovValue = 70,
        SelfChamsEnabled = false,
        RainbowChamsEnabled = false,
        SelfChamsColor = Color3.fromRGB(255, 255, 255),
        ChamsEnabled = false,
        isSpeedActive = false,
        isFlyActive = false,
        isNoClipActive = false,
        isFunctionalityEnabled = true,
        flySpeed = 1,
        Cmultiplier = 1,
        strafeEnabled = false,
        strafeAllowed = true,
        strafeSpeed = 50,
        strafeRadius = 5,
        strafeMode = "Horizontal",
        originalCameraMode = nil
    }
end

local SilentAimSettings = {
    Enabled = false,
    
    ClassName = "PasteWare  |  github.com/FakeAngles",
    ToggleKey = "U",
    
    TeamCheck = false,
    TargetPart = "HumanoidRootPart",
    SilentAimMethod = "Raycast",
    
    FOVRadius = 130,
    FOVVisible = false,
    ShowSilentAimTarget = false, 
    
    HitChance = 100
}

getgenv().SilentAimSettings = Settings

local Camera = workspace.CurrentCamera
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local GetChildren = game.GetChildren
local GetPlayers = Players.GetPlayers
local WorldToScreen = Camera.WorldToScreenPoint
local WorldToViewportPoint = Camera.WorldToViewportPoint
local GetPartsObscuringTarget = Camera.GetPartsObscuringTarget
local FindFirstChild = game.FindFirstChild
local RenderStepped = RunService.RenderStepped
local GuiInset = GuiService.GetGuiInset
local GetMouseLocation = UserInputService.GetMouseLocation

local resume = coroutine.resume 
local create = coroutine.create

local ValidTargetParts = {"Head", "HumanoidRootPart"}
local PredictionAmount = 0.165

local fov_circle = Drawing.new("Circle")
fov_circle.Thickness = 1
fov_circle.NumSides = 100
fov_circle.Radius = 180
fov_circle.Filled = false
fov_circle.Visible = false
fov_circle.ZIndex = 999
fov_circle.Transparency = 1
fov_circle.Color = Color3.fromRGB(54, 57, 241)

local ExpectedArguments = {
    ViewportPointToRay = {
        ArgCountRequired = 2,
        Args = { "number", "number" }
    },
    ScreenPointToRay = {
        ArgCountRequired = 2,
        Args = { "number", "number" }
    },
    Raycast = {
        ArgCountRequired = 3,
        Args = { "Instance", "Vector3", "Vector3", "RaycastParams" }
    },
    FindPartOnRay = {
        ArgCountRequired = 2,
        Args = { "Ray", "Instance", "boolean", "boolean" }
    },
    FindPartOnRayWithIgnoreList = {
        ArgCountRequired = 3,
        Args = { "Ray", "table", "boolean", "boolean" }
    },
    FindPartOnRayWithWhitelist = { 
        ArgCountRequired = 3,
        Args = { "Ray", "table", "boolean", "boolean" }
    }
}


function CalculateChance(Percentage)

    Percentage = math.floor(Percentage)


    local chance = math.floor(Random.new().NextNumber(Random.new(), 0, 1) * 100) / 100


    return chance <= Percentage / 100
end


local function getPositionOnScreen(Vector)
    local Vec3, OnScreen = WorldToScreen(Camera, Vector)
    return Vector2.new(Vec3.X, Vec3.Y), OnScreen
end

local function ValidateArguments(Args, RayMethod)
    local Matches = 0
    if #Args < RayMethod.ArgCountRequired then
        return false
    end
    for Pos, Argument in next, Args do
        if typeof(Argument) == RayMethod.Args[Pos] then
            Matches = Matches + 1
        end
    end
    return Matches >= RayMethod.ArgCountRequired
end

local function getDirection(Origin, Position)
    return (Position - Origin).Unit * 1000
end

local function getMousePosition()
    return GetMouseLocation(UserInputService)
end

local function IsPlayerVisible(Player)
    local PlayerCharacter = Player.Character
    local LocalPlayerCharacter = LocalPlayer.Character
    
    if not (PlayerCharacter or LocalPlayerCharacter) then return end 
    
    local PlayerRoot = FindFirstChild(PlayerCharacter, Options.TargetPart.Value) or FindFirstChild(PlayerCharacter, "HumanoidRootPart")
    
    if not PlayerRoot then return end 
    
    local CastPoints, IgnoreList = {PlayerRoot.Position, LocalPlayerCharacter, PlayerCharacter}, {LocalPlayerCharacter, PlayerCharacter}
    local ObscuringObjects = #GetPartsObscuringTarget(Camera, CastPoints, IgnoreList)
    
    return ((ObscuringObjects == 0 and true) or (ObscuringObjects > 0 and false))
end

local function getClosestPlayer()
    if not Options.TargetPart.Value then return end
    local Closest
    local DistanceToMouse
    local ignoredPlayers = Options.PlayerDropdown.Value 

    for _, Player in next, GetPlayers(Players) do
        if Player == LocalPlayer then continue end
        if ignoredPlayers and ignoredPlayers[Player.Name] then continue end
        if Toggles.TeamCheck.Value and Player.Team == LocalPlayer.Team then continue end
        local Character = Player.Character
        if not Character then continue end
        local HumanoidRootPart = FindFirstChild(Character, "HumanoidRootPart")
        local Humanoid = FindFirstChild(Character, "Humanoid")
        if not HumanoidRootPart or not Humanoid or Humanoid and Humanoid.Health <= 0 then continue end
        local ScreenPosition, OnScreen = getPositionOnScreen(HumanoidRootPart.Position)
        if not OnScreen then continue end
        local Distance = (getMousePosition() - ScreenPosition).Magnitude
        if Distance <= (DistanceToMouse or Options.Radius.Value or 2000) then
            Closest = ((Options.TargetPart.Value == "Random" and Character[ValidTargetParts[math.random(1, #ValidTargetParts)]]) or Character[Options.TargetPart.Value])
            DistanceToMouse = Distance
        end
    end
    return Closest
end


local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()


local function getBodyPart(character, part)
    return character:FindFirstChild(part) and part or "Head"
end

local function getNearestPlayerToMouse()
    if not ScriptState.aimLockEnabled then return nil end 
    local nearestPlayer = nil
    local shortestDistance = math.huge
    local mousePosition = Camera:ViewportPointToRay(Mouse.X, Mouse.Y).Origin

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild(ScriptState.bodyPartSelected) then
            local part = player.Character[ScriptState.bodyPartSelected]
            local screenPosition, onScreen = Camera:WorldToViewportPoint(part.Position)
            if onScreen then
                local distance = (Vector2.new(screenPosition.X, screenPosition.Y) - Vector2.new(Mouse.X, Mouse.Y)).Magnitude
                if distance < shortestDistance then
                    nearestPlayer = player
                    shortestDistance = distance
                end
            end
        end
    end
    return nearestPlayer
end

local function toggleLockOnPlayer()
    if not ScriptState.lockEnabled or not ScriptState.aimLockEnabled then return end

    if ScriptState.isLockedOn then
        ScriptState.isLockedOn = false
        ScriptState.targetPlayer = nil
    else
        ScriptState.targetPlayer = getNearestPlayerToMouse()
        if ScriptState.targetPlayer and ScriptState.targetPlayer.Character then
            local part = getBodyPart(ScriptState.targetPlayer.Character, ScriptState.bodyPartSelected)
            if ScriptState.targetPlayer.Character:FindFirstChild(part) then
                ScriptState.isLockedOn = true
            end
        end
    end
end


RunService.RenderStepped:Connect(function()
    if ScriptState.aimLockEnabled and ScriptState.lockEnabled and ScriptState.isLockedOn and ScriptState.targetPlayer and ScriptState.targetPlayer.Character then
        local partName = getBodyPart(ScriptState.targetPlayer.Character, ScriptState.bodyPartSelected)
        local part = ScriptState.targetPlayer.Character:FindFirstChild(partName)

        if part and ScriptState.targetPlayer.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
            local predictedPosition = part.Position + (part.AssemblyLinearVelocity * ScriptState.predictionFactor)
            local currentCameraPosition = Camera.CFrame.Position

            Camera.CFrame = CFrame.new(currentCameraPosition, predictedPosition) * CFrame.new(0, 0, ScriptState.smoothingFactor)
        else
            ScriptState.isLockedOn = false
            ScriptState.targetPlayer = nil
        end
    end
end)




local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/FakeAngles/PasteWare/refs/heads/main/mobileLib.lua"))()
local ThemeManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/FakeAngles/PasteWare/refs/heads/main/manage2.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/FakeAngles/PasteWare/refs/heads/main/manager.lua"))()

Library.KeybindFrame.Visible = false;

local Window = Library:CreateWindow({
    Title = 'PasteWare  |  github.com/FakeAngles',
    Center = true,
    AutoShow = true,  
    TabPadding = 8,
    MenuFadeTime = 0.2
})

local GeneralTab = Window:AddTab("Main")
local aimbox = GeneralTab:AddRightGroupbox("AimLock settings")
local velbox = GeneralTab:AddRightGroupbox("Anti Lock")
local frabox = GeneralTab:AddRightGroupbox("Movement")
local ExploitTab = Window:AddTab("Exploits")
local WarTycoonBox = ExploitTab:AddLeftGroupbox("War Tycoon")
local ACSEngineBox = ExploitTab:AddRightGroupbox("weapon settings")
local VisualsTab = Window:AddTab("Visuals")
local settingsTab = Window:AddTab("Settings")
local MenuGroup = settingsTab:AddLeftGroupbox("Menu")
MenuGroup:AddButton("Unload", function() Library:Unload() end)
MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "End", NoUI = true, Text = "Menu keybind" })
Library.ToggleKeybind = Options.MenuKeybind
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
ThemeManager:ApplyToTab(settingsTab)
SaveManager:BuildConfigSection(settingsTab)

local ScreenGui = Instance.new("ScreenGui")
local OpenButton = Instance.new("TextButton")
ScreenGui.Parent = game.CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

OpenButton.Parent = ScreenGui
OpenButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25) 
OpenButton.Size = UDim2.new(0, 80, 0, 30)
OpenButton.Position = UDim2.new(1, 100, 0.5, -15) 
OpenButton.Text = "menu"
OpenButton.TextColor3 = Color3.fromRGB(255, 255, 255)
OpenButton.Font = Enum.Font.Code
OpenButton.TextSize = 14
OpenButton.BorderSizePixel = 0
OpenButton.Active = true

local ScreenGui = Instance.new("ScreenGui")
local OpenButton = Instance.new("TextButton")
ScreenGui.Parent = game.CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

OpenButton.Parent = ScreenGui
OpenButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
OpenButton.Size = UDim2.new(0, 80, 0, 30)
OpenButton.Position = UDim2.new(1, -100, 0.5, -15)
OpenButton.Text = "OPEN"
OpenButton.TextColor3 = Color3.fromRGB(255, 255, 255)
OpenButton.Font = Enum.Font.Code
OpenButton.TextSize = 14
OpenButton.BorderSizePixel = 0
OpenButton.Active = true

local UIStroke = Instance.new("UIStroke")
UIStroke.Thickness = 1.5
UIStroke.Color = Color3.fromRGB(0, 110, 255)
UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
UIStroke.Parent = OpenButton

OpenButton.MouseButton1Click:Connect(function()
    Library:Toggle()
end)

local dragging, dragInput, dragStart, startPos
local function update(input)
    local delta = input.Position - dragStart
    OpenButton.Position = UDim2.new(
        startPos.X.Scale,
        startPos.X.Offset + delta.X,
        startPos.Y.Scale,
        startPos.Y.Offset + delta.Y
    )
end

OpenButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = OpenButton.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

OpenButton.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        update(input)
    end
end)

aimbox:AddToggle("aimLock_Enabled", {
    Text = "enable/disable AimLock",
    Default = false,
    Tooltip = "Toggle the AimLock feature on or off.",
    Callback = function(value)
        ScriptState.aimLockEnabled = value
        if not ScriptState.aimLockEnabled then
            ScriptState.lockEnabled = false
            ScriptState.isLockedOn = false
            ScriptState.targetPlayer = nil
        end
    end
})

aimbox:AddToggle("aim_Enabled", {
    Text = "aimlock keybind",
    Default = false,
    Tooltip = "Toggle AimLock on or off.",
    Callback = function(value)
        ScriptState.lockEnabled = value
        if not ScriptState.lockEnabled then
            ScriptState.isLockedOn = false
            ScriptState.targetPlayer = nil
        end
    end,
}):AddKeyPicker("aim_Enabled_KeyPicker", {
    Default = "Q", 
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "AimLock Key",
    Tooltip = "Key to toggle AimLock",
    Callback = function()
        toggleLockOnPlayer()
    end,
})

aimbox:AddSlider("Smoothing", {
    Text = "Camera Smoothing",
    Default = 0.1,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Tooltip = "Adjust camera smoothing factor.",
    Callback = function(value)
        ScriptState.smoothingFactor = value
    end,
})


aimbox:AddSlider("Prediction", {
    Text = "Prediction Factor",
    Default = 0.0,
    Min = 0,
    Max = 2,
    Rounding = 2,
    Tooltip = "Adjust prediction for target movement.",
    Callback = function(value)
        ScriptState.predictionFactor = value
    end,
})

aimbox:AddDropdown("BodyParts", {
    Values = {"Head", "UpperTorso", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg", "LeftUpperArm"},
    Default = "Head",
    Multi = false,
    Text = "Target Body Part",
    Tooltip = "Select which body part to lock onto.",
    Callback = function(value)
        ScriptState.bodyPartSelected = value
    end,
})


getgenv().ScriptState.Desync = false
getgenv().ScriptState.DesyncEnabled = false  


game:GetService("RunService").Heartbeat:Connect(function()
    if getgenv().ScriptState.DesyncEnabled then  
        if getgenv().ScriptState.Desync then
            local player = game.Players.LocalPlayer
            local character = player.Character
            if not character then return end 

            local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
            if not humanoidRootPart then return end

            local originalVelocity = humanoidRootPart.Velocity

            local randomOffset = Vector3.new(
                math.random(-1, 1) * ScriptState.reverseResolveIntensity * 1000,
                math.random(-1, 1) * ScriptState.reverseResolveIntensity * 1000,
                math.random(-1, 1) * ScriptState.reverseResolveIntensity * 1000
            )

            humanoidRootPart.Velocity = randomOffset
            humanoidRootPart.CFrame = humanoidRootPart.CFrame * CFrame.Angles(
                0,
                math.random(-1, 1) * ScriptState.reverseResolveIntensity * 0.001,
                0
            )

            game:GetService("RunService").RenderStepped:Wait()

            humanoidRootPart.Velocity = originalVelocity
        end
    end
end)

velbox:AddToggle("desyncMasterEnabled", {
    Text = "Enable ScriptState.Desync",
    Default = false,
    Tooltip = "Enable or disable the entire ScriptState.desync system.",
    Callback = function(value)
        getgenv().ScriptState.DesyncEnabled = value  
    end
})


velbox:AddToggle("ScriptState.desyncEnabled", {
    Text = "ScriptState.Desync keybind",
    Default = false,
    Tooltip = "Enable or disable reverse resolve ScriptState.desync.",
    Callback = function(value)
        getgenv().ScriptState.Desync = value
    end
}):AddKeyPicker("desyncToggleKey", {
    Default = "V", 
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "ScriptState.Desync Toggle Key",
    Tooltip = "Toggle to enable/disable velocity ScriptState.desync.",
    Callback = function(value)
        getgenv().ScriptState.Desync = value
    end
})


velbox:AddSlider("ScriptState.ReverseResolveIntensity", {
    Text = "velocity intensity",
    Default = 5,
    Min = 1,
    Max = 10,
    Rounding = 0,
    Tooltip = "Adjust the intensity of the reverse resolve effect.",
    Callback = function(value)
        ScriptState.reverseResolveIntensity = value
    end
})



RunService.RenderStepped:Connect(function()
    if ScriptState.aimLockEnabled and ScriptState.isLockedOn and ScriptState.targetPlayer and ScriptState.targetPlayer.Character then
        local partName = getBodyPart(ScriptState.targetPlayer.Character, ScriptState.bodyPartSelected)
        local part = ScriptState.targetPlayer.Character:FindFirstChild(partName)

        if part and ScriptState.targetPlayer.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
            local predictedPosition = part.Position + (part.AssemblyLinearVelocity * ScriptState.predictionFactor)

            if ScriptState.antiLockEnabled then
                if ScriptState.resolverMethod == "Recalculate" then

                    predictedPosition = predictedPosition + (part.AssemblyLinearVelocity * ScriptState.resolverIntensity)
                elseif ScriptState.resolverMethod == "Randomize" then

                    predictedPosition = predictedPosition + Vector3.new(
                        math.random() * ScriptState.resolverIntensity - (ScriptState.resolverIntensity / 2),
                        math.random() * ScriptState.resolverIntensity - (ScriptState.resolverIntensity / 2),
                        math.random() * ScriptState.resolverIntensity - (ScriptState.resolverIntensity / 2)
                    )
                elseif ScriptState.resolverMethod == "Invert" then

                    predictedPosition = predictedPosition - (part.AssemblyLinearVelocity * ScriptState.resolverIntensity * 2)
                end
            end

            local currentCameraPosition = Camera.CFrame.Position
            Camera.CFrame = CFrame.new(currentCameraPosition, predictedPosition) * CFrame.new(0, 0, ScriptState.smoothingFactor)
        else
            ScriptState.isLockedOn = false
            ScriptState.targetPlayer = nil
        end
    end
end)

aimbox:AddToggle("antiLock_Enabled", {
    Text = "Enable Anti Lock Resolver",
    Default = false,
    Tooltip = "Toggle the Anti Lock Resolver on or off.",
    Callback = function(value)
        ScriptState.antiLockEnabled = value
    end,
})

aimbox:AddSlider("ScriptState.ResolverIntensity", {
    Text = "Resolver Intensity",
    Default = 1.0,
    Min = 0,
    Max = 5,
    Rounding = 2,
    Tooltip = "Adjust the intensity of the Anti Lock Resolver.",
    Callback = function(value)
        ScriptState.resolverIntensity = value
    end,
})

aimbox:AddDropdown("ResolverMethods", {
    Values = {"Recalculate", "Randomize", "Invert"},
    Default = "Recalculate", 
    Multi = false,
    Text = "Resolver Method",
    Tooltip = "Select the method used by the Anti Lock Resolver.",
    Callback = function(value)
        ScriptState.resolverMethod = value
    end,
})


local MainBOX = GeneralTab:AddLeftTabbox("silent aim")
local Main = MainBOX:AddTab("silent aim")

SilentAimSettings.BulletTP = false


Main:AddToggle("aim_Enabled", {Text = "Enabled"})
    :AddKeyPicker("aim_Enabled_KeyPicker", {
        Default = "U", 
        SyncToggleState = true, 
        Mode = "Toggle", 
        Text = "Enabled", 
        NoUI = false
    })

Options.aim_Enabled_KeyPicker:OnClick(function()
    SilentAimSettings.Enabled = not SilentAimSettings.Enabled
    Toggles.aim_Enabled.Value = SilentAimSettings.Enabled
    Toggles.aim_Enabled:SetValue(SilentAimSettings.Enabled)
end)

Main:AddToggle("TeamCheck", {
    Text = "Team Check", 
    Default = SilentAimSettings.TeamCheck
}):OnChanged(function()
    SilentAimSettings.TeamCheck = Toggles.TeamCheck.Value
end)

Main:AddToggle("BulletTP", {
    Text = "Bullet Teleport",
    Default = SilentAimSettings.BulletTP,
    Tooltip = "Teleports bullet origin to target"
}):OnChanged(function()
    SilentAimSettings.BulletTP = Toggles.BulletTP.Value
end)

Main:AddToggle("CheckForFireFunc", {
    Text = "Check For Fire Function",
    Default = SilentAimSettings.CheckForFireFunc,
    Tooltip = "Checks if the method is called from a fire function"
}):OnChanged(function()
    SilentAimSettings.CheckForFireFunc = Toggles.CheckForFireFunc.Value
end)

Main:AddDropdown("TargetPart", {
    AllowNull = true, 
    Text = "Target Part", 
    Default = SilentAimSettings.TargetPart, 
    Values = {"Head", "HumanoidRootPart", "Random"}
}):OnChanged(function()
    SilentAimSettings.TargetPart = Options.TargetPart.Value
end)

Main:AddDropdown("Method", {
    AllowNull = true,
    Text = "Silent Aim Method",
    Default = SilentAimSettings.SilentAimMethod,
    Values = {
        "ViewportPointToRay",
        "ScreenPointToRay",
        "Raycast",
        "FindPartOnRay",
        "FindPartOnRayWithIgnoreList",
        "FindPartOnRayWithWhitelist"
    }
}):OnChanged(function() 
    SilentAimSettings.SilentAimMethod = Options.Method.Value 
end)

if not SilentAimSettings.BlockedMethods then
    SilentAimSettings.BlockedMethods = {}
end

Main:AddDropdown("Blocked Methods", {
    AllowNull = true,
    Multi = true,
    Text = "Blocked Methods",
    Default = SilentAimSettings.BlockedMethods,
    Values = {
        "Destroy",
        "BulkMoveTo",
        "PivotTo",
        "TranslateBy",
        "SetPrimaryPartCFrame"
    }
}):OnChanged(function()
    SilentAimSettings.BlockedMethods = Options["Blocked Methods"].Value
end)

Main:AddDropdown("Include", {
    AllowNull = true,
    Multi = true,
    Text = "Include",
    Default = SilentAimSettings.Include or {},
    Values = {"Camera", "Character"},
    Tooltip = "Includes these objects in the ignore list"
}):OnChanged(function()
    SilentAimSettings.Include = Options.Include.Value
end)

Main:AddDropdown("Origin", {
    AllowNull = true,
    Multi = true,
    Text = "Origin",
    Default = SilentAimSettings.Origin or "Camera",
    Values = {"Camera", "Custom"},
    Tooltip = "Sets the origin of the bullet"
}):OnChanged(function()
    SilentAimSettings.Origin = Options.Origin.Value
end)

Main:AddSlider("MultiplyUnitBy", {
    Text = "Multiply Unit By",
    Default = 1,
    Min = 0.1,
    Max = 10,
    Rounding = 1,
    Compact = false,
    Tooltip = "Multiplies the direction vector by this value"
}):OnChanged(function()
    SilentAimSettings.MultiplyUnitBy = Options.MultiplyUnitBy.Value
end)

Main:AddSlider("HitChance", {
    Text = "Hit Chance",
    Default = 100,
    Min = 0,
    Max = 100,
    Rounding = 1,
    Compact = false,
}):OnChanged(function()
    SilentAimSettings.HitChance = Options.HitChance.Value
end)

local FieldOfViewBOX = GeneralTab:AddLeftTabbox("Field Of View") do
    local Main = FieldOfViewBOX:AddTab("Visuals")

    Main:AddToggle("Visible", {Text = "Show FOV Circle"})
        :AddColorPicker("Color", {Default = Color3.fromRGB(54, 57, 241)})
        :OnChanged(function()
            fov_circle.Visible = Toggles.Visible.Value
            SilentAimSettings.FOVVisible = Toggles.Visible.Value
        end)

    Main:AddSlider("Radius", {
        Text = "FOV Circle Radius", 
        Min = 0, 
        Max = 360, 
        Default = 130, 
        Rounding = 0
    }):OnChanged(function()
        fov_circle.Radius = Options.Radius.Value
        SilentAimSettings.FOVRadius = Options.Radius.Value
    end)

    Main:AddToggle("MousePosition", {Text = "Show Silent Aim Target"})
        :AddColorPicker("MouseVisualizeColor", {Default = Color3.fromRGB(54, 57, 241)})
        :OnChanged(function()
            SilentAimSettings.ShowSilentAimTarget = Toggles.MousePosition.Value
        end)

    Main:AddDropdown("PlayerDropdown", {
        SpecialType = "Player",
        Text = "Ignore Player",
        Tooltip = "Friend list",
        Multi = true
    })
end

local function removeOldHighlight()
    if ScriptState.previousHighlight then
        ScriptState.previousHighlight:Destroy()
        ScriptState.previousHighlight = nil
    end
end

task.spawn(function()
    RenderStepped:Connect(function()
        if Toggles.MousePosition.Value then
            local closestPlayer = getClosestPlayer()
            if closestPlayer then 
                local char = closestPlayer.Parent
                if char and char:FindFirstChild("Humanoid") and char:FindFirstChild("HumanoidRootPart") then
                    if Toggles.TeamCheck.Value and closestPlayer:IsA("Player") and closestPlayer.Team == LocalPlayer.Team then
                        removeOldHighlight()
                        return
                    end
                    local Root = char.PrimaryPart or char:FindFirstChild("HumanoidRootPart")
                    if Root then
                        local RootToViewportPoint, IsOnScreen = WorldToViewportPoint(Camera, Root.Position)
                        removeOldHighlight()
                        if IsOnScreen then
                            local highlight = char:FindFirstChildOfClass("Highlight")
                            if not highlight then
                                highlight = Instance.new("Highlight")
                                highlight.Parent = char
                                highlight.Adornee = char
                            end
                            highlight.FillColor = Options.MouseVisualizeColor.Value
                            highlight.FillTransparency = 0.5
                            highlight.OutlineColor = Options.MouseVisualizeColor.Value
                            highlight.OutlineTransparency = 0
                            previousHighlight = highlight
                        end
                    end
                end
            else 
                removeOldHighlight()
            end
        end
        if Toggles.Visible.Value then 
            fov_circle.Visible = Toggles.Visible.Value
            fov_circle.Color = Options.Color.Value
            fov_circle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
        end
    end)
end)


local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local SoundService = game:GetService("SoundService")

local sounds = {
    ["RIFK7"] = "rbxassetid://9102080552",
    ["Bubble"] = "rbxassetid://9102092728",
    ["Minecraft"] = "rbxassetid://5869422451",
    ["Cod"] = "rbxassetid://160432334",
    ["Bameware"] = "rbxassetid://6565367558",
    ["Neverlose"] = "rbxassetid://6565370984",
    ["Gamesense"] = "rbxassetid://4817809188",
    ["Rust"] = "rbxassetid://6565371338",
}

local hitSound = Instance.new("Sound")
hitSound.Volume = 3
hitSound.Parent = SoundService

local HitSoundBox = GeneralTab:AddRightTabbox("HitSound") do
    local Main = HitSoundBox:AddTab("HitSound [beta]")

    Main:AddToggle("HitSoundEnabled", {Text = "Enable HitSound", Default = true})

    Main:AddDropdown("HitSoundSelect", {
        Values = {"RIFK7","Bubble","Minecraft","Cod","Bameware","Neverlose","Gamesense","Rust"},
        Default = "Neverlose",
        Text = "HitSound",
        Tooltip = "Choose sound"
    }):OnChanged(function()
        local id = sounds[Options.HitSoundSelect.Value]
        if id then
            hitSound.SoundId = id
        end
    end)
end

hitSound.SoundId = sounds[Options.HitSoundSelect.Value]


local soundPool = {}
local soundIndex = 1

local function getNextSound()
    if soundIndex > #soundPool then
        local s = hitSound:Clone()
        s.Parent = workspace
        s.Looped = false
        table.insert(soundPool, s)
    end
    local s = soundPool[soundIndex]
    soundIndex = soundIndex + 1
    return s
end

local function playHitSound()
    local s = getNextSound()
    s:Stop()
    s:Play()
end

local function trackPlayer(plr)
    if plr == LocalPlayer then return end

    plr.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid", 10)
        if not hum then return end

        local lastHealth = hum.Health

        hum.HealthChanged:Connect(function(newHp)
            if Toggles.HitSoundEnabled.Value then
                local closest = getClosestPlayer()
                if closest and closest.Parent == char then
                    if newHp < lastHealth then
                        playHitSound()
                    end
                    if lastHealth > 0 and newHp <= 0 then
                        playHitSound()
                    end
                end
            end
            lastHealth = newHp
        end)
    end)
end

for _, plr in ipairs(Players:GetPlayers()) do
    trackPlayer(plr)
end
Players.PlayerAdded:Connect(trackPlayer)




local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

RunService.Heartbeat:Connect(function()
    if Toggles.aim_Enabled and Toggles.aim_Enabled.Value then
        ScriptState.ClosestHitPart = getClosestPlayer()
    else
        ScriptState.ClosestHitPart = nil
    end
end)

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(...)
    local self, args = ..., {...}
    local method = getnamecallmethod()
    local chance = CalculateChance(SilentAimSettings.HitChance)

    local BlockedMethods = SilentAimSettings.BlockedMethods or {}
    if method == "Destroy" and self == Client then return end
    if table.find(BlockedMethods, method) then return end
    if SilentAimSettings.CheckForFireFunc and 
       (method:find("Ray") or method:find("ViewportPoint") or method:find("ScreenPoint")) then
        local n = tostring(self):lower()
        if not (n:find("bullet") or n:find("gun") or n:find("fire")) then
            return oldNamecall(...)
        end
    end

    local HitPart = nil
    if Toggles.aim_Enabled and Toggles.aim_Enabled.Value and not checkcaller() and chance then
        HitPart = ScriptState.ClosestHitPart
    end

    if HitPart and self == workspace then
        local function modifyRay(origin)
            if SilentAimSettings.BulletTP then
                origin = (HitPart.CFrame * CFrame.new(0, 0, 1)).p
            end
            return origin, getDirection(origin, HitPart.Position)
        end

        if (method == "FindPartOnRayWithIgnoreList" or
            method == "FindPartOnRayWithWhitelist" or
            method:lower() == "findpartonray" or
            method == "Raycast") and Options.Method.Value == method then

            local oldRay = args[2]
            local Origin, Direction

            if method == "Raycast" then
                Origin, Direction = modifyRay(args[2])
                args[2], args[3] = Origin, Direction
            else
                Origin, Direction = modifyRay(oldRay.Origin)
                args[2] = Ray.new(Origin, Direction)
            end

            return oldNamecall(unpack(args))
        elseif method == "ViewportPointToRay" and Options.Method.Value == method then
            local Origin = Camera.CFrame.p
            if SilentAimSettings.BulletTP then
                Origin = (HitPart.CFrame * CFrame.new(0, 0, 1)).p
            end
            args[2] = Camera:WorldToScreenPoint(HitPart.Position)
            return Ray.new(Origin, (HitPart.Position - Origin).Unit)
        elseif method == "ScreenPointToRay" and Options.Method.Value == method then
            local Origin = Camera.CFrame.p
            if SilentAimSettings.BulletTP then
                Origin = (HitPart.CFrame * CFrame.new(0, 0, 1)).p
            end
            args[2] = Camera:WorldToScreenPoint(HitPart.Position)
            return Ray.new(Origin, (HitPart.Position - Origin).Unit)
        end
    end
    return oldNamecall(...)
end))


local worldbox = VisualsTab:AddRightGroupbox("World")

local lighting = game:GetService("Lighting")
local camera = game.Workspace.CurrentCamera
ScriptState.lockedTime, ScriptState.fovValue, ScriptState.nebulaEnabled = 12, 70, false
local originalAmbient, originalOutdoorAmbient = lighting.Ambient, lighting.OutdoorAmbient
local originalFogStart, originalFogEnd, originalFogColor = lighting.FogStart, lighting.FogEnd, lighting.FogColor

local nebulaThemeColor = Color3.fromRGB(173, 216, 230)

worldbox:AddSlider("world_time", {
    Text = "Clock Time", Default = 12, Min = 0, Max = 24, Rounding = 1,
    Callback = function(v) ScriptState.lockedTime = v lighting.ClockTime = v end,
})

local oldNewIndex
oldNewIndex = hookmetamethod(game, "__newindex", function(self, property, value)
    if not checkcaller() and self == lighting then
        if property == "ClockTime" then value = ScriptState.lockedTime end
    end
    return oldNewIndex(self, property, value)
end)

worldbox:AddSlider("fov_slider", {
    Text = "FOV", Default = 70, Min = 30, Max = 120, Rounding = 2,
    Callback = function(v) ScriptState.fovValue = v end,
})

worldbox:AddToggle("fov_toggle", {
    Text = "Enable FOV Change", Default = false,
    Callback = function(state) ScriptState.fovEnabled = state end,
})

game:GetService("RunService").RenderStepped:Connect(function() 
    if ScriptState.fovEnabled then
        camera.FieldOfView = ScriptState.fovValue 
    end
end)


worldbox:AddToggle("nebula_theme", {
    Text = "Nebula Theme", Default = false,
    Callback = function(state)
        ScriptState.nebulaEnabled = state
        if state then
            local b = Instance.new("BloomEffect", lighting) b.Intensity, b.Size, b.Threshold, b.Name = 0.7, 24, 1, "NebulaBloom"
            local c = Instance.new("ColorCorrectionEffect", lighting) c.Saturation, c.Contrast, c.TintColor, c.Name = 0.5, 0.2, nebulaThemeColor, "NebulaColorCorrection"
            local a = Instance.new("Atmosphere", lighting) a.Density, a.Offset, a.Glare, a.Haze, a.Color, a.Decay, a.Name = 0.4, 0.25, 1, 2, nebulaThemeColor, Color3.fromRGB(25, 25, 112), "NebulaAtmosphere"
            lighting.Ambient, lighting.OutdoorAmbient = nebulaThemeColor, nebulaThemeColor
            lighting.FogStart, lighting.FogEnd = 100, 500
            lighting.FogColor = nebulaThemeColor
        else
            for _, v in pairs({"NebulaBloom", "NebulaColorCorrection", "NebulaAtmosphere"}) do
                local obj = lighting:FindFirstChild(v) if obj then obj:Destroy() end
            end
            lighting.Ambient, lighting.OutdoorAmbient = originalAmbient, originalOutdoorAmbient
            lighting.FogStart, lighting.FogEnd = originalFogStart, originalFogEnd
            lighting.FogColor = originalFogColor
        end
    end,
}):AddColorPicker("nebula_color_picker", {
    Text = "Nebula Color", Default = Color3.fromRGB(173, 216, 230),
    Callback = function(c)
        nebulaThemeColor = c
        if ScriptState.nebulaEnabled then
            local nc = lighting:FindFirstChild("NebulaColorCorrection") if nc then nc.TintColor = c end
            local na = lighting:FindFirstChild("NebulaAtmosphere") if na then na.Color = c end
            lighting.Ambient, lighting.OutdoorAmbient = c, c
            lighting.FogColor = c
        end
    end,
})


local Lighting = game:GetService("Lighting")
local Visuals = {}
local Skyboxes = {}

function Visuals:NewSky(Data)
    local Name = Data.Name
    Skyboxes[Name] = {
        SkyboxBk = Data.SkyboxBk,
        SkyboxDn = Data.SkyboxDn,
        SkyboxFt = Data.SkyboxFt,
        SkyboxLf = Data.SkyboxLf,
        SkyboxRt = Data.SkyboxRt,
        SkyboxUp = Data.SkyboxUp,
        MoonTextureId = Data.Moon or "rbxasset://sky/moon.jpg",
        SunTextureId = Data.Sun or "rbxasset://sky/sun.jpg"
    }
end

function Visuals:SwitchSkybox(Name)
    local OldSky = Lighting:FindFirstChildOfClass("Sky")
    if OldSky then OldSky:Destroy() end

    local Sky = Instance.new("Sky", Lighting)
    for Index, Value in pairs(Skyboxes[Name]) do
        Sky[Index] = Value
    end
end

if Lighting:FindFirstChildOfClass("Sky") then
    local OldSky = Lighting:FindFirstChildOfClass("Sky")
    Visuals:NewSky({
        Name = "Game's Default Sky",
        SkyboxBk = OldSky.SkyboxBk,
        SkyboxDn = OldSky.SkyboxDn,
        SkyboxFt = OldSky.SkyboxFt,
        SkyboxLf = OldSky.SkyboxLf,
        SkyboxRt = OldSky.SkyboxRt,
        SkyboxUp = OldSky.SkyboxUp
    })
end

Visuals:NewSky({
    Name = "Sunset",
    SkyboxBk = "rbxassetid://600830446",
    SkyboxDn = "rbxassetid://600831635",
    SkyboxFt = "rbxassetid://600832720",
    SkyboxLf = "rbxassetid://600886090",
    SkyboxRt = "rbxassetid://600833862",
    SkyboxUp = "rbxassetid://600835177"
})

Visuals:NewSky({
    Name = "Arctic",
    SkyboxBk = "http://www.roblox.com/asset/?id=225469390",
    SkyboxDn = "http://www.roblox.com/asset/?id=225469395",
    SkyboxFt = "http://www.roblox.com/asset/?id=225469403",
    SkyboxLf = "http://www.roblox.com/asset/?id=225469450",
    SkyboxRt = "http://www.roblox.com/asset/?id=225469471",
    SkyboxUp = "http://www.roblox.com/asset/?id=225469481"
})

Visuals:NewSky({
    Name = "Space",
    SkyboxBk = "http://www.roblox.com/asset/?id=166509999",
    SkyboxDn = "http://www.roblox.com/asset/?id=166510057",
    SkyboxFt = "http://www.roblox.com/asset/?id=166510116",
    SkyboxLf = "http://www.roblox.com/asset/?id=166510092",
    SkyboxRt = "http://www.roblox.com/asset/?id=166510131",
    SkyboxUp = "http://www.roblox.com/asset/?id=166510114"
})

Visuals:NewSky({
    Name = "Roblox Default",
    SkyboxBk = "rbxasset://textures/sky/sky512_bk.tex",
    SkyboxDn = "rbxasset://textures/sky/sky512_dn.tex",
    SkyboxFt = "rbxasset://textures/sky/sky512_ft.tex",
    SkyboxLf = "rbxasset://textures/sky/sky512_lf.tex",
    SkyboxRt = "rbxasset://textures/sky/sky512_rt.tex",
    SkyboxUp = "rbxasset://textures/sky/sky512_up.tex"
})

Visuals:NewSky({
    Name = "Red Night", 
    SkyboxBk = "http://www.roblox.com/Asset/?ID=401664839";
    SkyboxDn = "http://www.roblox.com/Asset/?ID=401664862";
    SkyboxFt = "http://www.roblox.com/Asset/?ID=401664960";
    SkyboxLf = "http://www.roblox.com/Asset/?ID=401664881";
    SkyboxRt = "http://www.roblox.com/Asset/?ID=401664901";
    SkyboxUp = "http://www.roblox.com/Asset/?ID=401664936";
})

Visuals:NewSky({
    Name = "Deep Space", 
    SkyboxBk = "http://www.roblox.com/asset/?id=149397692";
    SkyboxDn = "http://www.roblox.com/asset/?id=149397686";
    SkyboxFt = "http://www.roblox.com/asset/?id=149397697";
    SkyboxLf = "http://www.roblox.com/asset/?id=149397684";
    SkyboxRt = "http://www.roblox.com/asset/?id=149397688";
    SkyboxUp = "http://www.roblox.com/asset/?id=149397702";
})

Visuals:NewSky({
    Name = "Pink Skies", 
    SkyboxBk = "http://www.roblox.com/asset/?id=151165214";
    SkyboxDn = "http://www.roblox.com/asset/?id=151165197";
    SkyboxFt = "http://www.roblox.com/asset/?id=151165224";
    SkyboxLf = "http://www.roblox.com/asset/?id=151165191";
    SkyboxRt = "http://www.roblox.com/asset/?id=151165206";
    SkyboxUp = "http://www.roblox.com/asset/?id=151165227";
})

Visuals:NewSky({
    Name = "Purple Sunset", 
    SkyboxBk = "rbxassetid://264908339";
    SkyboxDn = "rbxassetid://264907909";
    SkyboxFt = "rbxassetid://264909420";
    SkyboxLf = "rbxassetid://264909758";
    SkyboxRt = "rbxassetid://264908886";
    SkyboxUp = "rbxassetid://264907379";
})

Visuals:NewSky({
    Name = "Blue Night", 
    SkyboxBk = "http://www.roblox.com/Asset/?ID=12064107";
    SkyboxDn = "http://www.roblox.com/Asset/?ID=12064152";
    SkyboxFt = "http://www.roblox.com/Asset/?ID=12064121";
    SkyboxLf = "http://www.roblox.com/Asset/?ID=12063984";
    SkyboxRt = "http://www.roblox.com/Asset/?ID=12064115";
    SkyboxUp = "http://www.roblox.com/Asset/?ID=12064131";
})

Visuals:NewSky({
    Name = "Blossom Daylight", 
    SkyboxBk = "http://www.roblox.com/asset/?id=271042516";
    SkyboxDn = "http://www.roblox.com/asset/?id=271077243";
    SkyboxFt = "http://www.roblox.com/asset/?id=271042556";
    SkyboxLf = "http://www.roblox.com/asset/?id=271042310";
    SkyboxRt = "http://www.roblox.com/asset/?id=271042467";
    SkyboxUp = "http://www.roblox.com/asset/?id=271077958";
})

Visuals:NewSky({
    Name = "Blue Nebula", 
    SkyboxBk = "http://www.roblox.com/asset?id=135207744";
    SkyboxDn = "http://www.roblox.com/asset?id=135207662";
    SkyboxFt = "http://www.roblox.com/asset?id=135207770";
    SkyboxLf = "http://www.roblox.com/asset?id=135207615";
    SkyboxRt = "http://www.roblox.com/asset?id=135207695";
    SkyboxUp = "http://www.roblox.com/asset?id=135207794";
})

Visuals:NewSky({
    Name = "Blue Planet", 
    SkyboxBk = "rbxassetid://218955819";
    SkyboxDn = "rbxassetid://218953419";
    SkyboxFt = "rbxassetid://218954524";
    SkyboxLf = "rbxassetid://218958493";
    SkyboxRt = "rbxassetid://218957134";
    SkyboxUp = "rbxassetid://218950090";
})

Visuals:NewSky({
    Name = "Deep Space", 
    SkyboxBk = "http://www.roblox.com/asset/?id=159248188";
    SkyboxDn = "http://www.roblox.com/asset/?id=159248183";
    SkyboxFt = "http://www.roblox.com/asset/?id=159248187";
    SkyboxLf = "http://www.roblox.com/asset/?id=159248173";
    SkyboxRt = "http://www.roblox.com/asset/?id=159248192";
    SkyboxUp = "http://www.roblox.com/asset/?id=159248176";
})

local SkyboxNames = {}
for Name, _ in pairs(Skyboxes) do
    table.insert(SkyboxNames, Name)
end

local worldbox = VisualsTab:AddRightGroupbox("SkyBox")
local SkyboxDropdown = worldbox:AddDropdown("SkyboxSelector", {
    AllowNull = false,
    Text = "Select Skybox",
    Default = "Game's Default Sky",
    Values = SkyboxNames
}):OnChanged(function(SelectedSkybox)
    if Skyboxes[SelectedSkybox] then
        Visuals:SwitchSkybox(SelectedSkybox)
    end
end)

local VisualsEx = VisualsTab:AddLeftGroupbox("ESP")

if not _G.ExunysESPLoaded then
    loadstring(game:HttpGet("https://raw.githubusercontent.com/FakeAngles/PasteWare/refs/heads/main/ESP.lua"))()
end

local ESP = getgenv().ExunysDeveloperESP
if not ESP then return end 

ESP.Settings = ESP.Settings or {}
ESP.Settings.Enabled = false
ESP.Properties = ESP.Properties or {}

local queuedToggles = {
    NameTag = false,
    Box = false,
    Tracer = false,
    HeadDot = false,
    HealthBar = false,
}

local function applyQueuedToggles()
    if not ESP.Settings.Enabled or not ESP.Properties then return end

    if ESP.Properties.ESP then ESP.Properties.ESP.DisplayName = queuedToggles.NameTag end
    if ESP.Properties.Box then ESP.Properties.Box.Enabled = queuedToggles.Box end
    if ESP.Properties.Tracer then ESP.Properties.Tracer.Enabled = queuedToggles.Tracer end
    if ESP.Properties.HeadDot then ESP.Properties.HeadDot.Enabled = queuedToggles.HeadDot end
    if ESP.Properties.HealthBar then ESP.Properties.HealthBar.Enabled = queuedToggles.HealthBar end
end

local function setToggle(name, value)
    queuedToggles[name] = value
    applyQueuedToggles()
end

local function setProperty(path, value)
    local ref = ESP
    for i = 1, #path-1 do
        if ref and ref[path[i]] then
            ref = ref[path[i]]
        else
            return
        end
    end
    if ref and path[#path] then
        ref[path[#path]] = value
    end
end

VisualsEx:AddToggle("espEnabled", {
    Text = "Enable ESP",
    Default = false,
    Callback = function(value)
        if value and ESP and not ESP.Loaded and ESP.Load then
            pcall(function() ESP:Load() end)
        end
        if ESP and ESP.Settings then
            ESP.Settings.Enabled = value
        end
        applyQueuedToggles()
    end
})

local TeamCheck = false
local function IsEnemy(player)
    if not TeamCheck then return true end
    return player.Team ~= LocalPlayer.Team
end

VisualsEx:AddToggle("teamCheck", {
    Text = "Team Check",
    Default = ESP.Settings.TeamCheck or false,
    Callback = function(value)
        if ESP and ESP.Settings then
            ESP.Settings.TeamCheck = value
        end
        if UpdateAllChams then
            pcall(UpdateAllChams)
        end
    end
})

local espElements = {
    {Name = "NameTag", Path = {"Properties", "ESP", "DisplayName"}, Type = "Toggle"},
    {Name = "Box", Path = {"Properties", "Box", "Enabled"}, Type = "Toggle"},
    {Name = "Box Color", Path = {"Properties", "Box", "Color"}, Type = "Color"},
    {Name = "Tracer", Path = {"Properties", "Tracer", "Enabled"}, Type = "Toggle"},
    {Name = "Tracer Color", Path = {"Properties", "Tracer", "Color"}, Type = "Color"},
    {Name = "HeadDot", Path = {"Properties", "HeadDot", "Enabled"}, Type = "Toggle"},
    {Name = "HeadDot Size", Path = {"Properties", "HeadDot", "NumSides"}, Type = "Slider", Min = 3, Max = 60, Default = ESP.Properties.HeadDot and ESP.Properties.HeadDot.NumSides or 6},
    {Name = "HealthBar", Path = {"Properties", "HealthBar", "Enabled"}, Type = "Toggle"},
}

for _, element in ipairs(espElements) do
    if element.Type == "Toggle" then
        VisualsEx:AddToggle(element.Name, {
            Text = element.Name,
            Default = false,
            Callback = function(val)
                setToggle(element.Name, val)
            end
        })
    elseif element.Type == "Color" then
        local ref = ESP
        for i = 1, #element.Path do
            if ref then
                ref = ref[element.Path[i]]
            else
                break
            end
        end
        VisualsEx:AddLabel(element.Name):AddColorPicker(element.Name.."Color", {
            Default = ref or Color3.new(1,1,1),
            Callback = function(val)
                setProperty(element.Path, val)
            end
        })
    elseif element.Type == "Slider" then
        VisualsEx:AddSlider(element.Name, {
            Text = element.Name,
            Min = element.Min,
            Max = element.Max,
            Default = element.Default or 6,
            Rounding = 1,
            Callback = function(val)
                setProperty(element.Path, val)
            end
        })
    end
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local originalProperties = {}

local function HSVToRGB(h, s, v)
    local c = v * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = v - c
    local r, g, b = 0, 0, 0

    if h < 60 then r, g, b = c, x, 0
    elseif h < 120 then r, g, b = x, c, 0
    elseif h < 180 then r, g, b = 0, c, x
    elseif h < 240 then r, g, b = 0, x, c
    elseif h < 300 then r, g, b = x, 0, c
    else r, g, b = c, 0, x end

    return Color3.new(r + m, g + m, b + m)
end

local function applyChams(char)
    if not char then return end
    originalProperties = {}
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            originalProperties[part] = {
                Color = part.Color,
                Material = part.Material
            }
            part.Material = Enum.Material.ForceField
            part.Color = ScriptState.SelfChamsColor
        end
    end
end

local function restoreChams()
    for part, props in pairs(originalProperties) do
        if part and part.Parent then
            part.Color = props.Color
            part.Material = props.Material
        end
    end
    originalProperties = {}
end

local function updateChams()
    if not ScriptState.SelfChamsEnabled then return end
    for part, _ in pairs(originalProperties) do
        if part and part.Parent then
            if ScriptState.RainbowChamsEnabled then
                local hue = (tick() * 120) % 360
                part.Color = HSVToRGB(hue, 1, 1)
            else
                part.Color = ScriptState.SelfChamsColor
            end
        end
    end
end

RunService.RenderStepped:Connect(updateChams)

LocalPlayer.CharacterAdded:Connect(function(char)
    if ScriptState.SelfChamsEnabled then
        task.wait(1)
        applyChams(char)
    end
end)

VisualsEx:AddToggle("ScriptState.selfChamsEnabled", {
    Text = "Self Chams",
    Default = false,
    Callback = function(val)
        ScriptState.SelfChamsEnabled = val
        if val then
            if LocalPlayer.Character then
                applyChams(LocalPlayer.Character)
            end
        else
            restoreChams()
        end
    end
})

VisualsEx:AddToggle("rainbowChams", {
    Text = "Rainbow Chams",
    Default = false,
    Callback = function(val)
        ScriptState.RainbowChamsEnabled = val
    end
})

VisualsEx:AddLabel("Self Chams Color"):AddColorPicker("ScriptState.selfChamsColor", {
    Default = ScriptState.SelfChamsColor,
    Callback = function(val)
        ScriptState.SelfChamsColor = val
    end
})

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")

local ChamsOccludedColor = {Color3.fromRGB(128, 0, 128), 0.7}
local ChamsVisibleColor = {Color3.fromRGB(255, 0, 255), 0.3}

local AdornmentsCache = {}
local IgnoreNames = {["HumanoidRootPart"] = true}

local function CreateAdornment(part, isHead, vis)
    local adorn
    if isHead then
        adorn = Instance.new("CylinderHandleAdornment")
        adorn.Height = vis == 1 and 0.87 or 1.02
        adorn.Radius = vis == 1 and 0.5 or 0.65
    else
        adorn = Instance.new("BoxHandleAdornment")
        local offset = vis == 1 and -0.05 or 0.05
        adorn.Size = part.Size + Vector3.new(offset, offset, offset)
    end
    adorn.Adornee = part
    adorn.Parent = part
    adorn.ZIndex = vis == 1 and 2 or 1
    adorn.AlwaysOnTop = vis == 1
    adorn.Visible = false
    return adorn
end

local function IsEnemy(player)
    if ESP and ESP.Settings and ESP.Settings.TeamCheck then
        return player.Team ~= LocalPlayer.Team
    end
    return true
end

local function ApplyChams(player)
    if player ~= LocalPlayer and player.Character then
        for _, part in pairs(player.Character:GetChildren()) do
            if part:IsA("BasePart") and not IgnoreNames[part.Name] then
                if not AdornmentsCache[part] then
                    AdornmentsCache[part] = {
                        CreateAdornment(part, part.Name=="Head", 1),
                        CreateAdornment(part, part.Name=="Head", 2)
                    }
                end
                local ad = AdornmentsCache[part]
                local visible = ScriptState.ChamsEnabled and IsEnemy(player)

                ad[1].Visible = visible
                ad[1].Color3 = ChamsOccludedColor[1]
                ad[1].Transparency = ChamsOccludedColor[2]

                ad[2].Visible = visible
                ad[2].AlwaysOnTop = true
                ad[2].ZIndex = 9e9
                ad[2].Color3 = ChamsVisibleColor[1]
                ad[2].Transparency = ChamsVisibleColor[2]
            end
        end
    end
end

local function UpdateAllChams()
    for _, player in pairs(Players:GetPlayers()) do
        ApplyChams(player)
    end
end

local function TrackPlayer(player)
    player:GetPropertyChangedSignal("Team"):Connect(function()
        if AdornmentsCache[player] then
            for _, ad in pairs(AdornmentsCache[player]) do
                ad.Visible = ScriptState.ChamsEnabled and IsEnemy(player)
            end
        end
    end)
end

Players.PlayerAdded:Connect(TrackPlayer)
for _, plr in pairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then
        TrackPlayer(plr)
    end
end

RunService.RenderStepped:Connect(UpdateAllChams)

VisualsEx:AddToggle("ScriptState.chamsEnabled", {
    Text = "Chams",
    Default = ScriptState.ChamsEnabled,
    Callback = function(val)
        ScriptState.ChamsEnabled = val
        for part, ad in pairs(AdornmentsCache) do
            ad[1].Visible = val
            ad[2].Visible = val
        end
    end
})

VisualsEx:AddLabel("Chams Occluded Color"):AddColorPicker("chamsOccludedColor", {
    Default = ChamsOccludedColor[1],
    Callback = function(val)
        ChamsOccludedColor[1] = val
    end
})

VisualsEx:AddLabel("Chams Visible Color"):AddColorPicker("chamsVisibleColor", {
    Default = ChamsVisibleColor[1],
    Callback = function(val)
        ChamsVisibleColor[1] = val
    end
})

VisualsEx:AddSlider("chamsOccludedTransparency", {
    Text = "Occluded Transparency",
    Default = ChamsOccludedColor[2],
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = function(val)
        ChamsOccludedColor[2] = val
    end
})

VisualsEx:AddSlider("chamsVisibleTransparency", {
    Text = "Visible Transparency",
    Default = ChamsVisibleColor[2],
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = function(val)
        ChamsVisibleColor[2] = val
    end
})

local localPlayer = game:GetService("Players").LocalPlayer
local camera = workspace.CurrentCamera
local humanoid = nil

frabox:AddToggle("functionalityEnabled", {
    Text = "Enable/Disable movement",
    Default = true,
    Tooltip = "Enable or disable.",
    Callback = function(value)
        ScriptState.isFunctionalityEnabled = value
    end
})

frabox:AddToggle("speedEnabled", {
    Text = "Speed Toggle",
    Default = false,
    Tooltip = "It makes you go fast.",
    Callback = function(value)
        ScriptState.isSpeedActive = value
    end
}):AddKeyPicker("speedToggleKey", {
    Default = "C",  
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Speed Toggle Key",
    Tooltip = "CFrame keybind.",
    Callback = function(value)
        ScriptState.isSpeedActive = value
    end
})

frabox:AddSlider("cframespeed", {
    Text = "CFrame Multiplier",
    Default = 1,
    Min = 1,
    Max = 20,
    Rounding = 1,
    Tooltip = "The CFrame speed.",
    Callback = function(value)
        ScriptState.Cmultiplier = value
    end,
})

frabox:AddToggle("flyEnabled", {
    Text = "CFly Toggle",
    Default = false,
    Tooltip = "Toggle CFrame Fly functionality.",
    Callback = function(value)
        ScriptState.isFlyActive = value
    end
}):AddKeyPicker("flyToggleKey", {
    Default = "F",  
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "CFly Toggle Key",
    Tooltip = "CFrame Fly keybind.",
    Callback = function(value)
        ScriptState.isFlyActive = value
    end
})

frabox:AddSlider("ScriptState.flySpeed", {
    Text = "CFly Speed",
    Default = 1,
    Min = 1,
    Max = 50,
    Rounding = 1,
    Tooltip = "The CFrame Fly speed.",
    Callback = function(value)
        ScriptState.flySpeed = value
    end,
})

frabox:AddToggle("noClipEnabled", {
    Text = "NoClip Toggle",
    Default = false,
    Tooltip = "Enable or disable NoClip.",
    Callback = function(value)
        ScriptState.isNoClipActive = value
    end
}):AddKeyPicker("noClipToggleKey", {
    Default = "N",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "NoClip Toggle Key",
    Tooltip = "Keybind to toggle NoClip.",
    Callback = function(value)
        ScriptState.isNoClipActive = value
    end
})

local function enableMasterToggle(value)
    ScriptState.masterToggle = value
end

WarTycoonBox:AddToggle("Master Toggle", {
    Text = "Enable/Disable",
    Default = false,
    Tooltip = "Enable or disable all features globally.",
    Callback = enableMasterToggle
})


local function modifyWeaponSettings(property, value)
    local function findSettingsModule(parent)
        for _, child in pairs(parent:GetChildren()) do
            if child:IsA("ModuleScript") then
                local success, module = pcall(function() return require(child) end)
                if success and module[property] ~= nil then
                    return module
                end
            end
            local found = findSettingsModule(child)
            if found then
                return found
            end
        end
        return nil
    end

    local player = game:GetService("Players").LocalPlayer
    local backpack = player:WaitForChild("Backpack")
    local character = player.Character or player.CharacterAdded:Wait()

    local function findSettingsInWarTycoon(item)
        local weaponName = item.Name
        local settingsModule = game:GetService("ReplicatedStorage"):WaitForChild("Configurations"):WaitForChild("ACS_Guns"):FindFirstChild(weaponName)
        if settingsModule then
            return settingsModule:FindFirstChild("Settings")
        end
        return nil
    end

    local function applyAttribute(weapon)
        if weapon and weapon:IsA("Tool") then
            pcall(function()
                weapon:SetAttribute(property, value)
            end)
        end
    end

    local function applyRequireModule(settingsModule)
        if settingsModule then
            local success, module = pcall(function() return require(settingsModule) end)
            if success and module[property] ~= nil then
                module[property] = value
            end
        end
    end

    local useAttribute = getgenv().WeaponModifyMethod == "Attribute"

    local function processWeapon(weapon)
        if useAttribute then
            applyAttribute(weapon)
        else
            local settingsModule
            if getgenv().WarTycoon then
                settingsModule = findSettingsInWarTycoon(weapon)
            else
                settingsModule = findSettingsModule(weapon)
            end
            applyRequireModule(settingsModule)
        end
    end

    if getgenv().WeaponOnHands then
        local toolInHand = character:FindFirstChildOfClass("Tool")
        if toolInHand then
            processWeapon(toolInHand)
        end
    else
        for _, item in pairs(backpack:GetChildren()) do
            processWeapon(item)
        end
    end
end


--not final code need optimize FindFirstChild... Cuz can make FinFirstChilde true withous find 1 and find 2 only find 1
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local FireTurret, RegisterTurretHit


local function getTank()
    if not ScriptState.masterToggle then return end
    local tankWorkspace = Workspace:FindFirstChild("Game Systems") 
        and Workspace["Game Systems"]:FindFirstChild("Tank Workspace")
    if not tankWorkspace then return nil end

    local closestTank = nil
    local shortestDistance = math.huge

    for _, tank in pairs(tankWorkspace:GetChildren()) do
        if tank:FindFirstChild("Misc") and tank.Misc:FindFirstChild("Turrets") then
            local tankPos = (tank.PrimaryPart and tank.PrimaryPart.Position) or Vector3.new()
            local playerPos = (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position) or Vector3.new()
            local distance = (tankPos - playerPos).Magnitude
            if distance < shortestDistance then
                shortestDistance = distance
                closestTank = tank
            end
        end
    end

    return closestTank
end

local function getTurretSmokeAndSettings(tank)
    if not ScriptState.masterToggle then return end
    if not tank:FindFirstChild("Misc") or not tank.Misc:FindFirstChild("Turrets") then return nil, nil, nil end
    local turretsFolder = tank.Misc.Turrets

    for _, turretGroup in pairs(turretsFolder:GetChildren()) do
        if turretGroup:IsA("Folder") or turretGroup:IsA("Model") then
            for _, turret in pairs(turretGroup:GetChildren()) do
                if turret:IsA("BasePart") or turret:IsA("Model") then
                    local smoke = turret:FindFirstChild("SmokePart")
                    local module = turret:FindFirstChildOfClass("ModuleScript")
                    if smoke and module then
                        local settings = require(module)
                        return turret, smoke, settings
                    end
                end
            end
        end
    end

    return nil, nil, nil
end

local function startTankSpam()
    if not ScriptState.masterToggle then return end
    if not FireTurret or not RegisterTurretHit then
        FireTurret = ReplicatedStorage.BulletFireSystem:WaitForChild("FireTurret")
        RegisterTurretHit = ReplicatedStorage.BulletFireSystem:WaitForChild("RegisterTurretHit")
    end

    local tank = getTank()
    if not tank then return end

    local turret, smoke, settings = getTurretSmokeAndSettings(tank)
    if not turret or not smoke or not settings then return end

    for i = 1, ScriptState.shellsToFire do
        if not ScriptState.isTankSpamEnabled then return end

        local targetHead = getClosestPlayer()
        if not targetHead then return end

        local origin = smoke.Position
        local targetPos = targetHead.Position
        local direction = (targetPos - origin).Unit

        FireTurret:FireServer(
            tank,
            turret,
            nil,
            nil,
            nil,
            nil,
            { {Workspace[LocalPlayer.Name], turret, Workspace.LocalPartStorage} },
            true
        )

        RegisterTurretHit:FireServer(
            turret,
            smoke,
            tank,
            {
                normal = Vector3.new(0, 1, 0),
                hitPart = targetHead,
                origin = origin,
                hitPoint = targetPos,
                direction = direction
            },
            {
                OverheatCount = settings.OverheatCount or 1,
                CooldownTime = settings.CooldownTime or 10,
                BulletSpread = settings.BulletSpread or 0.05,
                FireRate = settings.FireRate or 18
            }
        )

        ScriptState.shellNumber += 1
    end
end

WarTycoonBox:AddToggle("Tank Spam", {
    Text = "Toggle Tank Spam",
    Default = false,
    Tooltip = "using silent aim fov",
    Callback = function(value)
        ScriptState.isTankSpamEnabled = value
    end,
})
:AddKeyPicker("Tank Spam Key", {
    Default = "Q",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Tank Spam Key",
    Tooltip = "Toggle Tank Spam",
    Callback = function()
        if ScriptState.isTankSpamEnabled then
            startTankSpam()
        end
    end,
})

WarTycoonBox:AddSlider("Shell Count", {
    Text = "Shells per Spam",
    Default = 1,
    Min = 1,
    Max = 500,
    Rounding = 0,
    Tooltip = "Adjust how many shells to fire at once.",
    Callback = function(value)
        ScriptState.shellsToFire = math.floor(value)
    end,
})

WarTycoonBox:AddSlider("Spam Speed", {
    Text = "Spam Speed",
    Default = 1,
    Min = 0.01,
    Max = 5,
    Rounding = 2,
    Tooltip = "Adjust the speed of Tank spam.",
    Callback = function(value)
        ScriptState.spamSpeed = value
    end,
})

RunService.Heartbeat:Connect(function()
    if ScriptState.isTankSpamEnabled then
        task.wait(math.max(0.01, 1 / ScriptState.spamSpeed))
        startTankSpam()
    end
end)

ACSEngineBox:AddToggle("WarTycoon", {
    Text = "War Tycoon",
    Default = false,
    Tooltip = "Enable War Tycoon mode to search for weapon settings in ACS_Guns.",
    Callback = function(value)
        getgenv().WarTycoon = value
    end
})

ACSEngineBox:AddToggle("WeaponOnHands", {
    Text = "Weapon In Hands",
    Default = false,
    Tooltip = "Apply changes only to the weapon in hands if enabled.",
    Callback = function(value)
        getgenv().WeaponOnHands = value
    end
})

ACSEngineBox:AddDropdown("WeaponModifyMethod", {
    Text = "Weapon Modify Method",
    Default = "Attribute",
    Values = {"Attribute", "Require"},
    Tooltip = "Choose how to modify weapon settings",
    Callback = function(value)
        getgenv().WeaponModifyMethod = value
    end
})

ACSEngineBox:AddButton('INF AMMO', function()
    modifyWeaponSettings("Ammo", math.huge)
end)

ACSEngineBox:AddButton('NO RECOIL | NO SPREAD', function()
    if getgenv().WeaponModifyMethod == "Attribute" then
        modifyWeaponSettings("VRecoil", Vector2.new(0, 0))
        modifyWeaponSettings("HRecoil", Vector2.new(0, 0))
    else
        modifyWeaponSettings("VRecoil", {0, 0})
        modifyWeaponSettings("HRecoil", {0, 0})
    end
    modifyWeaponSettings("MinSpread", 0)
    modifyWeaponSettings("MaxSpread", 0)
    modifyWeaponSettings("RecoilPunch", 0)
    modifyWeaponSettings("AimRecoilReduction", 0)
end)

ACSEngineBox:AddButton('INF BULLET DISTANCE', function()
    modifyWeaponSettings("Distance", 25000)
end)

ACSEngineBox:AddInput("BulletSpeedInput", {
    Text = "Bullet Speed",
    Default = "10000",
    Tooltip = "Set the bullet speed",
    Callback = function(value)
        getgenv().bulletSpeedValue = tonumber(value) or 10000
    end
})

ACSEngineBox:AddButton('CHANGE BULLET SPEED', function()
    modifyWeaponSettings("BSpeed", getgenv().bulletSpeedValue or 10000)
    modifyWeaponSettings("MuzzleVelocity", getgenv().bulletSpeedValue or 10000)
end)

local fireRateInput = ACSEngineBox:AddInput('FireRateInput', {
    Text = 'Enter Fire Rate',
    Default = '8888',
    Tooltip = 'Type the fire rate value you want to apply.',
})

ACSEngineBox:AddButton('CHANGE FIRE RATE', function()
    local rate = tonumber(fireRateInput.Value) or 8888
    modifyWeaponSettings("FireRate", rate)
    modifyWeaponSettings("ShootRate", rate)
end)

local bulletsInput = ACSEngineBox:AddInput('BulletsInput', {
    Text = 'Enter Bullets',
    Default = '50',
    Tooltip = 'Type the number of bullets you want to apply.',
    Numeric = true
})

ACSEngineBox:AddButton('MULTI BULLETS', function()
    local bulletsValue = tonumber(bulletsInput.Value) or 50
    modifyWeaponSettings("Bullets", bulletsValue)
end)

local inputField = ACSEngineBox:AddInput('FireModeInput', {
    Text = 'Enter Fire Mode',
    Default = 'Auto',
    Tooltip = 'Type the fire mode you want to apply.',
})

ACSEngineBox:AddButton('CHANGE FIRE MODE', function()
    modifyWeaponSettings("Mode", inputField.Value or 'Auto')
end)


local targetStrafe = GeneralTab:AddLeftGroupbox("Target Strafe")
ScriptState.strafeSpeed, ScriptState.strafeRadius = 50, 5
ScriptState.strafeMode, ScriptState.targetPlayer = "Horizontal", nil
local function startTargetStrafe()
    if not ScriptState.strafeAllowed then return end
    ScriptState.targetPlayer = getClosestPlayer()
    if ScriptState.targetPlayer and ScriptState.targetPlayer.Parent then
        ScriptState.originalCameraMode = game:GetService("Players").LocalPlayer.CameraMode
        game:GetService("Players").LocalPlayer.CameraMode = Enum.CameraMode.Classic
        local targetPos = ScriptState.targetPlayer.Position
        LocalPlayer.Character:SetPrimaryPartCFrame(CFrame.new(targetPos))
        Camera.CameraSubject = ScriptState.targetPlayer.Parent:FindFirstChild("Humanoid")
    end
end

local function strafeAroundTarget()
    if not (ScriptState.strafeAllowed and ScriptState.targetPlayer and ScriptState.targetPlayer.Parent) then return end
    local targetPos = ScriptState.targetPlayer.Position
    local angle = tick() * (ScriptState.strafeSpeed / 10)
    local offset = ScriptState.strafeMode == "Horizontal"
        and Vector3.new(math.cos(angle) * ScriptState.strafeRadius, 0, math.sin(angle) * ScriptState.strafeRadius)
        or Vector3.new(math.cos(angle) * ScriptState.strafeRadius, ScriptState.strafeRadius, math.sin(angle) * ScriptState.strafeRadius)
    LocalPlayer.Character:SetPrimaryPartCFrame(CFrame.new(targetPos + offset))
    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(LocalPlayer.Character.HumanoidRootPart.Position, targetPos)
end

local function stopTargetStrafe()
    game:GetService("Players").LocalPlayer.CameraMode = ScriptState.originalCameraMode or Enum.CameraMode.Classic
    Camera.CameraSubject = LocalPlayer.Character.Humanoid
    ScriptState.strafeEnabled, ScriptState.targetPlayer = false, nil
end


targetStrafe:AddToggle("strafeControlToggle", {
    Text = "Enable/Disable",
    Default = true,
    Tooltip = "Enable or disable the ability to use Target Strafe.",
    Callback = function(value)
        ScriptState.strafeAllowed = value
        if not ScriptState.strafeAllowed and ScriptState.strafeEnabled then
            stopTargetStrafe()
        end
    end
})

targetStrafe:AddToggle("strafeToggle", {
    Text = "Enable Target Strafe",
    Default = false,
    Tooltip = "Enable or disable Target Strafe.",
    Callback = function(value)
        if ScriptState.strafeAllowed then
            ScriptState.strafeEnabled = value
            if ScriptState.strafeEnabled then startTargetStrafe() else stopTargetStrafe() end
        end
    end
}):AddKeyPicker("strafeToggleKey", {
    Default = "L",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Target Strafe Toggle Key",
    Tooltip = "Key to toggle Target Strafe",
    Callback = function(value)
        if ScriptState.strafeAllowed then
            ScriptState.strafeEnabled = value
            if ScriptState.strafeEnabled then startTargetStrafe() else stopTargetStrafe() end
        end
    end
})

targetStrafe:AddDropdown("strafeModeDropdown", {
    AllowNull = false,
    Text = "Target Strafe Mode",
    Default = "Horizontal",
    Values = {"Horizontal", "UP"},
    Tooltip = "Select the strafing mode.",
    Callback = function(value) ScriptState.strafeMode = value end
})

targetStrafe:AddSlider("strafeRadiusSlider", {
    Text = "Strafe Radius",
    Default = 5,
    Min = 1,
    Max = 20,
    Rounding = 1,
    Tooltip = "Set the radius of movement around the target.",
    Callback = function(value) ScriptState.strafeRadius = value end
})

targetStrafe:AddSlider("strafeSpeedSlider", {
    Text = "Strafe Speed",
    Default = 50,
    Min = 10,
    Max = 200,
    Rounding = 1,
    Tooltip = "Set the speed of strafing around the target.",
    Callback = function(value) ScriptState.strafeSpeed = value end
})

game:GetService("RunService").RenderStepped:Connect(function()
    if ScriptState.strafeEnabled and ScriptState.strafeAllowed then strafeAroundTarget() end
end)

while true do
    task.wait()

    if ScriptState.isFunctionalityEnabled then
        if localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
            humanoid = localPlayer.Character:FindFirstChild("Humanoid")
            
            if ScriptState.isSpeedActive and humanoid and humanoid.MoveDirection.Magnitude > 0 then
                local moveDirection = humanoid.MoveDirection.Unit
                localPlayer.Character.HumanoidRootPart.CFrame = localPlayer.Character.HumanoidRootPart.CFrame + moveDirection * ScriptState.Cmultiplier
            end

            if ScriptState.isFlyActive then
                local flyDirection = Vector3.zero

                if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.W) then
                    flyDirection = flyDirection + camera.CFrame.LookVector
                end
                if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.S) then
                    flyDirection = flyDirection - camera.CFrame.LookVector
                end
                if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.A) then
                    flyDirection = flyDirection - camera.CFrame.RightVector
                end
                if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.D) then
                    flyDirection = flyDirection + camera.CFrame.RightVector
                end

                if flyDirection.Magnitude > 0 then
                    flyDirection = flyDirection.Unit
                end

                local newPosition = localPlayer.Character.HumanoidRootPart.Position + flyDirection * ScriptState.flySpeed
                localPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(newPosition)
                localPlayer.Character.HumanoidRootPart.Velocity = Vector3.new(0, 0, 0)
            end

            if ScriptState.isNoClipActive then
                for _, v in pairs(localPlayer.Character:GetDescendants()) do
                    if v:IsA("BasePart") and v.CanCollide then
                        v.CanCollide = false
                    end
                end
            end
        end
    end
end

ThemeManager:LoadDefaultTheme()

