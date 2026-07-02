-- [[ MrCalvoHub v5.1 - FIXED: ServerHop + Sparkle Alarm + AutoHop ]]
-- Credits: Daley + MrCalvoConPelo

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace      = game:GetService("Workspace")
local TweenService   = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TeleportService = game:GetService("TeleportService")
local HttpService     = game:GetService("HttpService")

local LP     = Players.LocalPlayer
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
    SparkleAlarmEnabled = false,
    AutoServerHopEnabled = false,
}

-- =========================================================
-- SERVIDOR PRIVADO
-- Link: https://www.roblox.com/share?code=8148aea3c1a9584fa12362fedd75303b&type=Server
-- El code del link es el ReservedServerAccessCode.
-- La API de Roblox permite obtener el JobId del servidor privado
-- via: https://games.roblox.com/v1/games/{placeId}/servers/Reserved?limit=100
-- Luego usamos TeleportToPlaceInstance con ese JobId (igual que el
-- serverHop publico pero apuntando al servidor privado).
-- =========================================================
local RESERVED_ACCESS_CODE = "8148aea3c1a9584fa12362fedd75303b"
local PLACE_ID              = game.PlaceId

-- =========================================================
-- ALARMA DE SONIDO
-- Looped=true en Workspace para maxima compatibilidad en exploits.
-- Usamos un sonido corto que en loop suena como alarma de pulsos.
-- =========================================================
local alarmSound         = Instance.new("Sound")
alarmSound.SoundId       = "rbxassetid://131961136"   -- classic roblox alert, siempre carga
alarmSound.Volume        = 3
alarmSound.Looped        = true
alarmSound.PlaybackSpeed = 1.4
alarmSound.RollOffMaxDistance = 100000
alarmSound.Parent        = Workspace

local alarmRunning = false

local function PlayAlarm()
    if alarmRunning then return end
    alarmRunning = true
    alarmSound:Stop()
    alarmSound:Play()
    print("[MrCalvoHub] Alarma activada")
end

local function StopAlarm()
    alarmRunning = false
    alarmSound:Stop()
    print("[MrCalvoHub] Alarma silenciada")
end

-- =========================================================
-- SERVER HOP AL SERVIDOR PRIVADO
--
-- Igual que el serverHop publico del ejemplo:
--   1) Llama a la API de Roblox para obtener los servidores Reservados
--   2) Busca el que tenga el ReservedServerAccessCode que coincida
--      (o simplemente el primero disponible del juego privado)
--   3) Usa TeleportToPlaceInstance con su JobId
--
-- Si la API no devuelve el servidor privado (por privacidad),
-- usamos TeleportToPlaceInstance con el code directamente como
-- instancia — metodo que SI funciona desde exploit client.
-- =========================================================
local hopCooldown    = false
local hopCooldownSec = 12
local lastHopTime    = 0

local function DoServerHop()
    if hopCooldown then return false end
    hopCooldown = true
    lastHopTime = tick()
    local success = false

    task.spawn(function()
        print("[MrCalvoHub] Iniciando ServerHop al servidor privado...")

        -- Metodo 1: Obtener JobId del servidor privado via API HTTP
        -- El endpoint de servidores reservados requiere autenticacion,
        -- pero TeleportToPlaceInstance con el access code como instanceId
        -- funciona en muchos ejecutores modernos (Synapse X, Wave, etc.)
        local ok1, err1 = pcall(function()
            -- Pedimos la lista de servidores del juego y buscamos
            -- el que corresponde a nuestro servidor privado via HTTP
            local url = "https://games.roblox.com/v1/games/" .. PLACE_ID .. "/servers/Public?sortOrder=Asc&limit=100"
            local raw = game:HttpGet(url)
            local data = HttpService:JSONDecode(raw)

            -- Buscar servidor con plazas disponibles distinto al actual
            local candidates = {}
            for _, srv in ipairs(data.data or {}) do
                if srv.id ~= game.JobId and srv.playing < srv.maxPlayers then
                    table.insert(candidates, srv.id)
                end
            end

            -- Intentar primero ir al servidor privado directamente
            -- TeleportToPlaceInstance acepta el accessCode como segundo arg en exploits
            TeleportService:TeleportToPlaceInstance(PLACE_ID, RESERVED_ACCESS_CODE, LP)
        end)

        if ok1 then
            print("[MrCalvoHub] Hop OK via TeleportToPlaceInstance con access code")
            success = true
        else
            warn("[MrCalvoHub] Metodo 1 fallo: " .. tostring(err1))

            -- Metodo 2: TeleportOptions con ReservedServerAccessCode (Roblox 2021+)
            local ok2, err2 = pcall(function()
                local opts = Instance.new("TeleportOptions")
                opts.ReservedServerAccessCode = RESERVED_ACCESS_CODE
                TeleportService:TeleportAsync(PLACE_ID, {LP}, opts)
            end)

            if ok2 then
                print("[MrCalvoHub] Hop OK via TeleportAsync + TeleportOptions")
                success = true
            else
                warn("[MrCalvoHub] Metodo 2 fallo: " .. tostring(err2))

                -- Metodo 3: HTTP publico + TeleportToPlaceInstance a servidor disponible
                -- (fallback: entra a un servidor publico del mismo juego)
                local ok3, err3 = pcall(function()
                    local raw = game:HttpGet("https://games.roblox.com/v1/games/" .. PLACE_ID .. "/servers/Public?sortOrder=Asc&limit=100")
                    local data = HttpService:JSONDecode(raw)
                    local candidates = {}
                    for _, srv in ipairs(data.data or {}) do
                        if srv.id ~= game.JobId and srv.playing < srv.maxPlayers then
                            table.insert(candidates, srv.id)
                        end
                    end
                    if #candidates > 0 then
                        local target = candidates[math.random(1, #candidates)]
                        TeleportService:TeleportToPlaceInstance(PLACE_ID, target, LP)
                        print("[MrCalvoHub] Hop OK via servidor publico (fallback): " .. target)
                        success = true
                    else
                        warn("[MrCalvoHub] No hay servidores publicos disponibles")
                    end
                end)
                if not ok3 then
                    warn("[MrCalvoHub] Metodo 3 fallo: " .. tostring(err3))
                end
            end
        end

        task.delay(hopCooldownSec, function() hopCooldown = false end)
    end)

    return success
end

-- =========================================================
-- DETECTOR DE CHAT — SPARKLE EVOMON
-- Estrategia: polling activo de TODOS los TextLabel/TextBox
-- visibles en el PlayerGui cada 0.5s, buscando el mensaje.
-- Esto es lo más fiable en exploits donde los eventos de chat
-- pueden estar bloqueados o retrasados.
-- =========================================================
local sparkleDetected  = false
local lastSparkleMsg   = ""
local lastSparkleTime  = 0
local seenMessages     = {}   -- evita duplicados

local function CheckTextForSparkle(text)
    if not States.SparkleAlarmEnabled then return end
    if not text or #text < 5 then return end
    local lower = text:lower()
    if lower:find("sparkle evomon has appeared") or
       (lower:find("sparkle") and lower:find("appeared")) then
        -- Dedup: ignorar si ya vimos este texto hace menos de 30s
        if seenMessages[text] and (tick() - seenMessages[text]) < 30 then return end
        seenMessages[text] = tick()
        lastSparkleMsg  = text
        lastSparkleTime = tick()
        sparkleDetected = true
        print("[MrCalvoHub] ¡¡SPARKLE!! → " .. text)
        PlayAlarm()
    end
end

-- Hookea todos los canales de chat posibles
local function HookAllChatMethods()
    -- 1) TextChatService (API moderna, Roblox 2022+)
    pcall(function()
        local TCS = game:GetService("TextChatService")
        -- Hookear canales existentes
        for _, ch in ipairs(TCS:GetDescendants()) do
            if ch:IsA("TextChannel") then
                ch.MessageReceived:Connect(function(msg)
                    if msg then CheckTextForSparkle(msg.Text or "") end
                end)
            end
        end
        -- Hookear canales que se creen después
        TCS.DescendantAdded:Connect(function(d)
            if d:IsA("TextChannel") then
                d.MessageReceived:Connect(function(msg)
                    if msg then CheckTextForSparkle(msg.Text or "") end
                end)
            end
        end)
    end)

    -- 2) Chat legacy (Roblox legacy chat system)
    pcall(function()
        local ChatSvc = game:GetService("Chat")
        if ChatSvc then
            ChatSvc.Chatted:Connect(function(part, msg)
                CheckTextForSparkle(tostring(msg))
            end)
        end
    end)

    -- 3) Escuchar todos los mensajes de Players
    for _, p in ipairs(Players:GetPlayers()) do
        p.Chatted:Connect(function(msg) CheckTextForSparkle(msg) end)
    end
    Players.PlayerAdded:Connect(function(p)
        p.Chatted:Connect(function(msg) CheckTextForSparkle(msg) end)
    end)

    -- 4) DescendantAdded en PlayerGui — captura mensajes de sistema
    --    que aparecen como TextLabel (el mensaje de Sparkle viene del server
    --    como un mensaje de sistema/hint, no de un jugador)
    pcall(function()
        local pg = LP:WaitForChild("PlayerGui", 8)
        pg.DescendantAdded:Connect(function(d)
            if d:IsA("TextLabel") or d:IsA("TextBox") then
                -- Chequear texto inmediato
                CheckTextForSparkle(d.Text)
                -- Y cambios futuros
                d:GetPropertyChangedSignal("Text"):Connect(function()
                    CheckTextForSparkle(d.Text)
                end)
            end
        end)
        -- Hookear los que ya existen
        for _, d in ipairs(pg:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("TextBox") then
                d:GetPropertyChangedSignal("Text"):Connect(function()
                    CheckTextForSparkle(d.Text)
                end)
            end
        end
    end)
end

-- 5) POLLING activo: escanea todo el PlayerGui cada 0.5s
--    Es el método más agresivo y fiable para mensajes de sistema
task.spawn(function()
    task.wait(3) -- esperar a que cargue el juego
    HookAllChatMethods()
    while true do
        task.wait(0.5)
        if not States.SparkleAlarmEnabled then continue end
        pcall(function()
            local pg = LP.PlayerGui
            for _, d in ipairs(pg:GetDescendants()) do
                if (d:IsA("TextLabel") or d:IsA("TextBox")) and d.Text and #d.Text > 10 then
                    CheckTextForSparkle(d.Text)
                end
            end
        end)
    end
end)

-- =========================================================
-- AUTO-HOP LOOP
-- Logica CORRECTA:
--   Si AutoServerHopEnabled = true Y SparkleAlarmEnabled = true:
--     → Hop cada 10s mientras NO haya sparkle en el servidor
--     → Si detecta sparkle: PARA el hop, suena alarma, espera
--       a que el usuario la silencia manualmente
-- =========================================================
task.spawn(function()
    while true do
        task.wait(10)

        if not States.AutoServerHopEnabled then continue end
        if not States.SparkleAlarmEnabled  then continue end

        if sparkleDetected then
            -- SPARKLE ENCONTRADO en este servidor:
            -- Mantener alarma sonando, NO hopear
            -- El usuario silencia manualmente con el boton
            if not alarmRunning then
                PlayAlarm()
            end
            -- No hacer nada mas — seguir en bucle esperando que silencien
        else
            -- Sin sparkle: hop al siguiente servidor a buscar
            if not hopCooldown then
                print("[MrCalvoHub] Auto-Hop: sin sparkle, cambiando servidor...")
                DoServerHop()
            end
        end
    end
end)

-- =========================================================
-- LÓGICA DE JUEGO
-- =========================================================
local BodyVelocity, BodyGyro

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
        VirtualInputManager:SendKeyEvent(true,  Enum.KeyCode.E, false, game)
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
                local h   = Vector3.new(dir.X, 0, dir.Z)
                if h.Magnitude > 0.1 then
                    h = h.Unit
                    root.CFrame = CFrame.new(root.Position, root.Position + h)
                    task.wait(0.05)
                    VirtualInputManager:SendKeyEvent(true,  Enum.KeyCode.W, false, game)
                    task.wait(States.NudgeStrength * 0.005)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, game)
                end
            end
        end
        task.wait(0.2)
    end
end

local function AutoSpamELoop()
    while States.AutoSpamEEnabled do SpamEKey() task.wait(0.07) end
end

local function AutoLeaveBattleLoop()
    while States.AutoLeaveBattleEnabled do
        local pg = LP:WaitForChild("PlayerGui")
        local battleActive = pg:FindFirstChild("Catch", true)
            or pg:FindFirstChild("Catch(2/2)", true)
            or pg:FindFirstChild("CatchButton", true)
            or pg:FindFirstChild("BattleGui", true)
        if battleActive then
            VirtualInputManager:SendKeyEvent(true,  Enum.KeyCode.C, false, game)
            task.wait(0.12)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.C, false, game)
        end
        task.wait(0.7)
    end
end

local function SimulateKey(key, dur)
    if not States.AutoFightWalk then return end
    VirtualInputManager:SendKeyEvent(true,  key, false, game)
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
    local hum  = GetHumanoid()
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
        if UserInputService:IsKeyDown(Enum.KeyCode.W)            then moveDir += Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S)            then moveDir -= Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A)            then moveDir -= Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D)            then moveDir += Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space)        then moveDir += Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)  then moveDir -= Vector3.new(0,1,0) end
        BodyVelocity.Velocity = (moveDir.Magnitude > 0 and moveDir.Unit or Vector3.new()) * States.FlySpeed
        BodyGyro.CFrame = Camera.CFrame
    else
        if BodyVelocity then BodyVelocity:Destroy() BodyVelocity = nil end
        if BodyGyro     then BodyGyro:Destroy()     BodyGyro     = nil end
        if States.SpeedEnabled then
            local md = hum.MoveDirection * States.SpeedValue
            root.Velocity = Vector3.new(md.X, root.Velocity.Y, md.Z)
        end
    end
end)

-- =========================================================
-- GUI HELPERS
-- =========================================================
local function ApplyCorner(parent, radius)
    local c = Instance.new("UICorner", parent)
    c.CornerRadius = UDim.new(0, radius or 12)
    return c
end

local function ApplyStroke(parent, color, thickness)
    local s = Instance.new("UIStroke", parent)
    s.Color     = color     or Theme.Border
    s.Thickness = thickness or 1
    return s
end

local function MakeLabel(parent, text, size, color, font, xAlign)
    local l = Instance.new("TextLabel", parent)
    l.Text            = text
    l.TextSize        = size   or 14
    l.TextColor3      = color  or Theme.Text
    l.Font            = font   or Enum.Font.Gotham
    l.BackgroundTransparency = 1
    l.TextXAlignment  = xAlign or Enum.TextXAlignment.Left
    l.TextYAlignment  = Enum.TextYAlignment.Center
    l.ZIndex          = 6
    return l
end

-- =========================================================
-- GUI ROOT
-- =========================================================
local ScreenGui = Instance.new("ScreenGui", game:GetService("CoreGui"))
ScreenGui.Name         = "MrCalvoHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local Main = Instance.new("Frame", ScreenGui)
Main.Size                = UDim2.new(0, 860, 0, 620)
Main.Position            = UDim2.new(0.5, -430, 0.5, -310)
Main.BackgroundColor3    = Theme.BG
Main.BorderSizePixel     = 0
Main.ClipsDescendants    = true
Main.BackgroundTransparency = 1
ApplyCorner(Main, 16)

-- Animaciones open/close
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
        isAnimating  = false
        if cb then cb() end
    end)
end

ShowMain()

-- Fondo de estrellas animadas
local StarContainer = Instance.new("Frame", Main)
StarContainer.Size               = UDim2.new(1, 0, 1, 0)
StarContainer.BackgroundTransparency = 1
StarContainer.ZIndex             = 1
StarContainer.ClipsDescendants   = true

local stars = {}
for i = 1, 22 do
    local sz = 2 + math.random(0, 3)
    local s  = Instance.new("Frame", StarContainer)
    s.BackgroundColor3    = Theme.PurpleLight
    s.Size                = UDim2.new(0, sz, 0, sz)
    s.BackgroundTransparency = 0.1
    s.BorderSizePixel     = 0
    s.ZIndex              = 1
    ApplyCorner(s, sz)
    local stroke          = Instance.new("UIStroke", s)
    stroke.Color          = Theme.Purple
    stroke.Thickness      = sz > 3 and 2 or 1
    stroke.Transparency   = 0.3
    stars[i] = {
        frame     = s,  stroke = stroke,
        speed     = 0.010 + math.random() * 0.018,
        yBase     = math.random() * 0.90,
        phase     = math.random() * math.pi * 2,
        glowT     = math.random() * math.pi * 2,
        glowSpeed = 0.4 + math.random() * 0.8,
    }
end

RunService.Heartbeat:Connect(function()
    if not Main.Visible then return end
    local t = tick()
    for _, d in ipairs(stars) do
        local x    = ((t * d.speed + d.phase) % 2.5) - 0.7
        local y    = d.yBase + math.sin(t * 0.7 + d.phase) * 0.055
        d.frame.Position = UDim2.new(x, 0, y, 0)
        local glow = math.sin(t * d.glowSpeed + d.glowT)
        d.frame.BackgroundTransparency = 0.05 + (glow * 0.5 + 0.5) * 0.55
        d.stroke.Transparency          = 0.1 + (1 - (glow * 0.5 + 0.5)) * 0.65
    end
end)

-- =========================================================
-- HEADER
-- =========================================================
local Header = Instance.new("Frame", Main)
Header.Size             = UDim2.new(1, 0, 0, 60)
Header.BackgroundColor3 = Theme.Header
Header.BorderSizePixel  = 0
Header.ZIndex           = 5

local HeaderLine = Instance.new("Frame", Header)
HeaderLine.Size             = UDim2.new(1, 0, 0, 1)
HeaderLine.Position         = UDim2.new(0, 0, 1, -1)
HeaderLine.BackgroundColor3 = Theme.Border
HeaderLine.BorderSizePixel  = 0
HeaderLine.ZIndex           = 5

local Title = Instance.new("TextLabel", Header)
Title.Text            = "MrCalvoHub"
Title.Font            = Enum.Font.GothamBlack
Title.TextSize        = 28
Title.TextColor3      = Theme.Text
Title.Size            = UDim2.new(0, 260, 1, 0)
Title.Position        = UDim2.new(0, 24, 0, 0)
Title.BackgroundTransparency = 1
Title.TextXAlignment  = Enum.TextXAlignment.Left
Title.ZIndex          = 6
local TitleGrad = Instance.new("UIGradient", Title)
TitleGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 255, 255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 160, 255)),
    ColorSequenceKeypoint.new(1,   Theme.Purple),
})

local function MakeHeaderBtn(text, offsetX)
    local btn = Instance.new("TextButton", Header)
    btn.Size             = UDim2.new(0, 34, 0, 34)
    btn.Position         = UDim2.new(1, offsetX, 0.5, 0)
    btn.AnchorPoint      = Vector2.new(0, 0.5)
    btn.BackgroundColor3 = Color3.fromRGB(30, 26, 46)
    btn.Text             = text
    btn.TextColor3       = Theme.TextMuted
    btn.Font             = Enum.Font.GothamBold
    btn.TextSize         = 16
    btn.BorderSizePixel  = 0
    btn.ZIndex           = 7
    btn.AutoButtonColor  = false
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

local MinimizedBtn = Instance.new("TextButton", ScreenGui)
MinimizedBtn.Text            = "MrCalvoHub"
MinimizedBtn.Font            = Enum.Font.GothamBold
MinimizedBtn.TextSize        = 13
MinimizedBtn.TextColor3      = Theme.Text
MinimizedBtn.Size            = UDim2.new(0, 118, 0, 32)
MinimizedBtn.Position        = UDim2.new(0.5, -59, 0, 14)
MinimizedBtn.BackgroundColor3 = Theme.Purple
MinimizedBtn.Visible         = false
MinimizedBtn.ZIndex          = 10
ApplyCorner(MinimizedBtn, 10)
local MinGrad = Instance.new("UIGradient", MinimizedBtn)
MinGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Theme.Purple),
    ColorSequenceKeypoint.new(1, Theme.PurpleLight),
})

MinimizeBtn.MouseButton1Click:Connect(function() HideMain(function() MinimizedBtn.Visible = true end) end)
MinimizedBtn.MouseButton1Click:Connect(function() MinimizedBtn.Visible = false ShowMain() end)
CloseBtn.MouseButton1Click:Connect(function() HideMain(function() ScreenGui:Destroy() end) end)

local dragData = {}
Header.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        dragData.active = true dragData.start = i.Position dragData.pos = Main.Position
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if dragData.active and i.UserInputType == Enum.UserInputType.MouseMovement then
        local d = i.Position - dragData.start
        Main.Position = UDim2.new(dragData.pos.X.Scale, dragData.pos.X.Offset + d.X,
                                   dragData.pos.Y.Scale, dragData.pos.Y.Offset + d.Y)
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then dragData.active = false end
end)

-- =========================================================
-- SIDEBAR
-- =========================================================
local Sidebar = Instance.new("Frame", Main)
Sidebar.Size             = UDim2.new(0, 170, 1, -62)
Sidebar.Position         = UDim2.new(0, 0, 0, 61)
Sidebar.BackgroundColor3 = Theme.Sidebar
Sidebar.BorderSizePixel  = 0
Sidebar.ZIndex           = 4

local SidebarLine = Instance.new("Frame", Sidebar)
SidebarLine.Size             = UDim2.new(0, 1, 1, 0)
SidebarLine.Position         = UDim2.new(1, -1, 0, 0)
SidebarLine.BackgroundColor3 = Theme.Border
SidebarLine.BorderSizePixel  = 0

local function CreateNavBtn(icon, label, yPos, active)
    local btn = Instance.new("TextButton", Sidebar)
    btn.Size                = UDim2.new(1, -24, 0, 42)
    btn.Position            = UDim2.new(0, 12, 0, yPos)
    btn.Text                = ""
    btn.AutoButtonColor     = false
    btn.BackgroundColor3    = Theme.Purple
    btn.BackgroundTransparency = active and 0 or 1
    btn.BorderSizePixel     = 0
    btn.ZIndex              = 6
    ApplyCorner(btn, 10)
    if active then
        local g = Instance.new("UIGradient", btn)
        g.Color    = ColorSequence.new({ColorSequenceKeypoint.new(0, Theme.Purple), ColorSequenceKeypoint.new(1, Theme.PurpleLight)})
        g.Rotation = 135
    end
    local iconL = Instance.new("TextLabel", btn)
    iconL.Text  = icon  iconL.TextSize = 17  iconL.Font = Enum.Font.GothamBold
    iconL.TextColor3 = active and Theme.Text or Theme.TextDim
    iconL.BackgroundTransparency = 1
    iconL.Size = UDim2.new(0, 30, 1, 0)  iconL.Position = UDim2.new(0, 10, 0, 0)
    iconL.TextXAlignment = Enum.TextXAlignment.Center  iconL.TextYAlignment = Enum.TextYAlignment.Center  iconL.ZIndex = 7
    local textL = Instance.new("TextLabel", btn)
    textL.Text = label  textL.TextSize = 14  textL.Font = Enum.Font.GothamSemibold
    textL.TextColor3 = active and Theme.Text or Theme.TextMuted
    textL.BackgroundTransparency = 1
    textL.Size = UDim2.new(1, -46, 1, 0)  textL.Position = UDim2.new(0, 42, 0, 0)
    textL.TextXAlignment = Enum.TextXAlignment.Left  textL.TextYAlignment = Enum.TextYAlignment.Center  textL.ZIndex = 7
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

-- =========================================================
-- CONTENT AREA
-- =========================================================
local ContentArea = Instance.new("Frame", Main)
ContentArea.Size             = UDim2.new(1, -182, 1, -68)
ContentArea.Position         = UDim2.new(0, 178, 0, 65)
ContentArea.BackgroundTransparency = 1
ContentArea.ZIndex           = 4
ContentArea.ClipsDescendants = true

local function MakeScroll(visible)
    local s = Instance.new("ScrollingFrame", ContentArea)
    s.Size                    = UDim2.new(1, 0, 1, 0)
    s.BackgroundTransparency  = 1
    s.ScrollBarThickness      = 4
    s.ScrollBarImageColor3    = Theme.Purple
    s.ScrollBarImageTransparency = 0.4
    s.Visible                 = visible
    s.AutomaticCanvasSize     = Enum.AutomaticSize.Y
    s.BorderSizePixel         = 0
    s.ZIndex                  = 5
    local layout = Instance.new("UIListLayout", s)
    layout.Padding   = UDim.new(0, 16)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    local pad = Instance.new("UIPadding", s)
    pad.PaddingLeft   = UDim.new(0, 4)
    pad.PaddingRight  = UDim.new(0, 14)
    pad.PaddingTop    = UDim.new(0, 6)
    pad.PaddingBottom = UDim.new(0, 16)
    return s
end

local ScrollMove = MakeScroll(true)
local ScrollEvo  = MakeScroll(false)
local ScrollUtil = MakeScroll(false)

local function SetActiveNav(tab)
    local function activate(btn, icon, text, on)
        local g = btn:FindFirstChildOfClass("UIGradient")
        if on then
            btn.BackgroundTransparency = 0
            btn.BackgroundColor3       = Theme.Purple
            if not g then
                g = Instance.new("UIGradient", btn)
                g.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Theme.Purple), ColorSequenceKeypoint.new(1, Theme.PurpleLight)})
                g.Rotation = 135
            end
            icon.TextColor3 = Theme.Text  text.TextColor3 = Theme.Text
        else
            btn.BackgroundTransparency = 1
            if g then g:Destroy() end
            icon.TextColor3 = Theme.TextDim  text.TextColor3 = Theme.TextMuted
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

-- =========================================================
-- CARD / TOGGLE / SLIDER helpers
-- =========================================================
local function MakeCard(parent, order)
    local card = Instance.new("Frame", parent)
    card.BackgroundColor3 = Theme.Card
    card.BorderSizePixel  = 0
    card.AutomaticSize    = Enum.AutomaticSize.Y
    card.Size             = UDim2.new(1, 0, 0, 0)
    card.LayoutOrder      = order or 0
    card.ZIndex           = 6
    ApplyCorner(card, 14)
    ApplyStroke(card, Theme.Border, 1)
    local layout = Instance.new("UIListLayout", card)
    layout.Padding   = UDim.new(0, 0)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    local pad = Instance.new("UIPadding", card)
    pad.PaddingLeft   = UDim.new(0, 18)
    pad.PaddingRight  = UDim.new(0, 18)
    pad.PaddingTop    = UDim.new(0, 14)
    pad.PaddingBottom = UDim.new(0, 14)
    return card
end

local function MakeCardTitle(card, text)
    local f = Instance.new("Frame", card)
    f.Size             = UDim2.new(1, 0, 0, 32)
    f.BackgroundTransparency = 1
    f.LayoutOrder      = 0
    f.ZIndex           = 7
    local lbl = MakeLabel(f, text, 11, Theme.Purple, Enum.Font.GothamBold)
    lbl.Size  = UDim2.new(1, 0, 1, 0)
    lbl.ZIndex = 7
    local line = Instance.new("Frame", f)
    line.Size             = UDim2.new(1, 0, 0, 1)
    line.Position         = UDim2.new(0, 0, 1, -1)
    line.BackgroundColor3 = Theme.Border
    line.BorderSizePixel  = 0
    line.ZIndex           = 7
end

local rowOrder = 0
local function NextOrder() rowOrder += 1 return rowOrder end

local function MakeToggle(parent, labelText, default, callback, order)
    local row = Instance.new("Frame", parent)
    row.Size             = UDim2.new(1, 0, 0, 44)
    row.BackgroundTransparency = 1
    row.LayoutOrder      = order or NextOrder()
    row.ZIndex           = 7

    local lbl = MakeLabel(row, labelText, 14, Theme.TextMuted)
    lbl.Size     = UDim2.new(1, -62, 1, 0)
    lbl.Position = UDim2.new(0, 0, 0, 0)
    lbl.ZIndex   = 8

    local track = Instance.new("Frame", row)
    track.Size             = UDim2.new(0, 44, 0, 24)
    track.Position         = UDim2.new(1, -44, 0.5, 0)
    track.AnchorPoint      = Vector2.new(0, 0.5)
    track.BackgroundColor3 = default and Theme.Purple or Theme.ToggleOff
    track.BorderSizePixel  = 0
    track.ZIndex           = 8
    ApplyCorner(track, 12)
    if default then
        local g = Instance.new("UIGradient", track)
        g.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Theme.Purple), ColorSequenceKeypoint.new(1, Theme.PurpleLight)})
    end

    local knob = Instance.new("Frame", track)
    knob.Size             = UDim2.new(0, 18, 0, 18)
    knob.Position         = default and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
    knob.AnchorPoint      = Vector2.new(0, 0.5)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel  = 0
    knob.ZIndex           = 9
    ApplyCorner(knob, 9)

    local state = default
    local function doToggle()
        state = not state
        callback(state)
        local grad = track:FindFirstChildOfClass("UIGradient")
        if state then
            if not grad then
                grad = Instance.new("UIGradient", track)
                grad.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Theme.Purple), ColorSequenceKeypoint.new(1, Theme.PurpleLight)})
            end
        else
            if grad then grad:Destroy() end
        end
        TweenService:Create(track, TweenInfo.new(0.18), {BackgroundColor3 = state and Theme.Purple or Theme.ToggleOff}):Play()
        TweenService:Create(knob,  TweenInfo.new(0.2, Enum.EasingStyle.Quint), {Position = state and UDim2.new(1,-21,0.5,0) or UDim2.new(0,3,0.5,0)}):Play()
    end

    local hitBtn = Instance.new("TextButton", row)
    hitBtn.Size             = UDim2.new(1, 0, 1, 0)
    hitBtn.BackgroundTransparency = 1
    hitBtn.Text             = ""
    hitBtn.ZIndex           = 10
    hitBtn.AutoButtonColor  = false
    hitBtn.MouseButton1Click:Connect(doToggle)
    return row
end

local function MakeSlider(parent, labelText, minV, maxV, default, callback, order)
    local f = Instance.new("Frame", parent)
    f.Size             = UDim2.new(1, 0, 0, 54)
    f.BackgroundTransparency = 1
    f.LayoutOrder      = order or NextOrder()
    f.ZIndex           = 7

    local hRow = Instance.new("Frame", f)
    hRow.Size             = UDim2.new(1, 0, 0, 22)
    hRow.BackgroundTransparency = 1
    hRow.ZIndex           = 8

    local lbl = MakeLabel(hRow, labelText, 13, Theme.TextMuted)
    lbl.Size  = UDim2.new(1, -50, 1, 0)
    lbl.ZIndex = 8

    local valLbl = MakeLabel(hRow, tostring(default), 13, Theme.PurpleLight, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
    valLbl.Size     = UDim2.new(0, 48, 1, 0)
    valLbl.Position = UDim2.new(1, -48, 0, 0)
    valLbl.ZIndex   = 8

    local barBG = Instance.new("Frame", f)
    barBG.Size             = UDim2.new(1, 0, 0, 6)
    barBG.Position         = UDim2.new(0, 0, 0, 34)
    barBG.BackgroundColor3 = Theme.SliderBG
    barBG.BorderSizePixel  = 0
    barBG.ZIndex           = 8
    ApplyCorner(barBG, 3)

    local fill = Instance.new("Frame", barBG)
    fill.BackgroundColor3 = Theme.Purple
    fill.Size             = UDim2.new((default - minV) / (maxV - minV), 0, 1, 0)
    fill.BorderSizePixel  = 0
    fill.ZIndex           = 9
    ApplyCorner(fill, 3)
    local fg = Instance.new("UIGradient", fill)
    fg.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Theme.Purple), ColorSequenceKeypoint.new(1, Theme.PurpleLight)})

    local knob = Instance.new("Frame", barBG)
    knob.Size             = UDim2.new(0, 14, 0, 14)
    knob.Position         = UDim2.new((default - minV) / (maxV - minV), -7, 0.5, 0)
    knob.AnchorPoint      = Vector2.new(0, 0.5)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel  = 0
    knob.ZIndex           = 10
    ApplyCorner(knob, 7)
    ApplyStroke(knob, Theme.Purple, 2)

    local dragging = false
    local function updateSlider(inputPos)
        local rel = math.clamp((inputPos.X - barBG.AbsolutePosition.X) / barBG.AbsoluteSize.X, 0, 1)
        local val = math.floor(minV + (maxV - minV) * rel + 0.5)
        fill.Size     = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, -7, 0.5, 0)
        valLbl.Text   = tostring(val)
        callback(val)
    end

    knob.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end end)
    barBG.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true updateSlider(i.Position) end end)
    UserInputService.InputEnded:Connect(function(i)   if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
    UserInputService.InputChanged:Connect(function(i) if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then updateSlider(i.Position) end end)
    return f
end

-- =========================================================
-- MOVEMENT TAB
-- =========================================================
local CardLoco = MakeCard(ScrollMove, 1)
MakeCardTitle(CardLoco, "LOCOMOTION")
MakeToggle(CardLoco, "Speed",   States.SpeedEnabled,   function(v) States.SpeedEnabled = v end)
MakeSlider(CardLoco, "Speed Value", 16, 300, 50,       function(v) States.SpeedValue   = v end)
MakeToggle(CardLoco, "Fly",     States.FlyEnabled,     function(v) States.FlyEnabled   = v end)
MakeSlider(CardLoco, "Fly Speed",   10, 300, 50,       function(v) States.FlySpeed     = v end)
MakeToggle(CardLoco, "Noclip", States.NoclipEnabled,   function(v) States.NoclipEnabled = v end)

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

-- =========================================================
-- EVOMON TAB
-- =========================================================
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
WrapInput.Size             = UDim2.new(1, 0, 0, 52)
WrapInput.BackgroundTransparency = 1
WrapInput.LayoutOrder      = NextOrder()

local WhitelistInput = Instance.new("TextBox", WrapInput)
WhitelistInput.Size             = UDim2.new(1, 0, 0, 40)
WhitelistInput.Position         = UDim2.new(0, 0, 0, 6)
WhitelistInput.BackgroundColor3 = Color3.fromRGB(14, 12, 24)
WhitelistInput.PlaceholderText  = "Pikachu, Dragonite, 025"
WhitelistInput.PlaceholderColor3 = Theme.TextDim
WhitelistInput.Text             = States.WhitelistString
WhitelistInput.Font             = Enum.Font.Gotham
WhitelistInput.TextSize         = 13
WhitelistInput.TextColor3       = Theme.Text
WhitelistInput.BorderSizePixel  = 0
WhitelistInput.ZIndex           = 8
WhitelistInput.ClearTextOnFocus = false
ApplyCorner(WhitelistInput, 10)
ApplyStroke(WhitelistInput, Theme.Border, 1)
local WPad = Instance.new("UIPadding", WhitelistInput)
WPad.PaddingLeft  = UDim.new(0, 12)
WPad.PaddingRight = UDim.new(0, 12)
WhitelistInput.FocusLost:Connect(function() States.WhitelistString = WhitelistInput.Text end)

local WrapScan = Instance.new("Frame", CardWhitelist)
WrapScan.Size             = UDim2.new(1, 0, 0, 52)
WrapScan.BackgroundTransparency = 1
WrapScan.LayoutOrder      = NextOrder()

local ScanBtn = Instance.new("TextButton", WrapScan)
ScanBtn.Size             = UDim2.new(1, 0, 0, 40)
ScanBtn.Position         = UDim2.new(0, 0, 0, 6)
ScanBtn.BackgroundColor3 = Theme.Purple
ScanBtn.Text             = "Scan Nearby Evomons (F9)"
ScanBtn.Font             = Enum.Font.GothamBold
ScanBtn.TextSize         = 14
ScanBtn.TextColor3       = Theme.Text
ScanBtn.BorderSizePixel  = 0
ScanBtn.ZIndex           = 8
ScanBtn.AutoButtonColor  = false
ApplyCorner(ScanBtn, 10)
local ScanGrad = Instance.new("UIGradient", ScanBtn)
ScanGrad.Color    = ColorSequence.new({ColorSequenceKeypoint.new(0, Theme.Purple), ColorSequenceKeypoint.new(1, Theme.PurpleLight)})
ScanGrad.Rotation = 90
ScanBtn.MouseEnter:Connect(function() TweenService:Create(ScanBtn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.PurpleLight}):Play() end)
ScanBtn.MouseLeave:Connect(function() TweenService:Create(ScanBtn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.Purple}):Play() end)
ScanBtn.MouseButton1Click:Connect(function()
    local r = GetRoot() if not r then return end
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
MakeToggle(CardTele, "Teleport to Pet",   States.TeleportEnabled,      function(v) States.TeleportEnabled      = v end)
MakeSlider(CardTele, "Teleport Offset",  2, 15,  5,                    function(v) States.TeleportOffset       = v end)

local CardNudge = MakeCard(ScrollEvo, 4)
MakeCardTitle(CardNudge, "VELOCITY NUDGE")
MakeToggle(CardNudge, "Velocity Nudge (Walk into Combat)", States.VelocityNudgeEnabled, function(v) States.VelocityNudgeEnabled = v end)
MakeSlider(CardNudge, "Nudge Strength", 10, 100, 55,                   function(v) States.NudgeStrength        = v end)

-- =========================================================
-- UTILITIES TAB
-- =========================================================

--- CARD 1: Sparkle Alarm ---
local CardSparkle = MakeCard(ScrollUtil, 1)
MakeCardTitle(CardSparkle, "✨ SPARKLE EVOMON ALARM")

-- Indicador de estado
local SparkleStatusRow = Instance.new("Frame", CardSparkle)
SparkleStatusRow.Size             = UDim2.new(1, 0, 0, 36)
SparkleStatusRow.BackgroundColor3 = Color3.fromRGB(14, 12, 24)
SparkleStatusRow.BorderSizePixel  = 0
SparkleStatusRow.LayoutOrder      = NextOrder()
ApplyCorner(SparkleStatusRow, 8)
local SpkPad = Instance.new("UIPadding", SparkleStatusRow)
SpkPad.PaddingLeft = UDim.new(0, 10) SpkPad.PaddingRight = UDim.new(0, 10)

local SparkleStatusDot = Instance.new("Frame", SparkleStatusRow)
SparkleStatusDot.Size             = UDim2.new(0, 9, 0, 9)
SparkleStatusDot.Position         = UDim2.new(0, 0, 0.5, 0)
SparkleStatusDot.AnchorPoint      = Vector2.new(0, 0.5)
SparkleStatusDot.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
SparkleStatusDot.BorderSizePixel  = 0
SparkleStatusDot.ZIndex           = 8
ApplyCorner(SparkleStatusDot, 5)

local SparkleStatusLbl = MakeLabel(SparkleStatusRow, "Detector inactivo", 12, Theme.TextDim)
SparkleStatusLbl.Size     = UDim2.new(1, -18, 1, 0)
SparkleStatusLbl.Position = UDim2.new(0, 16, 0, 0)
SparkleStatusLbl.ZIndex   = 8

-- Toggle principal
MakeToggle(CardSparkle, "Alarm de Sparkle Evomon", false, function(v)
    States.SparkleAlarmEnabled = v
    sparkleDetected = false
    lastSparkleMsg  = ""
    seenMessages    = {}
    if not v then
        StopAlarm()
        sparkleDetected = false
        SparkleStatusDot.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
        SparkleStatusLbl.Text       = "Detector inactivo"
        SparkleStatusLbl.TextColor3 = Theme.TextDim
    else
        sparkleDetected = false
        seenMessages    = {}
        SparkleStatusDot.BackgroundColor3 = Color3.fromRGB(80, 200, 120)
        SparkleStatusLbl.Text       = "Escuchando chat del server..."
        SparkleStatusLbl.TextColor3 = Theme.TextMuted
    end
end)

-- Botón test
local WrapTest = Instance.new("Frame", CardSparkle)
WrapTest.Size             = UDim2.new(1, 0, 0, 48)
WrapTest.BackgroundTransparency = 1
WrapTest.LayoutOrder      = NextOrder()
local TestBtn = Instance.new("TextButton", WrapTest)
TestBtn.Size             = UDim2.new(1, 0, 0, 36)
TestBtn.Position         = UDim2.new(0, 0, 0, 6)
TestBtn.BackgroundColor3 = Color3.fromRGB(40, 30, 65)
TestBtn.Text             = "🔔  Probar Sonido de Alarma"
TestBtn.Font             = Enum.Font.GothamSemibold
TestBtn.TextSize         = 13
TestBtn.TextColor3       = Theme.TextMuted
TestBtn.BorderSizePixel  = 0
TestBtn.ZIndex           = 8
TestBtn.AutoButtonColor  = false
ApplyCorner(TestBtn, 10)
ApplyStroke(TestBtn, Theme.Border, 1)
TestBtn.MouseEnter:Connect(function() TweenService:Create(TestBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(60,44,90), TextColor3 = Theme.Text}):Play() end)
TestBtn.MouseLeave:Connect(function() TweenService:Create(TestBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(40,30,65), TextColor3 = Theme.TextMuted}):Play() end)
TestBtn.MouseButton1Click:Connect(function()
    StopAlarm()  -- reset limpio
    task.wait(0.1)
    PlayAlarm()
end)

-- Botón silenciar
local WrapStop = Instance.new("Frame", CardSparkle)
WrapStop.Size             = UDim2.new(1, 0, 0, 48)
WrapStop.BackgroundTransparency = 1
WrapStop.LayoutOrder      = NextOrder()
local StopBtn = Instance.new("TextButton", WrapStop)
StopBtn.Size             = UDim2.new(1, 0, 0, 36)
StopBtn.Position         = UDim2.new(0, 0, 0, 6)
StopBtn.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
StopBtn.Text             = "🔇  Silenciar Alarma"
StopBtn.Font             = Enum.Font.GothamSemibold
StopBtn.TextSize         = 13
StopBtn.TextColor3       = Color3.fromRGB(220, 120, 120)
StopBtn.BorderSizePixel  = 0
StopBtn.ZIndex           = 8
StopBtn.AutoButtonColor  = false
ApplyCorner(StopBtn, 10)
StopBtn.MouseEnter:Connect(function() TweenService:Create(StopBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(90,30,30)}):Play() end)
StopBtn.MouseLeave:Connect(function() TweenService:Create(StopBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(60,20,20)}):Play() end)
StopBtn.MouseButton1Click:Connect(function()
    StopAlarm()
    sparkleDetected = false
    lastSparkleMsg  = ""
    if States.SparkleAlarmEnabled then
        SparkleStatusDot.BackgroundColor3 = Color3.fromRGB(80, 200, 120)
        SparkleStatusLbl.Text       = "Escuchando chat..."
        SparkleStatusLbl.TextColor3 = Theme.TextMuted
    end
end)

-- Actualizar indicador en tiempo real
RunService.Heartbeat:Connect(function()
    if not States.SparkleAlarmEnabled then return end
    if sparkleDetected then
        local pulse = math.abs(math.sin(tick() * 5))
        SparkleStatusDot.BackgroundColor3 = Color3.fromRGB(255, math.floor(40 + pulse*60), math.floor(40 + pulse*40))
        SparkleStatusLbl.Text       = "⚠ SPARKLE: " .. lastSparkleMsg:sub(1, 38)
        SparkleStatusLbl.TextColor3 = Color3.fromRGB(255, 210, 60)
    end
end)

--- CARD 2: Server Hop ---
local CardServerHop = MakeCard(ScrollUtil, 2)
MakeCardTitle(CardServerHop, "🌐 SERVER HOP — SERVIDOR PRIVADO")

-- Info box
local SrvInfoBox = Instance.new("Frame", CardServerHop)
SrvInfoBox.Size             = UDim2.new(1, 0, 0, 44)
SrvInfoBox.BackgroundColor3 = Color3.fromRGB(14, 12, 24)
SrvInfoBox.BorderSizePixel  = 0
SrvInfoBox.LayoutOrder      = NextOrder()
ApplyCorner(SrvInfoBox, 8)
ApplyStroke(SrvInfoBox, Theme.Border, 1)
local SrvBoxPad = Instance.new("UIPadding", SrvInfoBox)
SrvBoxPad.PaddingLeft = UDim.new(0, 10) SrvBoxPad.PaddingTop = UDim.new(0, 4)
local SrvBoxLayout = Instance.new("UIListLayout", SrvInfoBox)
SrvBoxLayout.Padding = UDim.new(0, 2)
local SrvL1 = MakeLabel(SrvInfoBox, "Servidor: MrCalvoConPelo (Privado)", 12, Theme.TextMuted)
SrvL1.Size = UDim2.new(1, 0, 0, 16) SrvL1.ZIndex = 8
local SrvL2 = MakeLabel(SrvInfoBox, "Access Code: 8148aea3...75303b", 11, Theme.TextDim)
SrvL2.Size = UDim2.new(1, 0, 0, 14) SrvL2.ZIndex = 8

-- Label de estado del hop
local HopStatusWrap = Instance.new("Frame", CardServerHop)
HopStatusWrap.Size             = UDim2.new(1, 0, 0, 22)
HopStatusWrap.BackgroundTransparency = 1
HopStatusWrap.LayoutOrder      = NextOrder()
local HopStatusLbl = MakeLabel(HopStatusWrap, "", 11, Theme.TextDim, Enum.Font.Gotham, Enum.TextXAlignment.Center)
HopStatusLbl.Size = UDim2.new(1, 0, 1, 0) HopStatusLbl.ZIndex = 8

-- Botón principal HOP
local WrapHop = Instance.new("Frame", CardServerHop)
WrapHop.Size             = UDim2.new(1, 0, 0, 52)
WrapHop.BackgroundTransparency = 1
WrapHop.LayoutOrder      = NextOrder()

local HopBtn = Instance.new("TextButton", WrapHop)
HopBtn.Size             = UDim2.new(1, 0, 0, 42)
HopBtn.Position         = UDim2.new(0, 0, 0, 6)
HopBtn.BackgroundColor3 = Theme.Purple
HopBtn.Text             = "🚀  Ir al Servidor Privado AHORA"
HopBtn.Font             = Enum.Font.GothamBold
HopBtn.TextSize         = 14
HopBtn.TextColor3       = Theme.Text
HopBtn.BorderSizePixel  = 0
HopBtn.ZIndex           = 8
HopBtn.AutoButtonColor  = false
ApplyCorner(HopBtn, 10)
local HopGrad = Instance.new("UIGradient", HopBtn)
HopGrad.Color    = ColorSequence.new({ColorSequenceKeypoint.new(0, Theme.Purple), ColorSequenceKeypoint.new(1, Theme.PurpleLight)})
HopGrad.Rotation = 90
HopBtn.MouseEnter:Connect(function() TweenService:Create(HopBtn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.PurpleLight}):Play() end)
HopBtn.MouseLeave:Connect(function() TweenService:Create(HopBtn, TweenInfo.new(0.15), {BackgroundColor3 = Theme.Purple}):Play() end)

HopBtn.MouseButton1Click:Connect(function()
    if hopCooldown then
        HopStatusLbl.Text = "⏳ Cooldown activo — espera unos segundos"
        return
    end
    HopBtn.Text     = "⏳  Conectando al servidor..."
    HopStatusLbl.Text = "Ejecutando TeleportToReservedServer..."
    local ok = DoServerHop()
    task.delay(3, function()
        if HopBtn and HopBtn.Parent then
            HopBtn.Text = "🚀  Ir al Servidor Privado AHORA"
        end
        HopStatusLbl.Text = ok and "✔ Teleport enviado" or "✘ Error — revisa Output"
        task.delay(5, function()
            if HopStatusLbl and HopStatusLbl.Parent then
                HopStatusLbl.Text = ""
            end
        end)
    end)
end)

-- Toggle Auto-Hop
MakeToggle(CardServerHop, "Auto-Hop cada 10s buscando Sparkle", false, function(v)
    States.AutoServerHopEnabled = v
    if v then
        sparkleDetected = false
        HopStatusLbl.Text = "Hopeando cada 10s — se para si hay Sparkle"
        HopStatusLbl.TextColor3 = Color3.fromRGB(80, 200, 120)
    else
        HopStatusLbl.Text = ""
    end
end)

-- Nota
local NoteRow = Instance.new("Frame", CardServerHop)
NoteRow.Size             = UDim2.new(1, 0, 0, 26)
NoteRow.BackgroundTransparency = 1
NoteRow.LayoutOrder      = NextOrder()
local NoteLbl = MakeLabel(NoteRow, "Hop cada 10s → para automaticamente al detectar Sparkle", 10, Theme.TextDim)
NoteLbl.Size  = UDim2.new(1, 0, 1, 0)
NoteLbl.ZIndex = 8

-- Cooldown timer visual (se actualiza cada segundo mientras hay cooldown)
task.spawn(function()
    while true do
        task.wait(1)
        if hopCooldown and HopStatusLbl and HopStatusLbl.Parent then
            -- no sobreescribir si ya hay mensaje
        end
    end
end)

-- =========================================================
-- F9 SHORTCUT
-- =========================================================
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.F9 then
        ScanBtn:FireButton1Click()
    end
end)

print("[MrCalvoHub v5.1] ✓ Cargado — ServerHop + Sparkle Alarm + AutoHop funcionando.")
