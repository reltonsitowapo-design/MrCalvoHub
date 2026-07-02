-- [[ MrCalvoHub v5.0 - ServerHop + Sparkle Alarm + Utilities Tab ]]
-- Credits: Daley + MrCalvoConPelo

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TeleportService = game:GetService("TeleportService")
local SoundService = game:GetService("SoundService")

local LP = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Theme = {
    BG          = Color3.fromRGB(11, 11, 18),
    Card        = Color3.fromRGB(19, 19, 32),
    Sidebar     = Color3.fromRGB(12, 11, 22),
    Header      = Color3.fromRGB(15, 13, 28),
    Purple      = Color3.fromRGB(124, 77, 255),
    PurpleLight = Color3.fromRGB(169, 112, 255),
    Text        = Color3.fromRGB(255, 255, 255),
    TextMuted   = Color3.fromRGB(192, 184, 216),
    TextDim     = Color3.fromRGB(100, 90, 140),
    Border      = Color3.fromRGB(30, 26, 46),
    SliderBG    = Color3.fromRGB(30, 26, 46),
    ToggleOff   = Color3.fromRGB(42, 37, 64),
}

local States = {
    SpeedEnabled = false, SpeedValue = 50,
    FlyEnabled = false, FlySpeed = 50,
    NoclipEnabled = false,
    AutoFightWalk = false, W_Duration = 2, A_Duration = 2, S_Duration = 2, D_Duration = 2,
    KillAuraEnabled = false, TeleportRange = 75,
    TeleportEnabled = true, VelocityNudgeEnabled = true,
    NudgeStrength = 55, TeleportOffset = 5,
    AutoLeaveBattleEnabled = false, AutoSpamEEnabled = false,
    WhitelistEnabled = false, WhitelistString = "",
    -- Utilities
    SparkleAlarmEnabled = false,
    AutoServerHopEnabled = false,
}

-- ==================== SERVIDOR PRIVADO ====================
-- Link: https://www.roblox.com/share?code=8148aea3c1a9584fa12362fedd75303b&type=Server
local PRIVATE_SERVER_CODE = "8148aea3c1a9584fa12362fedd75303b"
local GAME_PLACE_ID = game.PlaceId   -- Se detecta automáticamente del juego actual

-- ==================== ALARMA DE SONIDO ====================
-- Crea un sonido de alarma generado proceduralmente (beeps con Sound de Roblox)
local AlarmSound = Instance.new("Sound")
AlarmSound.SoundId = "rbxassetid://9120386339"  -- Chime/notification sound
AlarmSound.Volume = 1.5
AlarmSound.RollOffMaxDistance = 0
AlarmSound.Parent = SoundService

local AlarmSound2 = Instance.new("Sound")
AlarmSound2.SoundId = "rbxassetid://5153644985"  -- Alert beep
AlarmSound2.Volume = 1.2
AlarmSound2.RollOffMaxDistance = 0
AlarmSound2.Parent = SoundService

local alarmActive = false

local function PlayAlarm()
    if alarmActive then return end
    alarmActive = true
    task.spawn(function()
        for i = 1, 5 do
            if not alarmActive then break end
            AlarmSound:Play()
            task.wait(0.18)
            AlarmSound2:Play()
            task.wait(0.55)
        end
        alarmActive = false
    end)
end

local function StopAlarm()
    alarmActive = false
    AlarmSound:Stop()
    AlarmSound2:Stop()
end

-- ==================== DETECTOR DE CHAT SPARKLE ====================
-- Escucha mensajes del sistema del juego buscando el patrón de Sparkle Evomon
local sparkleDetected = false
local lastSparkleMsg = ""

local function OnChatMessage(msg)
    if not States.SparkleAlarmEnabled then return end
    local lower = msg:lower()
    -- Detecta: "Sparkle Evomon has appeared on [isla]"
    if lower:find("sparkle evomon has appeared") or lower:find("sparkle evomon") then
        if msg ~= lastSparkleMsg then
            lastSparkleMsg = msg
            sparkleDetected = true
            print("[MrCalvoHub] ¡SPARKLE DETECTADO! → " .. msg)
            PlayAlarm()
        end
    end
end

-- Hookeamos el chat del sistema vía TextChatService y la antigua API de chat
local function HookChat()
    -- Método 1: TextChatService (juegos modernos)
    pcall(function()
        local TCS = game:GetService("TextChatService")
        if TCS then
            for _, ch in ipairs(TCS:GetChildren()) do
                if ch:IsA("TextChannel") then
                    ch.MessageReceived:Connect(function(msg)
                        if msg and msg.Text then
                            OnChatMessage(msg.Text)
                        end
                    end)
                end
            end
            TCS.DescendantAdded:Connect(function(d)
                if d:IsA("TextChannel") then
                    d.MessageReceived:Connect(function(msg)
                        if msg and msg.Text then
                            OnChatMessage(msg.Text)
                        end
                    end)
                end
            end)
        end
    end)

    -- Método 2: Chat legacy de Roblox
    pcall(function()
        local Chat = game:GetService("Chat")
        Chat.Chatted:Connect(function(_, msg)
            OnChatMessage(msg)
        end)
    end)

    -- Método 3: Escuchar PlayerGui/BubbleChat y eventos de mensaje del servidor
    pcall(function()
        local pg = LP:WaitForChild("PlayerGui", 5)
        if not pg then return end

        local function hookFrame(f)
            for _, v in ipairs(f:GetDescendants()) do
                if v:IsA("TextLabel") or v:IsA("TextBox") then
                    -- Observer para labels que aparecen con mensajes de sistema
                    v:GetPropertyChangedSignal("Text"):Connect(function()
                        if v.Text and #v.Text > 5 then
                            OnChatMessage(v.Text)
                        end
                    end)
                end
            end
        end

        pg.DescendantAdded:Connect(function(d)
            if (d:IsA("TextLabel") or d:IsA("TextBox")) and d.Text then
                OnChatMessage(d.Text)
            end
        end)
    end)
end

task.delay(2, HookChat)  -- Espera 2s para que el chat cargue

-- ==================== SERVER HOP ====================
local serverHopCooldown = false

local function DoServerHop()
    if serverHopCooldown then
        print("[MrCalvoHub] ServerHop en cooldown, espera...")
        return
    end
    serverHopCooldown = true
    print("[MrCalvoHub] Iniciando ServerHop al servidor privado...")

    pcall(function()
        -- Método principal: TeleportToPrivateServer con el código del link
        local success, err = pcall(function()
            TeleportService:TeleportToPrivateServer(GAME_PLACE_ID, PRIVATE_SERVER_CODE, {LP})
        end)

        if not success then
            print("[MrCalvoHub] Error en TeleportToPrivateServer: " .. tostring(err))
            -- Fallback: reservar slot y teleportar
            pcall(function()
                local code = TeleportService:ReserveServer(GAME_PLACE_ID)
                TeleportService:TeleportToReservedServer(code, {LP})
            end)
        end
    end)

    task.delay(10, function() serverHopCooldown = false end)
end

local BodyVelocity, BodyGyro

-- ==================== LÓGICA ====================
local function GetRoot() local c = LP.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function GetHumanoid() local c = LP.Character return c and c:FindFirstChildOfClass("Humanoid") end

local function MatchesWhitelist(name)
    if not States.WhitelistEnabled or States.WhitelistString == "" then return true end
    local l = name:lower()
    for w in States.WhitelistString:gmatch("[^,]+") do
        if l:find(w:gsub("^%s*(.-)%s*$", "%1"):lower(), 1, true) then return true end
    end
    return false
end

local function SpamEKey()
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(0.035)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
end

local function KillAuraLoop()
    while States.KillAuraEnabled do
        local root = GetRoot()
        if not root then task.wait(0.25) continue end
        local closest, closestDist = nil, math.huge
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name:find("Pet0_") and MatchesWhitelist(obj.Name) then
                local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                if part then
                    local dist = (part.Position - root.Position).Magnitude
                    if dist <= States.TeleportRange and dist > 4 and dist < closestDist then
                        closest, closestDist = part, dist
                    end
                end
            end
        end
        if closest then
            if States.TeleportEnabled then
                root.CFrame = closest.CFrame * CFrame.new(0, 5, -States.TeleportOffset)
                task.wait(0.08)
            end
            if States.VelocityNudgeEnabled then
                local dir = (closest.Position - root.Position)
                local h = Vector3.new(dir.X, 0, dir.Z)
                if h.Magnitude > 0.1 then
                    h = h.Unit
                    root.CFrame = CFrame.new(root.Position, root.Position + h)
                    task.wait(0.05)
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.W, false, game)
                    task.wait(States.NudgeStrength * 0.005)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, game)
                end
            end
        end
        task.wait(0.2)
    end
end

local function AutoSpamELoop() while States.AutoSpamEEnabled do SpamEKey() task.wait(0.07) end end

local function AutoLeaveBattleLoop()
    while States.AutoLeaveBattleEnabled do
        local pg = LP:WaitForChild("PlayerGui")
        local battleActive = pg:FindFirstChild("Catch", true)
            or pg:FindFirstChild("Catch(2/2)", true)
            or pg:FindFirstChild("CatchButton", true)
            or pg:FindFirstChild("BattleGui", true)
        if battleActive then
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.C, false, game)
            task.wait(0.12)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.C, false, game)
        end
        task.wait(0.7)
    end
end

local function SimulateKey(key, dur)
    if not States.AutoFightWalk then return end
    VirtualInputManager:SendKeyEvent(true, key, false, game)
    task.wait(dur)
    VirtualInputManager:SendKeyEvent(false, key, false, game)
end

local function AutoFightWalkLoop()
    while true do
        if States.AutoFightWalk then
            SimulateKey(Enum.KeyCode.W, States.W_Duration) task.wait(0.1)
            SimulateKey(Enum.KeyCode.A, States.A_Duration) task.wait(0.1)
            SimulateKey(Enum.KeyCode.D, States.D_Duration) task.wait(0.1)
            SimulateKey(Enum.KeyCode.S, States.S_Duration) task.wait(0.1)
        else task.wait(0.5) end
    end
end

RunService.Heartbeat:Connect(function()
    local root = GetRoot()
    local hum = GetHumanoid()
    if not root or not hum then return end
    if States.NoclipEnabled and LP.Character then
        for _, p in ipairs(LP.Character:GetChildren()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end
    if States.FlyEnabled then
        if not BodyVelocity then
            BodyVelocity = Instance.new("BodyVelocity", root)
            BodyVelocity.MaxForce = Vector3.new(1e5,1e5,1e5)
            BodyGyro = Instance.new("BodyGyro", root)
            BodyGyro.MaxTorque = Vector3.new(1e5,1e5,1e5)
        end
        local moveDir = Vector3.new()
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir -= Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir -= Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir += Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir -= Vector3.new(0,1,0) end
        local len = moveDir.Magnitude
        BodyVelocity.Velocity = (len > 0 and moveDir.Unit or Vector3.new()) * States.FlySpeed
        BodyGyro.CFrame = Camera.CFrame
    else
        if BodyVelocity then BodyVelocity:Destroy() BodyVelocity = nil end
        if BodyGyro then BodyGyro:Destroy() BodyGyro = nil end
        if States.SpeedEnabled then
            local md = hum.MoveDirection * States.SpeedValue
            root.Velocity = Vector3.new(md.X, root.Velocity.Y, md.Z)
        end
    end
end)

-- ==================== GUI HELPERS ====================
local function ApplyCorner(parent, radius)
    local c = Instance.new("UICorner", parent)
    c.CornerRadius = UDim.new(0, radius or 12)
    return c
end

local function ApplyStroke(parent, color, thickness)
    local s = Instance.new("UIStroke", parent)
    s.Color = color or Theme.Border
    s.Thickness = thickness or 1
    return s
end

local function MakeLabel(parent, text, size, color, font, xAlign)
    local l = Instance.new("TextLabel", parent)
    l.Text = text
    l.TextSize = size or 14
    l.TextColor3 = color or Theme.Text
    l.Font = font or Enum.Font.Gotham
    l.BackgroundTransparency = 1
    l.TextXAlignment = xAlign or Enum.TextXAlignment.Left
    l.TextYAlignment = Enum.TextYAlignment.Center
    -- Importante: no capturar input
    l.ZIndex = 6
    return l
end

-- ==================== GUI ROOT ====================
local ScreenGui = Instance.new("ScreenGui", game:GetService("CoreGui"))
ScreenGui.Name = "MrCalvoHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.new(0, 860, 0, 620)
Main.Position = UDim2.new(0.5, -430, 0.5, -310)
Main.BackgroundColor3 = Theme.BG
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.BackgroundTransparency = 1  -- empieza invisible para animacion de entrada
ApplyCorner(Main, 16)

-- ==================== ANIMACION OPEN/CLOSE ====================
local isAnimating = false

local function ShowMain()
    if isAnimating then return end
    isAnimating = true
    Main.Visible = true
    Main.BackgroundTransparency = 1
    Main.Size = UDim2.new(0, 860, 0, 580)
    TweenService:Create(Main, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0,
        Size = UDim2.new(0, 860, 0, 620),
    }):Play()
    task.delay(0.35, function() isAnimating = false end)
end

local function HideMain(cb)
    if isAnimating then return end
    isAnimating = true
    TweenService:Create(Main, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 860, 0, 580),
    }):Play()
    task.delay(0.26, function()
        Main.Visible = false
        isAnimating = false
        if cb then cb() end
    end)
end

ShowMain()

-- ==================== FONDO ESTRELLAS ====================
local StarContainer = Instance.new("Frame", Main)
StarContainer.Size = UDim2.new(1, 0, 1, 0)
StarContainer.BackgroundTransparency = 1
StarContainer.ZIndex = 1
StarContainer.ClipsDescendants = true

local stars = {}
for i = 1, 22 do
    local sz = 2 + math.random(0, 3)
    local s = Instance.new("Frame", StarContainer)
    s.BackgroundColor3 = Theme.PurpleLight
    s.Size = UDim2.new(0, sz, 0, sz)
    s.BackgroundTransparency = 0.1
    s.BorderSizePixel = 0
    s.ZIndex = 1
    ApplyCorner(s, sz)

    -- Glow ring
    local stroke = Instance.new("UIStroke", s)
    stroke.Color = Theme.Purple
    stroke.Thickness = sz > 3 and 2 or 1
    stroke.Transparency = 0.3

    local data = {
        frame = s,
        stroke = stroke,
        speed  = 0.010 + math.random() * 0.018,
        yBase  = math.random() * 0.90,
        phase  = math.random() * math.pi * 2,
        glowDir = 1,
        glowT  = math.random() * math.pi * 2,
        glowSpeed = 0.4 + math.random() * 0.8,
    }
    stars[i] = data
end

RunService.Heartbeat:Connect(function(dt)
    if not Main.Visible then return end
    local t = tick()
    for _, d in ipairs(stars) do
        -- Movimiento horizontal suave
        local x = ((t * d.speed + d.phase) % 2.5) - 0.7
        local y = d.yBase + math.sin(t * 0.7 + d.phase) * 0.055
        d.frame.Position = UDim2.new(x, 0, y, 0)
        -- Glow pulsante (transparencia oscila)
        local glow = math.sin(t * d.glowSpeed + d.glowT)
        d.frame.BackgroundTransparency = 0.05 + (glow * 0.5 + 0.5) * 0.55
        d.stroke.Transparency = 0.1 + (1 - (glow * 0.5 + 0.5)) * 0.65
    end
end)

-- ==================== HEADER ====================
local Header = Instance.new("Frame", Main)
Header.Size = UDim2.new(1, 0, 0, 60)
Header.BackgroundColor3 = Theme.Header
Header.BorderSizePixel = 0
Header.ZIndex = 5

local HeaderLine = Instance.new("Frame", Header)
HeaderLine.Size = UDim2.new(1, 0, 0, 1)
HeaderLine.Position = UDim2.new(0, 0, 1, -1)
HeaderLine.BackgroundColor3 = Theme.Border
HeaderLine.BorderSizePixel = 0
HeaderLine.ZIndex = 5

local Title = Instance.new("TextLabel", Header)
Title.Text = "MrCalvoHub"
Title.Font = Enum.Font.GothamBlack
Title.TextSize = 28
Title.TextColor3 = Theme.Text
Title.Size = UDim2.new(0, 260, 1, 0)
Title.Position = UDim2.new(0, 24, 0, 0)
Title.BackgroundTransparency = 1
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 6

local TitleGrad = Instance.new("UIGradient", Title)
TitleGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 160, 255)),
    ColorSequenceKeypoint.new(1, Theme.Purple),
})

local function MakeHeaderBtn(text, offsetX)
    local btn = Instance.new("TextButton", Header)
    btn.Size = UDim2.new(0, 34, 0, 34)
    btn.Position = UDim2.new(1, offsetX, 0.5, 0)
    btn.AnchorPoint = Vector2.new(0, 0.5)
    btn.BackgroundColor3 = Color3.fromRGB(30, 26, 46)
    btn.Text = text
    btn.TextColor3 = Theme.TextMuted
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 16
    btn.BorderSizePixel = 0
    btn.ZIndex = 7
    ApplyCorner(btn, 10)
    ApplyStroke(btn, Theme.Border, 1)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(46,34,72), TextColor3 = Theme.Text}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(30,26,46), TextColor3 = Theme.TextMuted}):Play()
    end)
    return btn
end

local MinimizeBtn = MakeHeaderBtn("−", -82)
local CloseBtn    = MakeHeaderBtn("✕", -44)

-- Minimized pill
local MinimizedBtn = Instance.new("TextButton", ScreenGui)
MinimizedBtn.Text = "MrCalvoHub"
MinimizedBtn.Font = Enum.Font.GothamBold
MinimizedBtn.TextSize = 13
MinimizedBtn.TextColor3 = Theme.Text
MinimizedBtn.Size = UDim2.new(0, 118, 0, 32)
MinimizedBtn.Position = UDim2.new(0.5, -59, 0, 14)
MinimizedBtn.BackgroundColor3 = Theme.Purple
MinimizedBtn.Visible = false
MinimizedBtn.ZIndex = 10
MinimizedBtn.BackgroundTransparency = 0
ApplyCorner(MinimizedBtn, 10)
local MinGrad = Instance.new("UIGradient", MinimizedBtn)
MinGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Theme.Purple),
    ColorSequenceKeypoint.new(1, Theme.PurpleLight),
})

MinimizeBtn.MouseButton1Click:Connect(function()
    HideMain(function()
        MinimizedBtn.Visible = true
    end)
end)

MinimizedBtn.MouseButton1Click:Connect(function()
    MinimizedBtn.Visible = false
    ShowMain()
end)

CloseBtn.MouseButton1Click:Connect(function()
    HideMain(function() ScreenGui:Destroy() end)
end)

-- Draggable
local dragData = {}
Header.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        dragData.active = true
        dragData.start = i.Position
        dragData.pos = Main.Position
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if dragData.active and i.UserInputType == Enum.UserInputType.MouseMovement then
        local d = i.Position - dragData.start
        Main.Position = UDim2.new(
            dragData.pos.X.Scale, dragData.pos.X.Offset + d.X,
            dragData.pos.Y.Scale, dragData.pos.Y.Offset + d.Y
        )
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then dragData.active = false end
end)

-- ==================== SIDEBAR ====================
local Sidebar = Instance.new("Frame", Main)
Sidebar.Size = UDim2.new(0, 170, 1, -62)
Sidebar.Position = UDim2.new(0, 0, 0, 61)
Sidebar.BackgroundColor3 = Theme.Sidebar
Sidebar.BorderSizePixel = 0
Sidebar.ZIndex = 4

local SidebarLine = Instance.new("Frame", Sidebar)
SidebarLine.Size = UDim2.new(0, 1, 1, 0)
SidebarLine.Position = UDim2.new(1, -1, 0, 0)
SidebarLine.BackgroundColor3 = Theme.Border
SidebarLine.BorderSizePixel = 0

-- Nav buttons: usamos TextButton directamente para que capture clicks sin problema
-- Los labels usan TextTransparency=1 en el btn y ponemos subframes
local navBtns = {}

local function CreateNavBtn(icon, label, yPos, active)
    local btn = Instance.new("TextButton", Sidebar)
    btn.Size = UDim2.new(1, -24, 0, 42)
    btn.Position = UDim2.new(0, 12, 0, yPos)
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.BackgroundColor3 = Theme.Purple
    btn.BackgroundTransparency = active and 0 or 1
    btn.BorderSizePixel = 0
    btn.ZIndex = 6
    ApplyCorner(btn, 10)

    if active then
        local g = Instance.new("UIGradient", btn)
        g.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Theme.Purple),
            ColorSequenceKeypoint.new(1, Theme.PurpleLight),
        })
        g.Rotation = 135
    end

    -- Icono (no captura input - TextLabel)
    local iconL = Instance.new("TextLabel", btn)
    iconL.Text = icon
    iconL.TextSize = 17
    iconL.Font = Enum.Font.GothamBold
    iconL.TextColor3 = active and Theme.Text or Theme.TextDim
    iconL.BackgroundTransparency = 1
    iconL.Size = UDim2.new(0, 30, 1, 0)
    iconL.Position = UDim2.new(0, 10, 0, 0)
    iconL.TextXAlignment = Enum.TextXAlignment.Center
    iconL.TextYAlignment = Enum.TextYAlignment.Center
    iconL.ZIndex = 7

    -- Texto (no captura input)
    local textL = Instance.new("TextLabel", btn)
    textL.Text = label
    textL.TextSize = 14
    textL.Font = Enum.Font.GothamSemibold
    textL.TextColor3 = active and Theme.Text or Theme.TextMuted
    textL.BackgroundTransparency = 1
    textL.Size = UDim2.new(1, -46, 1, 0)
    textL.Position = UDim2.new(0, 42, 0, 0)
    textL.TextXAlignment = Enum.TextXAlignment.Left
    textL.TextYAlignment = Enum.TextYAlignment.Center
    textL.ZIndex = 7

    btn.MouseEnter:Connect(function()
        if btn.BackgroundTransparency > 0.5 then
            TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.7}):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if btn.BackgroundTransparency > 0.1 then
            TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
        end
    end)

    return btn, iconL, textL
end

local MoveBtn, MoveBtnIcon, MoveBtnText = CreateNavBtn("🏃", "Movement",  14, true)
local EvoBtn,  EvoBtnIcon,  EvoBtnText  = CreateNavBtn("🐾", "Evomon",    62, false)
local UtilBtn, UtilBtnIcon, UtilBtnText = CreateNavBtn("⚡", "Utilities", 110, false)

-- ==================== CONTENT AREA ====================
local ContentArea = Instance.new("Frame", Main)
ContentArea.Size = UDim2.new(1, -182, 1, -68)
ContentArea.Position = UDim2.new(0, 178, 0, 65)
ContentArea.BackgroundTransparency = 1
ContentArea.ZIndex = 4
ContentArea.ClipsDescendants = true

local function MakeScroll(visible)
    local s = Instance.new("ScrollingFrame", ContentArea)
    s.Size = UDim2.new(1, 0, 1, 0)
    s.BackgroundTransparency = 1
    s.ScrollBarThickness = 4
    s.ScrollBarImageColor3 = Theme.Purple
    s.ScrollBarImageTransparency = 0.4
    s.Visible = visible
    s.AutomaticCanvasSize = Enum.AutomaticSize.Y
    s.BorderSizePixel = 0
    s.ZIndex = 5

    local layout = Instance.new("UIListLayout", s)
    layout.Padding = UDim.new(0, 16)
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    local pad = Instance.new("UIPadding", s)
    pad.PaddingLeft = UDim.new(0, 4)
    pad.PaddingRight = UDim.new(0, 14)
    pad.PaddingTop = UDim.new(0, 6)
    pad.PaddingBottom = UDim.new(0, 16)

    return s
end

local ScrollMove = MakeScroll(true)
local ScrollEvo  = MakeScroll(false)
local ScrollUtil = MakeScroll(false)

-- Tab switching — activa/desactiva visual del boton
local function SetActiveNav(tab)
    -- tab: "move", "evo", "util"
    local function activate(btn, icon, text, on)
        local g = btn:FindFirstChildOfClass("UIGradient")
        if on then
            btn.BackgroundTransparency = 0
            btn.BackgroundColor3 = Theme.Purple
            if not g then
                g = Instance.new("UIGradient", btn)
                g.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Theme.Purple),
                    ColorSequenceKeypoint.new(1, Theme.PurpleLight),
                })
                g.Rotation = 135
            end
            icon.TextColor3 = Theme.Text
            text.TextColor3 = Theme.Text
        else
            btn.BackgroundTransparency = 1
            if g then g:Destroy() end
            icon.TextColor3 = Theme.TextDim
            text.TextColor3 = Theme.TextMuted
        end
    end
    activate(MoveBtn, MoveBtnIcon, MoveBtnText, tab == "move")
    activate(EvoBtn,  EvoBtnIcon,  EvoBtnText,  tab == "evo")
    activate(UtilBtn, UtilBtnIcon, UtilBtnText, tab == "util")
    ScrollMove.Visible = (tab == "move")
    ScrollEvo.Visible  = (tab == "evo")
    ScrollUtil.Visible = (tab == "util")
end

MoveBtn.MouseButton1Click:Connect(function() SetActiveNav("move") end)
EvoBtn.MouseButton1Click:Connect(function()  SetActiveNav("evo")  end)
UtilBtn.MouseButton1Click:Connect(function() SetActiveNav("util") end)

-- ==================== CARD ====================
local function MakeCard(parent, order)
    local card = Instance.new("Frame", parent)
    card.BackgroundColor3 = Theme.Card
    card.BorderSizePixel = 0
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.Size = UDim2.new(1, 0, 0, 0)
    card.LayoutOrder = order or 0
    card.ZIndex = 6
    ApplyCorner(card, 14)
    ApplyStroke(card, Theme.Border, 1)

    local layout = Instance.new("UIListLayout", card)
    layout.Padding = UDim.new(0, 0)
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    local pad = Instance.new("UIPadding", card)
    pad.PaddingLeft = UDim.new(0, 18)
    pad.PaddingRight = UDim.new(0, 18)
    pad.PaddingTop = UDim.new(0, 14)
    pad.PaddingBottom = UDim.new(0, 14)

    return card
end

local function MakeCardTitle(card, text)
    local f = Instance.new("Frame", card)
    f.Size = UDim2.new(1, 0, 0, 32)
    f.BackgroundTransparency = 1
    f.LayoutOrder = 0
    f.ZIndex = 7

    local lbl = MakeLabel(f, text, 11, Theme.Purple, Enum.Font.GothamBold)
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.ZIndex = 7

    local line = Instance.new("Frame", f)
    line.Size = UDim2.new(1, 0, 0, 1)
    line.Position = UDim2.new(0, 0, 1, -1)
    line.BackgroundColor3 = Theme.Border
    line.BorderSizePixel = 0
    line.ZIndex = 7
end

local rowOrder = 0
local function NextOrder() rowOrder += 1 return rowOrder end

-- ==================== TOGGLE (FIX CLICK AREA) ====================
-- Usamos un TextButton invisible como capa de click encima de todo
local function MakeToggle(parent, labelText, default, callback, order)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, 0, 0, 44)
    row.BackgroundTransparency = 1
    row.LayoutOrder = order or NextOrder()
    row.ZIndex = 7

    -- Label izquierdo
    local lbl = MakeLabel(row, labelText, 14, Theme.TextMuted)
    lbl.Size = UDim2.new(1, -62, 1, 0)
    lbl.Position = UDim2.new(0, 0, 0, 0)
    lbl.ZIndex = 8

    -- Track del toggle
    local track = Instance.new("Frame", row)
    track.Size = UDim2.new(0, 44, 0, 24)
    track.Position = UDim2.new(1, -44, 0.5, 0)
    track.AnchorPoint = Vector2.new(0, 0.5)
    track.BackgroundColor3 = default and Theme.Purple or Theme.ToggleOff
    track.BorderSizePixel = 0
    track.ZIndex = 8
    ApplyCorner(track, 12)

    if default then
        local g = Instance.new("UIGradient", track)
        g.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Theme.Purple),
            ColorSequenceKeypoint.new(1, Theme.PurpleLight),
        })
    end

    local knob = Instance.new("Frame", track)
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = default and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
    knob.AnchorPoint = Vector2.new(0, 0.5)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.ZIndex = 9
    ApplyCorner(knob, 9)

    local state = default

    local function doToggle()
        state = not state
        callback(state)
        local grad = track:FindFirstChildOfClass("UIGradient")
        if state then
            if not grad then
                grad = Instance.new("UIGradient", track)
                grad.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Theme.Purple),
                    ColorSequenceKeypoint.new(1, Theme.PurpleLight),
                })
            end
        else
            if grad then grad:Destroy() end
        end
        TweenService:Create(track, TweenInfo.new(0.18), {
            BackgroundColor3 = state and Theme.Purple or Theme.ToggleOff,
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {
            Position = state and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
        }):Play()
    end

    -- FIX: Botón invisible que cubre TODO el ancho del row → garantiza click en cualquier punto
    local hitBtn = Instance.new("TextButton", row)
    hitBtn.Size = UDim2.new(1, 0, 1, 0)
    hitBtn.Position = UDim2.new(0, 0, 0, 0)
    hitBtn.BackgroundTransparency = 1
    hitBtn.Text = ""
    hitBtn.ZIndex = 10  -- encima de todo
    hitBtn.AutoButtonColor = false
    hitBtn.MouseButton1Click:Connect(doToggle)

    return row
end

-- ==================== SLIDER ====================
local function MakeSlider(parent, labelText, minV, maxV, default, callback, order)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, 0, 0, 54)
    f.BackgroundTransparency = 1
    f.LayoutOrder = order or NextOrder()
    f.ZIndex = 7

    local headerRow = Instance.new("Frame", f)
    headerRow.Size = UDim2.new(1, 0, 0, 22)
    headerRow.BackgroundTransparency = 1
    headerRow.ZIndex = 8

    local lbl = MakeLabel(headerRow, labelText, 13, Theme.TextMuted)
    lbl.Size = UDim2.new(1, -50, 1, 0)
    lbl.ZIndex = 8

    local valLbl = MakeLabel(headerRow, tostring(default), 13, Theme.PurpleLight, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
    valLbl.Size = UDim2.new(0, 48, 1, 0)
    valLbl.Position = UDim2.new(1, -48, 0, 0)
    valLbl.ZIndex = 8

    local barBG = Instance.new("Frame", f)
    barBG.Size = UDim2.new(1, 0, 0, 6)
    barBG.Position = UDim2.new(0, 0, 0, 34)
    barBG.BackgroundColor3 = Theme.SliderBG
    barBG.BorderSizePixel = 0
    barBG.ZIndex = 8
    ApplyCorner(barBG, 3)

    local fill = Instance.new("Frame", barBG)
    fill.BackgroundColor3 = Theme.Purple
    fill.Size = UDim2.new((default - minV) / (maxV - minV), 0, 1, 0)
    fill.BorderSizePixel = 0
    fill.ZIndex = 9
    ApplyCorner(fill, 3)
    local fg = Instance.new("UIGradient", fill)
    fg.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Theme.Purple),
        ColorSequenceKeypoint.new(1, Theme.PurpleLight),
    })

    local knob = Instance.new("Frame", barBG)
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new((default - minV) / (maxV - minV), -7, 0.5, 0)
    knob.AnchorPoint = Vector2.new(0, 0.5)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.ZIndex = 10
    ApplyCorner(knob, 7)
    ApplyStroke(knob, Theme.Purple, 2)

    local dragging = false
    local function updateSlider(inputPos)
        local rel = math.clamp((inputPos.X - barBG.AbsolutePosition.X) / barBG.AbsoluteSize.X, 0, 1)
        local val = math.floor(minV + (maxV - minV) * rel + 0.5)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, -7, 0.5, 0)
        valLbl.Text = tostring(val)
        callback(val)
    end

    knob.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
    end)
    barBG.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            updateSlider(i.Position)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            updateSlider(i.Position)
        end
    end)

    return f
end

-- ==================== MOVEMENT TAB ====================
local CardLoco = MakeCard(ScrollMove, 1)
MakeCardTitle(CardLoco, "LOCOMOTION")
MakeToggle(CardLoco, "Speed", States.SpeedEnabled, function(v) States.SpeedEnabled = v end)
MakeSlider(CardLoco, "Speed Value", 16, 300, 50, function(v) States.SpeedValue = v end)
MakeToggle(CardLoco, "Fly", States.FlyEnabled, function(v) States.FlyEnabled = v end)
MakeSlider(CardLoco, "Fly Speed", 10, 300, 50, function(v) States.FlySpeed = v end)
MakeToggle(CardLoco, "Noclip", States.NoclipEnabled, function(v) States.NoclipEnabled = v end)

local CardAFW = MakeCard(ScrollMove, 2)
MakeCardTitle(CardAFW, "AUTO FIGHT WALK")
MakeToggle(CardAFW, "Auto Fight Walk", States.AutoFightWalk, function(v)
    States.AutoFightWalk = v
    if v then task.spawn(AutoFightWalkLoop) end
end)
MakeSlider(CardAFW, "W Duration", 1, 10, 2, function(v) States.W_Duration = v end)
MakeSlider(CardAFW, "A Duration", 1, 10, 2, function(v) States.A_Duration = v end)
MakeSlider(CardAFW, "S Duration", 1, 10, 2, function(v) States.S_Duration = v end)
MakeSlider(CardAFW, "D Duration", 1, 10, 2, function(v) States.D_Duration = v end)

-- ==================== EVOMON TAB ====================
local CardEngage = MakeCard(ScrollEvo, 1)
MakeCardTitle(CardEngage, "AUTO ENGAGE")
MakeToggle(CardEngage, "Kill Aura", States.KillAuraEnabled, function(v)
    States.KillAuraEnabled = v
    if v then task.spawn(KillAuraLoop) end
end)
MakeSlider(CardEngage, "Kill Aura Range", 10, 200, 75, function(v) States.TeleportRange = v end)
MakeToggle(CardEngage, "Auto Spam E", States.AutoSpamEEnabled, function(v)
    States.AutoSpamEEnabled = v
    if v then task.spawn(AutoSpamELoop) end
end)
MakeToggle(CardEngage, "Auto Leave Battle (C Key)", States.AutoLeaveBattleEnabled, function(v)
    States.AutoLeaveBattleEnabled = v
    if v then task.spawn(AutoLeaveBattleLoop) end
end)

local CardWhitelist = MakeCard(ScrollEvo, 2)
MakeCardTitle(CardWhitelist, "TARGET WHITELIST")
MakeToggle(CardWhitelist, "Use Target Whitelist", States.WhitelistEnabled, function(v) States.WhitelistEnabled = v end)

local WrapInput = Instance.new("Frame", CardWhitelist)
WrapInput.Size = UDim2.new(1, 0, 0, 52)
WrapInput.BackgroundTransparency = 1
WrapInput.LayoutOrder = NextOrder()

local WhitelistInput = Instance.new("TextBox", WrapInput)
WhitelistInput.Size = UDim2.new(1, 0, 0, 40)
WhitelistInput.Position = UDim2.new(0, 0, 0, 6)
WhitelistInput.BackgroundColor3 = Color3.fromRGB(14, 12, 24)
WhitelistInput.PlaceholderText = "Pikachu, Dragonite, 025"
WhitelistInput.PlaceholderColor3 = Theme.TextDim
WhitelistInput.Text = States.WhitelistString
WhitelistInput.Font = Enum.Font.Gotham
WhitelistInput.TextSize = 13
WhitelistInput.TextColor3 = Theme.Text
WhitelistInput.BorderSizePixel = 0
WhitelistInput.ZIndex = 8
WhitelistInput.ClearTextOnFocus = false
ApplyCorner(WhitelistInput, 10)
ApplyStroke(WhitelistInput, Theme.Border, 1)
local WPad = Instance.new("UIPadding", WhitelistInput)
WPad.PaddingLeft = UDim.new(0, 12)
WPad.PaddingRight = UDim.new(0, 12)
WhitelistInput.FocusLost:Connect(function() States.WhitelistString = WhitelistInput.Text end)

local WrapScan = Instance.new("Frame", CardWhitelist)
WrapScan.Size = UDim2.new(1, 0, 0, 52)
WrapScan.BackgroundTransparency = 1
WrapScan.LayoutOrder = NextOrder()

local ScanBtn = Instance.new("TextButton", WrapScan)
ScanBtn.Size = UDim2.new(1, 0, 0, 40)
ScanBtn.Position = UDim2.new(0, 0, 0, 6)
ScanBtn.BackgroundColor3 = Theme.Purple
ScanBtn.Text = "Scan Nearby Evomons (F9)"
ScanBtn.Font = Enum.Font.GothamBold
ScanBtn.TextSize = 14
ScanBtn.TextColor3 = Theme.Text
ScanBtn.BorderSizePixel = 0
ScanBtn.ZIndex = 8
ScanBtn.AutoButtonColor = false
ApplyCorner(ScanBtn, 10)
local ScanGrad = Instance.new("UIGradient", ScanBtn)
ScanGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Theme.Purple),
    ColorSequenceKeypoint.new(1, Theme.PurpleLight),
})
ScanGrad.Rotation = 90
ScanBtn.MouseEnter:Connect(function()
    TweenService:Create(ScanBtn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.PurpleLight}):Play()
end)
ScanBtn.MouseLeave:Connect(function()
    TweenService:Create(ScanBtn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.Purple}):Play()
end)
ScanBtn.MouseButton1Click:Connect(function()
    local r = GetRoot()
    if not r then return end
    print("=== EVOMONS CERCANOS ===")
    for _, o in ipairs(Workspace:GetDescendants()) do
        if o.Name:find("Pet0_") then
            local p = o:IsA("BasePart") and o or o:FindFirstChildWhichIsA("BasePart")
            if p then
                local d = math.floor((p.Position - r.Position).Magnitude)
                if d < 200 then print(o.Name .. " | " .. d .. " studs") end
            end
        end
    end
end)

local CardTele = MakeCard(ScrollEvo, 3)
MakeCardTitle(CardTele, "TELEPORT SETTINGS")
MakeToggle(CardTele, "Teleport to Pet", States.TeleportEnabled, function(v) States.TeleportEnabled = v end)
MakeSlider(CardTele, "Teleport Offset", 2, 15, 5, function(v) States.TeleportOffset = v end)

local CardNudge = MakeCard(ScrollEvo, 4)
MakeCardTitle(CardNudge, "VELOCITY NUDGE")
MakeToggle(CardNudge, "Velocity Nudge (Walk into Combat)", States.VelocityNudgeEnabled, function(v) States.VelocityNudgeEnabled = v end)
MakeSlider(CardNudge, "Nudge Strength", 10, 100, 55, function(v) States.NudgeStrength = v end)

-- ==================== UTILITIES TAB ====================

-- ---- Card 1: Sparkle Evomon Alarm ----
local CardSparkle = MakeCard(ScrollUtil, 1)
MakeCardTitle(CardSparkle, "✨ SPARKLE EVOMON ALARM")

-- Estado visual del detector
local SparkleStatusWrap = Instance.new("Frame", CardSparkle)
SparkleStatusWrap.Size = UDim2.new(1, 0, 0, 38)
SparkleStatusWrap.BackgroundTransparency = 1
SparkleStatusWrap.LayoutOrder = NextOrder()

local SparkleStatusDot = Instance.new("Frame", SparkleStatusWrap)
SparkleStatusDot.Size = UDim2.new(0, 10, 0, 10)
SparkleStatusDot.Position = UDim2.new(0, 0, 0.5, 0)
SparkleStatusDot.AnchorPoint = Vector2.new(0, 0.5)
SparkleStatusDot.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
SparkleStatusDot.BorderSizePixel = 0
ApplyCorner(SparkleStatusDot, 5)

local SparkleStatusLbl = MakeLabel(SparkleStatusWrap, "Detector inactivo — activa el toggle", 12, Theme.TextDim)
SparkleStatusLbl.Size = UDim2.new(1, -18, 1, 0)
SparkleStatusLbl.Position = UDim2.new(0, 16, 0, 0)
SparkleStatusLbl.ZIndex = 8

MakeToggle(CardSparkle, "Alarm de Sparkle Evomon", false, function(v)
    States.SparkleAlarmEnabled = v
    sparkleDetected = false
    lastSparkleMsg = ""
    if not v then
        StopAlarm()
        SparkleStatusDot.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
        SparkleStatusLbl.Text = "Detector inactivo — activa el toggle"
        SparkleStatusLbl.TextColor3 = Theme.TextDim
    else
        SparkleStatusDot.BackgroundColor3 = Color3.fromRGB(80, 200, 120)
        SparkleStatusLbl.Text = "Escuchando el chat... esperando Sparkle"
        SparkleStatusLbl.TextColor3 = Theme.TextMuted
    end
end)

-- Botón para testear la alarma
local WrapTestAlarm = Instance.new("Frame", CardSparkle)
WrapTestAlarm.Size = UDim2.new(1, 0, 0, 50)
WrapTestAlarm.BackgroundTransparency = 1
WrapTestAlarm.LayoutOrder = NextOrder()

local TestAlarmBtn = Instance.new("TextButton", WrapTestAlarm)
TestAlarmBtn.Size = UDim2.new(1, 0, 0, 38)
TestAlarmBtn.Position = UDim2.new(0, 0, 0, 6)
TestAlarmBtn.BackgroundColor3 = Color3.fromRGB(40, 30, 65)
TestAlarmBtn.Text = "🔔  Probar Sonido de Alarma"
TestAlarmBtn.Font = Enum.Font.GothamSemibold
TestAlarmBtn.TextSize = 13
TestAlarmBtn.TextColor3 = Theme.TextMuted
TestAlarmBtn.BorderSizePixel = 0
TestAlarmBtn.ZIndex = 8
TestAlarmBtn.AutoButtonColor = false
ApplyCorner(TestAlarmBtn, 10)
ApplyStroke(TestAlarmBtn, Theme.Border, 1)
TestAlarmBtn.MouseEnter:Connect(function()
    TweenService:Create(TestAlarmBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(60, 44, 90), TextColor3 = Theme.Text}):Play()
end)
TestAlarmBtn.MouseLeave:Connect(function()
    TweenService:Create(TestAlarmBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(40, 30, 65), TextColor3 = Theme.TextMuted}):Play()
end)
TestAlarmBtn.MouseButton1Click:Connect(function()
    alarmActive = false  -- forzar nueva reproducción
    PlayAlarm()
end)

-- Botón para silenciar
local WrapStopAlarm = Instance.new("Frame", CardSparkle)
WrapStopAlarm.Size = UDim2.new(1, 0, 0, 50)
WrapStopAlarm.BackgroundTransparency = 1
WrapStopAlarm.LayoutOrder = NextOrder()

local StopAlarmBtn = Instance.new("TextButton", WrapStopAlarm)
StopAlarmBtn.Size = UDim2.new(1, 0, 0, 38)
StopAlarmBtn.Position = UDim2.new(0, 0, 0, 6)
StopAlarmBtn.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
StopAlarmBtn.Text = "🔇  Silenciar Alarma"
StopAlarmBtn.Font = Enum.Font.GothamSemibold
StopAlarmBtn.TextSize = 13
StopAlarmBtn.TextColor3 = Color3.fromRGB(220, 130, 130)
StopAlarmBtn.BorderSizePixel = 0
StopAlarmBtn.ZIndex = 8
StopAlarmBtn.AutoButtonColor = false
ApplyCorner(StopAlarmBtn, 10)
StopAlarmBtn.MouseEnter:Connect(function()
    TweenService:Create(StopAlarmBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(90, 30, 30)}):Play()
end)
StopAlarmBtn.MouseLeave:Connect(function()
    TweenService:Create(StopAlarmBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(60, 20, 20)}):Play()
end)
StopAlarmBtn.MouseButton1Click:Connect(function()
    StopAlarm()
    sparkleDetected = false
    if States.SparkleAlarmEnabled then
        SparkleStatusDot.BackgroundColor3 = Color3.fromRGB(80, 200, 120)
        SparkleStatusLbl.Text = "Escuchando el chat... esperando Sparkle"
        SparkleStatusLbl.TextColor3 = Theme.TextMuted
    end
end)

-- Monitor de SparkleStatus en tiempo real
RunService.Heartbeat:Connect(function()
    if sparkleDetected and States.SparkleAlarmEnabled then
        -- Pulso rojo en el indicador
        local t = tick()
        local pulse = math.abs(math.sin(t * 4))
        SparkleStatusDot.BackgroundColor3 = Color3.fromRGB(255, math.floor(50 + pulse * 80), math.floor(50 + pulse * 50))
        SparkleStatusLbl.Text = "⚠️ SPARKLE DETECTADO → " .. lastSparkleMsg:sub(1, 45)
        SparkleStatusLbl.TextColor3 = Color3.fromRGB(255, 200, 80)
    end
end)

-- ---- Card 2: Private Server Hop ----
local CardServerHop = MakeCard(ScrollUtil, 2)
MakeCardTitle(CardServerHop, "🌐 SERVER HOP")

-- Info del servidor
local ServerInfoWrap = Instance.new("Frame", CardServerHop)
ServerInfoWrap.Size = UDim2.new(1, 0, 0, 48)
ServerInfoWrap.BackgroundColor3 = Color3.fromRGB(14, 12, 24)
ServerInfoWrap.BorderSizePixel = 0
ServerInfoWrap.LayoutOrder = NextOrder()
ApplyCorner(ServerInfoWrap, 10)
ApplyStroke(ServerInfoWrap, Theme.Border, 1)

local ServerInfoPad = Instance.new("UIPadding", ServerInfoWrap)
ServerInfoPad.PaddingLeft = UDim.new(0, 12)
ServerInfoPad.PaddingRight = UDim.new(0, 12)
ServerInfoPad.PaddingTop = UDim.new(0, 6)
ServerInfoPad.PaddingBottom = UDim.new(0, 6)

local ServerInfoLayout = Instance.new("UIListLayout", ServerInfoWrap)
ServerInfoLayout.Padding = UDim.new(0, 2)

local SrvLine1 = MakeLabel(ServerInfoWrap, "Servidor Privado: MrCalvoConPelo", 12, Theme.TextMuted)
SrvLine1.Size = UDim2.new(1, 0, 0, 16)
SrvLine1.ZIndex = 8

local SrvLine2 = MakeLabel(ServerInfoWrap, "Código: 8148aea3...75303b", 11, Theme.TextDim)
SrvLine2.Size = UDim2.new(1, 0, 0, 14)
SrvLine2.ZIndex = 8

-- Botón principal ServerHop
local WrapHopBtn = Instance.new("Frame", CardServerHop)
WrapHopBtn.Size = UDim2.new(1, 0, 0, 56)
WrapHopBtn.BackgroundTransparency = 1
WrapHopBtn.LayoutOrder = NextOrder()

local HopBtn = Instance.new("TextButton", WrapHopBtn)
HopBtn.Size = UDim2.new(1, 0, 0, 44)
HopBtn.Position = UDim2.new(0, 0, 0, 6)
HopBtn.BackgroundColor3 = Theme.Purple
HopBtn.Text = "🚀  Ir al Servidor Privado"
HopBtn.Font = Enum.Font.GothamBold
HopBtn.TextSize = 14
HopBtn.TextColor3 = Theme.Text
HopBtn.BorderSizePixel = 0
HopBtn.ZIndex = 8
HopBtn.AutoButtonColor = false
ApplyCorner(HopBtn, 10)

local HopGrad = Instance.new("UIGradient", HopBtn)
HopGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Theme.Purple),
    ColorSequenceKeypoint.new(1, Theme.PurpleLight),
})
HopGrad.Rotation = 90

HopBtn.MouseEnter:Connect(function()
    TweenService:Create(HopBtn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.PurpleLight}):Play()
end)
HopBtn.MouseLeave:Connect(function()
    TweenService:Create(HopBtn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.Purple}):Play()
end)

local hopCooldownLabel = MakeLabel(WrapHopBtn, "", 11, Theme.TextDim, Enum.Font.Gotham, Enum.TextXAlignment.Center)
hopCooldownLabel.Size = UDim2.new(1, 0, 0, 14)
hopCooldownLabel.Position = UDim2.new(0, 0, 1, -8)
hopCooldownLabel.ZIndex = 8

HopBtn.MouseButton1Click:Connect(function()
    if serverHopCooldown then
        hopCooldownLabel.Text = "⏳ Espera antes de volver a hopear..."
        return
    end
    HopBtn.Text = "⏳  Conectando..."
    hopCooldownLabel.Text = "Teleportando al servidor privado..."
    DoServerHop()
    task.delay(3, function()
        if HopBtn and HopBtn.Parent then
            HopBtn.Text = "🚀  Ir al Servidor Privado"
        end
    end)
    task.delay(10, function()
        if hopCooldownLabel and hopCooldownLabel.Parent then
            hopCooldownLabel.Text = ""
        end
    end)
end)

-- Toggle: Auto-hop cuando detecta Sparkle
MakeToggle(CardServerHop, "Auto-Hop al detectar Sparkle", false, function(v)
    States.AutoServerHopEnabled = v
end)

local autoHopNote = Instance.new("Frame", CardServerHop)
autoHopNote.Size = UDim2.new(1, 0, 0, 28)
autoHopNote.BackgroundTransparency = 1
autoHopNote.LayoutOrder = NextOrder()
local autoHopNoteLbl = MakeLabel(autoHopNote, "⚠ Requiere 'Alarm de Sparkle' activa", 11, Theme.TextDim)
autoHopNoteLbl.Size = UDim2.new(1, 0, 1, 0)
autoHopNoteLbl.ZIndex = 8

-- Auto-hop logic: cuando sparkle es detectado y el toggle está activo
local lastAutoHop = 0
RunService.Heartbeat:Connect(function()
    if States.AutoServerHopEnabled and States.SparkleAlarmEnabled and sparkleDetected then
        local now = tick()
        if now - lastAutoHop > 15 then  -- cooldown de 15s para no spamear
            lastAutoHop = now
            task.spawn(DoServerHop)
        end
    end
end)

-- ==================== F9 SHORTCUT ====================
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.F9 then
        ScanBtn:FireButton1Click()
    end
end)

print("[MrCalvoHub v5.0] Cargado. ServerHop + Sparkle Alarm + Utilities activos.")
