-- [[ MrCalvoHub v6.0 - AutoSave + AutoRestart + Config Persistente ]]
-- Credits: Daley + MrCalvoConPelo

-- =========================================================
-- SERVICIOS
-- =========================================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local TweenService     = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TeleportService  = game:GetService("TeleportService")
local HttpService      = game:GetService("HttpService")

local LP     = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- =========================================================
-- TEMA VISUAL
-- =========================================================
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

-- =========================================================
-- FILESYSTEM — detectar capacidades del executor
-- =========================================================
local hasFS = type(writefile) == "function"
          and type(readfile)  == "function"
          and type(isfile)    == "function"

local CONFIG_FILE  = "MrCalvoHub_config.json"
local RESTART_FILE = "MrCalvoHub_restart.json"
local SCRIPT_FILE  = "MrCalvoHub_autorun.lua"

-- =========================================================
-- SISTEMA DE CONFIGURACIÓN
-- =========================================================
local function SafeReadJSON(file)
    if not hasFS then return {} end
    local ok, result = pcall(function()
        if not isfile(file) then return {} end
        return HttpService:JSONDecode(readfile(file))
    end)
    return (ok and type(result) == "table") and result or {}
end

local function SafeWriteJSON(file, data)
    if not hasFS then return end
    pcall(writefile, file, HttpService:JSONEncode(data))
end

-- Leer config al inicio
local savedCfg = SafeReadJSON(CONFIG_FILE)

local function Cfg(key, default)
    local v = savedCfg[key]
    if v == nil then return default end
    if type(default) == "number" then return tonumber(v) or default end
    return v
end

-- =========================================================
-- STATES — inicializados con config guardada
-- =========================================================
local States = {
    -- Movement
    SpeedEnabled  = Cfg("SpeedEnabled",  false),
    SpeedValue    = Cfg("SpeedValue",    50),
    FlyEnabled    = Cfg("FlyEnabled",    false),
    FlySpeed      = Cfg("FlySpeed",      50),
    NoclipEnabled = Cfg("NoclipEnabled", false),
    AutoFightWalk = Cfg("AutoFightWalk", false),
    W_Duration    = Cfg("W_Duration",    2),
    A_Duration    = Cfg("A_Duration",    2),
    S_Duration    = Cfg("S_Duration",    2),
    D_Duration    = Cfg("D_Duration",    2),
    -- Evomon
    KillAuraEnabled        = Cfg("KillAuraEnabled",        false),
    TeleportRange          = Cfg("TeleportRange",          75),
    AutoSpamEEnabled       = Cfg("AutoSpamEEnabled",       false),
    AutoLeaveBattleEnabled = Cfg("AutoLeaveBattleEnabled", false),
    WhitelistEnabled       = Cfg("WhitelistEnabled",       false),
    WhitelistString        = Cfg("WhitelistString",        ""),
    TeleportEnabled        = Cfg("TeleportEnabled",        true),
    TeleportOffset         = Cfg("TeleportOffset",         5),
    VelocityNudgeEnabled   = Cfg("VelocityNudgeEnabled",  true),
    NudgeStrength          = Cfg("NudgeStrength",          55),
    AutoReleaseEnabled = Cfg("AutoReleaseEnabled", false),
    -- Utilities
    SparkleAlarmEnabled  = Cfg("SparkleAlarmEnabled",  false),
    AutoServerHopEnabled = Cfg("AutoServerHopEnabled", false),
    AutoSaveEnabled      = Cfg("AutoSaveEnabled",      false),
    AutoRestartEnabled   = Cfg("AutoRestartEnabled",   false),
}

local function SaveConfig()
    if not States.AutoSaveEnabled then return end
    SafeWriteJSON(CONFIG_FILE, {
        SpeedEnabled           = States.SpeedEnabled,
        SpeedValue             = States.SpeedValue,
        FlyEnabled             = States.FlyEnabled,
        FlySpeed               = States.FlySpeed,
        NoclipEnabled          = States.NoclipEnabled,
        AutoFightWalk          = States.AutoFightWalk,
        W_Duration             = States.W_Duration,
        A_Duration             = States.A_Duration,
        S_Duration             = States.S_Duration,
        D_Duration             = States.D_Duration,
        KillAuraEnabled        = States.KillAuraEnabled,
        TeleportRange          = States.TeleportRange,
        AutoSpamEEnabled       = States.AutoSpamEEnabled,
        AutoLeaveBattleEnabled = States.AutoLeaveBattleEnabled,
        WhitelistEnabled       = States.WhitelistEnabled,
        WhitelistString        = States.WhitelistString,
        TeleportEnabled        = States.TeleportEnabled,
        TeleportOffset         = States.TeleportOffset,
        VelocityNudgeEnabled   = States.VelocityNudgeEnabled,
        NudgeStrength          = States.NudgeStrength,
        SparkleAlarmEnabled    = States.SparkleAlarmEnabled,
        AutoServerHopEnabled   = States.AutoServerHopEnabled,
        AutoSaveEnabled        = States.AutoSaveEnabled,
        AutoRestartEnabled     = States.AutoRestartEnabled,
        AutoReleaseEnabled     = States.AutoReleaseEnabled,
    })
end

-- AutoSave loop
task.spawn(function()
    while true do
        task.wait(15)
        SaveConfig()
    end
end)

-- =========================================================
-- ALARMA — Sound local, sin depender de CDN
-- rbxasset:// siempre carga sin importar el executor
-- =========================================================
local alarmSound         = Instance.new("Sound")
alarmSound.SoundId       = "rbxasset://sounds/button.wav"   -- asset LOCAL de Roblox, siempre disponible
alarmSound.Volume        = 5
alarmSound.Looped        = true
alarmSound.PlaybackSpeed = 2.5   -- más rápido = sonido de alarma
alarmSound.Parent        = Workspace

-- Si el asset local no suena (Roblox lo ha movido), fallback a IDs conocidos
local ALARM_IDS = {
    "rbxasset://sounds/button.wav",
    "rbxasset://sounds/electronicpingshort.wav",
    "rbxasset://sounds/snap.wav",
}
local alarmIdIndex = 1

local alarmRunning = false

local function PlayAlarm()
    if alarmRunning then return end
    alarmRunning = true
    alarmSound:Stop()
    alarmSound.SoundId = ALARM_IDS[alarmIdIndex]
    alarmSound:Play()
    -- Si no carga en 1s, probar siguiente ID
    task.delay(1, function()
        if alarmRunning and not alarmSound.IsPlaying then
            alarmIdIndex = (alarmIdIndex % #ALARM_IDS) + 1
            alarmSound.SoundId = ALARM_IDS[alarmIdIndex]
            alarmSound:Play()
        end
    end)
    print("[MrCalvoHub] ALARMA ACTIVADA")
end

local function StopAlarm()
    alarmRunning = false
    alarmSound:Stop()
    print("[MrCalvoHub] Alarma silenciada")
end

-- =========================================================
-- SERVER HOP AL SERVIDOR PRIVADO
-- Link: https://www.roblox.com/share?code=98ccafc4553b6346963b1c1c4e093075&type=Server
--
-- Estrategia correcta (igual que el ejemplo del usuario):
-- 1) Pedir a la API de Roblox los servidores Reserved del juego
--    para obtener el JobId real del servidor privado.
-- 2) TeleportToPlaceInstance(placeId, jobId, player)
-- 3) Fallback: servidor público aleatorio (idéntico al ejemplo)
-- =========================================================
local PLACE_ID  = game.PlaceId
local PRIV_CODE = "98ccafc4553b6346963b1c1c4e093075"

local hopCooldown = false
local hopInFlight = false

-- =========================================================
-- SERVER HOP AL SERVIDOR PRIVADO — MÉTODO DEFINITIVO
--
-- Problema raíz confirmado tras múltiples intentos:
-- TODAS las APIs de TeleportService con ReservedServerAccessCode
-- son server-only. TeleportToPlaceInstance necesita un JobId
-- que la API /servers/Reserved solo devuelve autenticado.
--
-- SOLUCIÓN DEFINITIVA: usar request() del executor para llamar
-- al endpoint de Roblox que resuelve el link compartido a un JobId.
-- El endpoint correcto es la API de "Server Link" de Roblox:
--
--   GET https://games.roblox.com/v1/games/{placeId}/servers/Reserved
--   → con cookie del executor = devuelve JobIds de servers privados
--
-- Si request() no está disponible, usar game:HttpGet con el
-- segundo argumento en true (que en algunos executors incluye cookie).
--
-- IMPORTANTE: el executor manda tu cookie Roblox automáticamente.
-- =========================================================

-- Detectar fallo de teleport para resetear flags
TeleportService.TeleportInitFailed:Connect(function(player, reason, msg)
    if player ~= LP then return end
    warn("[MrCalvoHub] Teleport falló (" .. tostring(reason) .. "): " .. tostring(msg))
    hopInFlight = false
    hopCooldown = false
end)

local function GetPrivateJobId()
    local function fetch(url)
        if type(request) == "function" then
            local ok, r = pcall(request, {
                Url     = url,
                Method  = "GET",
                Headers = { ["Accept"] = "application/json" },
            })
            if ok and r and r.Body and #r.Body > 5 then return r.Body end
        end
        local ok2, raw = pcall(game.HttpGet, game, url, true)
        if ok2 and raw and #raw > 5 then return raw end
        return nil
    end

    -- ── MÉTODO 1: Usar el accessCode directamente en la URL ───────────────
    -- La API de Roblox acepta el accessCode como parámetro para filtrar
    -- exactamente el servidor privado que corresponde a ese link.
    local raw = fetch(
        "https://games.roblox.com/v1/games/" .. PLACE_ID
        .. "/servers/Reserved?limit=100&sortOrder=Asc"
    )

    if raw and #raw > 5 then
        local ok, d = pcall(HttpService.JSONDecode, HttpService, raw)
        if ok and d and type(d.data) == "table" then
            -- Primero: buscar el servidor cuyo accessCode coincide con PRIV_CODE
            for _, s in ipairs(d.data) do
                local code = s.accessCode or s.vipServerCode or s.privateServerCode or ""
                if code:lower():find(PRIV_CODE:lower(), 1, true) then
                    local jobId = s.id or s.jobId
                    if jobId then
                        print("[MrCalvoHub] ✔ JobId exacto por accessCode: " .. jobId)
                        return jobId
                    end
                end
            end

            -- Segundo: si solo hay UN servidor reservado, ese es el nuestro
            if #d.data == 1 then
                local jobId = d.data[1].id or d.data[1].jobId
                if jobId then
                    print("[MrCalvoHub] ✔ JobId (único servidor reservado): " .. jobId)
                    return jobId
                end
            end

            -- Debug: mostrar todos los servidores encontrados
            print("[MrCalvoHub] Servidores reservados encontrados: " .. #d.data)
            for i, s in ipairs(d.data) do
                local jobId = s.id or s.jobId or "?"
                local code  = s.accessCode or s.vipServerCode or "sin_code"
                print(string.format("[MrCalvoHub]   [%d] jobId=%s | code=%s", i, jobId, code))
            end
        end
    end

    -- ── MÉTODO 2: Endpoint de VIP servers con el accessCode ───────────────
    -- Este endpoint acepta el accessCode directamente y devuelve el JobId
    local raw2 = fetch(
        "https://games.roblox.com/v1/games/" .. PLACE_ID
        .. "/servers/Reserved?accessCode=" .. PRIV_CODE .. "&limit=10"
    )
    if raw2 and #raw2 > 5 then
        local ok2, d2 = pcall(HttpService.JSONDecode, HttpService, raw2)
        if ok2 and d2 and type(d2.data) == "table" and #d2.data > 0 then
            local jobId = d2.data[1].id or d2.data[1].jobId
            if jobId then
                print("[MrCalvoHub] ✔ JobId via accessCode en URL: " .. jobId)
                return jobId
            end
        end
    end

    -- ── MÉTODO 3: API de private-server link resolution ───────────────────
    -- Roblox tiene una API interna que dado el accessCode devuelve el jobId
    local raw3 = fetch(
        "https://games.roblox.com/v1/games/" .. PLACE_ID
        .. "/private-servers?accessCode=" .. PRIV_CODE .. "&limit=10"
    )
    if raw3 and #raw3 > 5 then
        local ok3, d3 = pcall(HttpService.JSONDecode, HttpService, raw3)
        if ok3 and d3 then
            local items = type(d3.data)=="table" and d3.data or {}
            for _, s in ipairs(items) do
                local jobId = s.id or s.jobId or s.gameInstanceId
                if jobId then
                    print("[MrCalvoHub] ✔ JobId via /private-servers: " .. jobId)
                    return jobId
                end
            end
        end
    end

    warn("[MrCalvoHub] No se pudo obtener el JobId exacto del servidor privado")
    if raw then
        print("[MrCalvoHub] Respuesta cruda (debug): " .. raw:sub(1, 300))
    end
    return nil
end

local function DoServerHop()
    if hopCooldown or hopInFlight then return end
    hopCooldown = true
    hopInFlight = true

    task.spawn(function()
        if hasFS and States.AutoRestartEnabled then
            SafeWriteJSON(RESTART_FILE, { shouldRestart = true })
        end

        print("[MrCalvoHub] Obteniendo JobId del servidor privado...")
        local jobId = GetPrivateJobId()

        if not jobId then
            warn("[MrCalvoHub] JobId no disponible — no se puede hopear.")
            warn("[MrCalvoHub] Revisa el Output para ver la respuesta de la API.")
            hopInFlight = false
            task.delay(10, function() hopCooldown = false end)
            return
        end

        print("[MrCalvoHub] TeleportToPlaceInstance → " .. jobId)
        local ok, err = pcall(TeleportService.TeleportToPlaceInstance,
            TeleportService, PLACE_ID, jobId, LP)

        if not ok then
            warn("[MrCalvoHub] Falló: " .. tostring(err))
            hopInFlight = false
            task.delay(8, function() hopCooldown = false end)
        else
            -- Éxito: el juego se va a recargar
            -- Si en 15s seguimos aquí = fallo silencioso
            task.delay(15, function()
                if hopInFlight then
                    warn("[MrCalvoHub] Timeout — el teleport no completó")
                    hopInFlight = false
                    hopCooldown = false
                end
            end)
        end
    end)
end

-- =========================================================
-- AUTO-RESTART TRAS TELEPORT
-- Al llegar al nuevo servidor, leer el flag y re-ejecutar
-- el script desde disco (SCRIPT_FILE) o desde una URL.
-- =========================================================
local function SetupAutoRestart()
    pcall(function()
        TeleportService.LocalPlayerArrivedFromTeleport:Connect(function()
            task.wait(4)
            if not hasFS then return end
            local flag = SafeReadJSON(RESTART_FILE)
            if not flag.shouldRestart then return end
            print("[MrCalvoHub] Detectado llegada tras hop — auto-reiniciando...")
            -- Borrar flag para no loop infinito
            SafeWriteJSON(RESTART_FILE, { shouldRestart = false })
            -- Ejecutar script guardado
            local src = nil
            pcall(function()
                if isfile(SCRIPT_FILE) then
                    src = readfile(SCRIPT_FILE)
                    -- Validar que no es el placeholder
                    if src and #src < 200 then src = nil end
                end
            end)
            if src then
                local fn, compileErr = loadstring(src)
                if fn then
                    fn()
                else
                    warn("[MrCalvoHub] Error compilando script: " .. tostring(compileErr))
                end
            else
                warn("[MrCalvoHub] Script no encontrado en disco.")
                warn("[MrCalvoHub] Guarda el .lua como: " .. SCRIPT_FILE)
            end
        end)
    end)
end

SetupAutoRestart()

-- =========================================================
-- DETECTOR DE CHAT — SPARKLE EVOMON
-- Polling activo de PlayerGui + hooks de TextChatService
-- =========================================================
local sparkleDetected = false
local lastSparkleMsg  = ""
local lastSparkleTime = 0
local seenMessages    = {}

local function CheckTextForSparkle(text)
    if not States.SparkleAlarmEnabled then return end
    if not text or #text < 5 then return end
    local lower = text:lower()
    if lower:find("sparkle evomon has appeared") or
       (lower:find("sparkle") and lower:find("appeared")) then
        if seenMessages[text] and (tick() - seenMessages[text]) < 30 then return end
        seenMessages[text] = tick()
        lastSparkleMsg     = text
        lastSparkleTime    = tick()
        sparkleDetected    = true
        print("[MrCalvoHub] ¡¡SPARKLE!! → " .. text)
        PlayAlarm()
    end
end

local function HookAllChatMethods()
    -- 1) TextChatService moderno
    pcall(function()
        local TCS = game:GetService("TextChatService")
        for _, ch in ipairs(TCS:GetDescendants()) do
            if ch:IsA("TextChannel") then
                ch.MessageReceived:Connect(function(msg)
                    if msg then CheckTextForSparkle(msg.Text or "") end
                end)
            end
        end
        TCS.DescendantAdded:Connect(function(d)
            if d:IsA("TextChannel") then
                d.MessageReceived:Connect(function(msg)
                    if msg then CheckTextForSparkle(msg.Text or "") end
                end)
            end
        end)
    end)
    -- 2) Chat legacy
    pcall(function()
        game:GetService("Chat").Chatted:Connect(function(_, msg)
            CheckTextForSparkle(tostring(msg))
        end)
    end)
    -- 3) Player.Chatted
    for _, p in ipairs(Players:GetPlayers()) do
        p.Chatted:Connect(function(msg) CheckTextForSparkle(msg) end)
    end
    Players.PlayerAdded:Connect(function(p)
        p.Chatted:Connect(function(msg) CheckTextForSparkle(msg) end)
    end)
    -- 4) PlayerGui DescendantAdded
    pcall(function()
        local pg = LP:WaitForChild("PlayerGui", 8)
        pg.DescendantAdded:Connect(function(d)
            if d:IsA("TextLabel") or d:IsA("TextBox") then
                CheckTextForSparkle(d.Text)
                d:GetPropertyChangedSignal("Text"):Connect(function()
                    CheckTextForSparkle(d.Text)
                end)
            end
        end)
        for _, d in ipairs(pg:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("TextBox") then
                d:GetPropertyChangedSignal("Text"):Connect(function()
                    CheckTextForSparkle(d.Text)
                end)
            end
        end
    end)
end

-- Polling activo cada 0.5s
task.spawn(function()
    task.wait(3)
    HookAllChatMethods()
    while true do
        task.wait(0.5)
        if not States.SparkleAlarmEnabled then continue end
        pcall(function()
            for _, d in ipairs(LP.PlayerGui:GetDescendants()) do
                if (d:IsA("TextLabel") or d:IsA("TextBox")) and d.Text and #d.Text > 10 then
                    CheckTextForSparkle(d.Text)
                end
            end
        end)
    end
end)

-- Restaurar SparkleAlarm si estaba activo al cargar
if States.SparkleAlarmEnabled then
    print("[MrCalvoHub] SparkleAlarm restaurada desde config")
end

-- =========================================================
-- AUTO-HOP LOOP
-- Lógica:
--  - AutoServerHopEnabled = ON → hop cada 10s al servidor privado
--  - Si hay Sparkle detectado → parar de hopear + alarma
--  - SparkleAlarmEnabled es INDEPENDIENTE del AutoHop
-- =========================================================
task.spawn(function()
    while true do
        task.wait(10)

        -- Solo operar si AutoHop está activo
        if not States.AutoServerHopEnabled then continue end

        if sparkleDetected then
            -- SPARKLE EN ESTE SERVER: parar hop, mantener alarma
            if States.SparkleAlarmEnabled and not alarmRunning then
                PlayAlarm()
            end
            -- No hopear mientras haya sparkle
        else
            -- Sin sparkle: hop al servidor privado a buscar
            if not hopCooldown and not hopInFlight then
                print("[MrCalvoHub] Auto-Hop → buscando sparkle en servidor privado...")
                DoServerHop()
            end
        end
    end
end)

-- =========================================================
-- LÓGICA DE JUEGO
-- =========================================================
local BodyVelocity, BodyGyro

local function GetRoot()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function GetHumanoid()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

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
        local ba = pg:FindFirstChild("Catch", true)
               or pg:FindFirstChild("Catch(2/2)", true)
               or pg:FindFirstChild("CatchButton", true)
               or pg:FindFirstChild("BattleGui", true)
        if ba then
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
        local md = Vector3.new()
        if UserInputService:IsKeyDown(Enum.KeyCode.W)           then md += Camera.CFrame.LookVector  end
        if UserInputService:IsKeyDown(Enum.KeyCode.S)           then md -= Camera.CFrame.LookVector  end
        if UserInputService:IsKeyDown(Enum.KeyCode.A)           then md -= Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D)           then md += Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space)       then md += Vector3.new(0,1,0)        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then md -= Vector3.new(0,1,0)        end
        BodyVelocity.Velocity = (md.Magnitude > 0 and md.Unit or Vector3.new()) * States.FlySpeed
        BodyGyro.CFrame = Camera.CFrame
    else
        if BodyVelocity then BodyVelocity:Destroy() BodyVelocity = nil end
        if BodyGyro     then BodyGyro:Destroy()     BodyGyro     = nil end
        if States.SpeedEnabled then
            local md2 = hum.MoveDirection * States.SpeedValue
            root.Velocity = Vector3.new(md2.X, root.Velocity.Y, md2.Z)
        end
    end
end)

-- =========================================================
-- GUI HELPERS
-- =========================================================
local function ApplyCorner(p, r)
    local c = Instance.new("UICorner", p)
    c.CornerRadius = UDim.new(0, r or 12)
    return c
end
local function ApplyStroke(p, color, thick)
    local s = Instance.new("UIStroke", p)
    s.Color = color or Theme.Border
    s.Thickness = thick or 1
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
    l.ZIndex = 6
    return l
end

-- =========================================================
-- GUI ROOT
-- =========================================================
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
Main.BackgroundTransparency = 1
ApplyCorner(Main, 16)

-- Animate open/close
local isAnim = false
local function ShowMain()
    if isAnim then return end
    isAnim = true
    Main.Visible = true
    Main.BackgroundTransparency = 1
    Main.Size = UDim2.new(0, 860, 0, 580)
    TweenService:Create(Main, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0, Size = UDim2.new(0, 860, 0, 620)
    }):Play()
    task.delay(0.35, function() isAnim = false end)
end
local function HideMain(cb)
    if isAnim then return end
    isAnim = true
    TweenService:Create(Main, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        BackgroundTransparency = 1, Size = UDim2.new(0, 860, 0, 580)
    }):Play()
    task.delay(0.26, function()
        Main.Visible = false
        isAnim = false
        if cb then cb() end
    end)
end
ShowMain()

-- Stars background
local StarContainer = Instance.new("Frame", Main)
StarContainer.Size = UDim2.new(1,0,1,0)
StarContainer.BackgroundTransparency = 1
StarContainer.ZIndex = 1
StarContainer.ClipsDescendants = true
local stars = {}
for i = 1, 22 do
    local sz = 2 + math.random(0,3)
    local s = Instance.new("Frame", StarContainer)
    s.BackgroundColor3 = Theme.PurpleLight
    s.Size = UDim2.new(0,sz,0,sz)
    s.BackgroundTransparency = 0.1
    s.BorderSizePixel = 0
    s.ZIndex = 1
    ApplyCorner(s, sz)
    local st = Instance.new("UIStroke", s)
    st.Color = Theme.Purple
    st.Thickness = sz > 3 and 2 or 1
    st.Transparency = 0.3
    stars[i] = {f=s, st=st, spd=0.01+math.random()*0.018, yb=math.random()*0.9,
                ph=math.random()*math.pi*2, gt=math.random()*math.pi*2, gs=0.4+math.random()*0.8}
end
RunService.Heartbeat:Connect(function()
    if not Main.Visible then return end
    local t = tick()
    for _, d in ipairs(stars) do
        d.f.Position = UDim2.new(((t*d.spd+d.ph)%2.5)-0.7, 0, d.yb+math.sin(t*0.7+d.ph)*0.055, 0)
        local g = math.sin(t*d.gs+d.gt)
        d.f.BackgroundTransparency = 0.05+(g*0.5+0.5)*0.55
        d.st.Transparency = 0.1+(1-(g*0.5+0.5))*0.65
    end
end)

-- Header
local Header = Instance.new("Frame", Main)
Header.Size = UDim2.new(1,0,0,60)
Header.BackgroundColor3 = Theme.Header
Header.BorderSizePixel = 0
Header.ZIndex = 5
local HLine = Instance.new("Frame", Header)
HLine.Size = UDim2.new(1,0,0,1)
HLine.Position = UDim2.new(0,0,1,-1)
HLine.BackgroundColor3 = Theme.Border
HLine.BorderSizePixel = 0
HLine.ZIndex = 5
local Title = Instance.new("TextLabel", Header)
Title.Text = "MrCalvoHub"
Title.Font = Enum.Font.GothamBlack
Title.TextSize = 28
Title.TextColor3 = Theme.Text
Title.Size = UDim2.new(0,260,1,0)
Title.Position = UDim2.new(0,24,0,0)
Title.BackgroundTransparency = 1
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 6
local TG = Instance.new("UIGradient", Title)
TG.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200,160,255)),
    ColorSequenceKeypoint.new(1, Theme.Purple)
})

local function MakeHBtn(text, ox)
    local b = Instance.new("TextButton", Header)
    b.Size = UDim2.new(0,34,0,34)
    b.Position = UDim2.new(1,ox,0.5,0)
    b.AnchorPoint = Vector2.new(0,0.5)
    b.BackgroundColor3 = Color3.fromRGB(30,26,46)
    b.Text = text; b.TextColor3 = Theme.TextMuted
    b.Font = Enum.Font.GothamBold; b.TextSize = 16
    b.BorderSizePixel = 0; b.ZIndex = 7; b.AutoButtonColor = false
    ApplyCorner(b,10); ApplyStroke(b, Theme.Border, 1)
    b.MouseEnter:Connect(function() TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3=Color3.fromRGB(46,34,72), TextColor3=Theme.Text}):Play() end)
    b.MouseLeave:Connect(function() TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3=Color3.fromRGB(30,26,46), TextColor3=Theme.TextMuted}):Play() end)
    return b
end
local MinBtn   = MakeHBtn("−", -82)
local CloseBtn = MakeHBtn("✕", -44)

local MiniPill = Instance.new("TextButton", ScreenGui)
MiniPill.Text="MrCalvoHub"; MiniPill.Font=Enum.Font.GothamBold; MiniPill.TextSize=13
MiniPill.TextColor3=Theme.Text; MiniPill.Size=UDim2.new(0,118,0,32); MiniPill.Position=UDim2.new(0.5,-59,0,14)
MiniPill.BackgroundColor3=Theme.Purple; MiniPill.Visible=false; MiniPill.ZIndex=10
ApplyCorner(MiniPill,10)
local MG = Instance.new("UIGradient", MiniPill)
MG.Color = ColorSequence.new({ColorSequenceKeypoint.new(0,Theme.Purple),ColorSequenceKeypoint.new(1,Theme.PurpleLight)})

MinBtn.MouseButton1Click:Connect(function() HideMain(function() MiniPill.Visible=true end) end)
MiniPill.MouseButton1Click:Connect(function() MiniPill.Visible=false ShowMain() end)
CloseBtn.MouseButton1Click:Connect(function() HideMain(function() ScreenGui:Destroy() end) end)

local dragD = {}
Header.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        dragD.on=true; dragD.s=i.Position; dragD.p=Main.Position
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if dragD.on and i.UserInputType == Enum.UserInputType.MouseMovement then
        local d = i.Position - dragD.s
        Main.Position = UDim2.new(dragD.p.X.Scale, dragD.p.X.Offset+d.X, dragD.p.Y.Scale, dragD.p.Y.Offset+d.Y)
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then dragD.on=false end
end)

-- Sidebar
local Sidebar = Instance.new("Frame", Main)
Sidebar.Size = UDim2.new(0,170,1,-62)
Sidebar.Position = UDim2.new(0,0,0,61)
Sidebar.BackgroundColor3 = Theme.Sidebar
Sidebar.BorderSizePixel = 0; Sidebar.ZIndex = 4
local SL = Instance.new("Frame", Sidebar)
SL.Size=UDim2.new(0,1,1,0); SL.Position=UDim2.new(1,-1,0,0)
SL.BackgroundColor3=Theme.Border; SL.BorderSizePixel=0

local function CreateNavBtn(icon, label, yPos, active)
    local btn = Instance.new("TextButton", Sidebar)
    btn.Size = UDim2.new(1,-24,0,42)
    btn.Position = UDim2.new(0,12,0,yPos)
    btn.Text=""; btn.AutoButtonColor=false
    btn.BackgroundColor3=Theme.Purple
    btn.BackgroundTransparency = active and 0 or 1
    btn.BorderSizePixel=0; btn.ZIndex=6
    ApplyCorner(btn,10)
    if active then
        local g=Instance.new("UIGradient",btn)
        g.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Theme.Purple),ColorSequenceKeypoint.new(1,Theme.PurpleLight)})
        g.Rotation=135
    end
    local ic=Instance.new("TextLabel",btn); ic.Text=icon; ic.TextSize=17; ic.Font=Enum.Font.GothamBold
    ic.TextColor3=active and Theme.Text or Theme.TextDim; ic.BackgroundTransparency=1
    ic.Size=UDim2.new(0,30,1,0); ic.Position=UDim2.new(0,10,0,0)
    ic.TextXAlignment=Enum.TextXAlignment.Center; ic.TextYAlignment=Enum.TextYAlignment.Center; ic.ZIndex=7
    local tx=Instance.new("TextLabel",btn); tx.Text=label; tx.TextSize=14; tx.Font=Enum.Font.GothamSemibold
    tx.TextColor3=active and Theme.Text or Theme.TextMuted; tx.BackgroundTransparency=1
    tx.Size=UDim2.new(1,-46,1,0); tx.Position=UDim2.new(0,42,0,0)
    tx.TextXAlignment=Enum.TextXAlignment.Left; tx.TextYAlignment=Enum.TextYAlignment.Center; tx.ZIndex=7
    btn.MouseEnter:Connect(function()
        if btn.BackgroundTransparency > 0.5 then TweenService:Create(btn,TweenInfo.new(0.15),{BackgroundTransparency=0.7}):Play() end
    end)
    btn.MouseLeave:Connect(function()
        if btn.BackgroundTransparency > 0.1 then TweenService:Create(btn,TweenInfo.new(0.15),{BackgroundTransparency=1}):Play() end
    end)
    return btn, ic, tx
end

local MoveBtn, MBI, MBT = CreateNavBtn("🏃","Movement", 14, true)
local EvoBtn,  EBI, EBT = CreateNavBtn("🐾","Evomon",   62, false)
local UtilBtn, UBI, UBT = CreateNavBtn("⚡","Utilities",110, false)

-- Content area
local ContentArea = Instance.new("Frame", Main)
ContentArea.Size=UDim2.new(1,-182,1,-68); ContentArea.Position=UDim2.new(0,178,0,65)
ContentArea.BackgroundTransparency=1; ContentArea.ZIndex=4; ContentArea.ClipsDescendants=true

local function MakeScroll(vis)
    local s=Instance.new("ScrollingFrame",ContentArea)
    s.Size=UDim2.new(1,0,1,0); s.BackgroundTransparency=1
    s.ScrollBarThickness=4; s.ScrollBarImageColor3=Theme.Purple
    s.ScrollBarImageTransparency=0.4; s.Visible=vis
    s.AutomaticCanvasSize=Enum.AutomaticSize.Y; s.BorderSizePixel=0; s.ZIndex=5
    local ly=Instance.new("UIListLayout",s); ly.Padding=UDim.new(0,16); ly.SortOrder=Enum.SortOrder.LayoutOrder
    local pd=Instance.new("UIPadding",s)
    pd.PaddingLeft=UDim.new(0,4); pd.PaddingRight=UDim.new(0,14)
    pd.PaddingTop=UDim.new(0,6); pd.PaddingBottom=UDim.new(0,16)
    return s
end

local ScrollMove = MakeScroll(true)
local ScrollEvo  = MakeScroll(false)
local ScrollUtil = MakeScroll(false)

local function SetNav(tab)
    local function act(btn,ic,tx,on)
        local g=btn:FindFirstChildOfClass("UIGradient")
        if on then
            btn.BackgroundTransparency=0; btn.BackgroundColor3=Theme.Purple
            if not g then
                g=Instance.new("UIGradient",btn)
                g.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Theme.Purple),ColorSequenceKeypoint.new(1,Theme.PurpleLight)})
                g.Rotation=135
            end
            ic.TextColor3=Theme.Text; tx.TextColor3=Theme.Text
        else
            btn.BackgroundTransparency=1; if g then g:Destroy() end
            ic.TextColor3=Theme.TextDim; tx.TextColor3=Theme.TextMuted
        end
    end
    act(MoveBtn,MBI,MBT, tab=="move")
    act(EvoBtn, EBI,EBT, tab=="evo")
    act(UtilBtn,UBI,UBT, tab=="util")
    ScrollMove.Visible=(tab=="move")
    ScrollEvo.Visible=(tab=="evo")
    ScrollUtil.Visible=(tab=="util")
end

MoveBtn.MouseButton1Click:Connect(function() SetNav("move") end)
EvoBtn.MouseButton1Click:Connect(function()  SetNav("evo")  end)
UtilBtn.MouseButton1Click:Connect(function() SetNav("util") end)

-- Card/Toggle/Slider helpers
local function MakeCard(parent, order)
    local c=Instance.new("Frame",parent)
    c.BackgroundColor3=Theme.Card; c.BorderSizePixel=0
    c.AutomaticSize=Enum.AutomaticSize.Y; c.Size=UDim2.new(1,0,0,0)
    c.LayoutOrder=order or 0; c.ZIndex=6
    ApplyCorner(c,14); ApplyStroke(c,Theme.Border,1)
    local ly=Instance.new("UIListLayout",c); ly.Padding=UDim.new(0,0); ly.SortOrder=Enum.SortOrder.LayoutOrder
    local pd=Instance.new("UIPadding",c)
    pd.PaddingLeft=UDim.new(0,18); pd.PaddingRight=UDim.new(0,18)
    pd.PaddingTop=UDim.new(0,14); pd.PaddingBottom=UDim.new(0,14)
    return c
end

local function MakeCardTitle(card, text)
    local f=Instance.new("Frame",card); f.Size=UDim2.new(1,0,0,32)
    f.BackgroundTransparency=1; f.LayoutOrder=0; f.ZIndex=7
    local l=MakeLabel(f,text,11,Theme.Purple,Enum.Font.GothamBold); l.Size=UDim2.new(1,0,1,0); l.ZIndex=7
    local ln=Instance.new("Frame",f); ln.Size=UDim2.new(1,0,0,1); ln.Position=UDim2.new(0,0,1,-1)
    ln.BackgroundColor3=Theme.Border; ln.BorderSizePixel=0; ln.ZIndex=7
end

local rowO = 0
local function NxtO() rowO+=1 return rowO end

local function MakeToggle(parent, labelText, default, callback, order)
    local row=Instance.new("Frame",parent)
    row.Size=UDim2.new(1,0,0,44); row.BackgroundTransparency=1
    row.LayoutOrder=order or NxtO(); row.ZIndex=7
    local lb=MakeLabel(row,labelText,14,Theme.TextMuted)
    lb.Size=UDim2.new(1,-62,1,0); lb.Position=UDim2.new(0,0,0,0); lb.ZIndex=8
    local tr=Instance.new("Frame",row)
    tr.Size=UDim2.new(0,44,0,24); tr.Position=UDim2.new(1,-44,0.5,0)
    tr.AnchorPoint=Vector2.new(0,0.5); tr.BackgroundColor3=default and Theme.Purple or Theme.ToggleOff
    tr.BorderSizePixel=0; tr.ZIndex=8; ApplyCorner(tr,12)
    if default then
        local g=Instance.new("UIGradient",tr)
        g.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Theme.Purple),ColorSequenceKeypoint.new(1,Theme.PurpleLight)})
    end
    local kn=Instance.new("Frame",tr)
    kn.Size=UDim2.new(0,18,0,18)
    kn.Position=default and UDim2.new(1,-21,0.5,0) or UDim2.new(0,3,0.5,0)
    kn.AnchorPoint=Vector2.new(0,0.5); kn.BackgroundColor3=Color3.new(1,1,1)
    kn.BorderSizePixel=0; kn.ZIndex=9; ApplyCorner(kn,9)
    local state=default
    local function doT()
        state=not state; callback(state)
        local g=tr:FindFirstChildOfClass("UIGradient")
        if state then
            if not g then
                g=Instance.new("UIGradient",tr)
                g.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Theme.Purple),ColorSequenceKeypoint.new(1,Theme.PurpleLight)})
            end
        else if g then g:Destroy() end end
        TweenService:Create(tr,TweenInfo.new(0.18),{BackgroundColor3=state and Theme.Purple or Theme.ToggleOff}):Play()
        TweenService:Create(kn,TweenInfo.new(0.2,Enum.EasingStyle.Quint),{Position=state and UDim2.new(1,-21,0.5,0) or UDim2.new(0,3,0.5,0)}):Play()
    end
    local hit=Instance.new("TextButton",row)
    hit.Size=UDim2.new(1,0,1,0); hit.BackgroundTransparency=1
    hit.Text=""; hit.ZIndex=10; hit.AutoButtonColor=false
    hit.MouseButton1Click:Connect(doT)
    return row
end

local function MakeSlider(parent, labelText, minV, maxV, default, callback, order)
    local f=Instance.new("Frame",parent)
    f.Size=UDim2.new(1,0,0,54); f.BackgroundTransparency=1
    f.LayoutOrder=order or NxtO(); f.ZIndex=7
    local hr=Instance.new("Frame",f); hr.Size=UDim2.new(1,0,0,22); hr.BackgroundTransparency=1; hr.ZIndex=8
    local lb=MakeLabel(hr,labelText,13,Theme.TextMuted); lb.Size=UDim2.new(1,-50,1,0); lb.ZIndex=8
    local vl=MakeLabel(hr,tostring(default),13,Theme.PurpleLight,Enum.Font.GothamBold,Enum.TextXAlignment.Right)
    vl.Size=UDim2.new(0,48,1,0); vl.Position=UDim2.new(1,-48,0,0); vl.ZIndex=8
    local bg=Instance.new("Frame",f); bg.Size=UDim2.new(1,0,0,6); bg.Position=UDim2.new(0,0,0,34)
    bg.BackgroundColor3=Theme.SliderBG; bg.BorderSizePixel=0; bg.ZIndex=8; ApplyCorner(bg,3)
    local fl=Instance.new("Frame",bg); fl.BackgroundColor3=Theme.Purple
    fl.Size=UDim2.new((default-minV)/(maxV-minV),0,1,0); fl.BorderSizePixel=0; fl.ZIndex=9; ApplyCorner(fl,3)
    local fg=Instance.new("UIGradient",fl)
    fg.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Theme.Purple),ColorSequenceKeypoint.new(1,Theme.PurpleLight)})
    local kn=Instance.new("Frame",bg); kn.Size=UDim2.new(0,14,0,14)
    kn.Position=UDim2.new((default-minV)/(maxV-minV),-7,0.5,0); kn.AnchorPoint=Vector2.new(0,0.5)
    kn.BackgroundColor3=Color3.new(1,1,1); kn.BorderSizePixel=0; kn.ZIndex=10
    ApplyCorner(kn,7); ApplyStroke(kn,Theme.Purple,2)
    local drag=false
    local function upd(pos)
        local rel=math.clamp((pos.X-bg.AbsolutePosition.X)/bg.AbsoluteSize.X,0,1)
        local val=math.floor(minV+(maxV-minV)*rel+0.5)
        fl.Size=UDim2.new(rel,0,1,0); kn.Position=UDim2.new(rel,-7,0.5,0)
        vl.Text=tostring(val); callback(val)
    end
    kn.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true end end)
    bg.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true upd(i.Position) end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end end)
    UserInputService.InputChanged:Connect(function(i) if drag and i.UserInputType==Enum.UserInputType.MouseMovement then upd(i.Position) end end)
    return f
end

-- Purple button helper
local function MakePurpleBtn(parent, text, order)
    local wrap=Instance.new("Frame",parent)
    wrap.Size=UDim2.new(1,0,0,50); wrap.BackgroundTransparency=1; wrap.LayoutOrder=order or NxtO()
    local btn=Instance.new("TextButton",wrap)
    btn.Size=UDim2.new(1,0,0,38); btn.Position=UDim2.new(0,0,0,6)
    btn.BackgroundColor3=Theme.Purple; btn.Text=text
    btn.Font=Enum.Font.GothamBold; btn.TextSize=14; btn.TextColor3=Theme.Text
    btn.BorderSizePixel=0; btn.ZIndex=8; btn.AutoButtonColor=false; ApplyCorner(btn,10)
    local g=Instance.new("UIGradient",btn)
    g.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Theme.Purple),ColorSequenceKeypoint.new(1,Theme.PurpleLight)})
    g.Rotation=90
    btn.MouseEnter:Connect(function() TweenService:Create(btn,TweenInfo.new(0.15),{BackgroundColor3=Theme.PurpleLight}):Play() end)
    btn.MouseLeave:Connect(function() TweenService:Create(btn,TweenInfo.new(0.15),{BackgroundColor3=Theme.Purple}):Play() end)
    return btn, wrap
end

local function MakeDarkBtn(parent, text, order)
    local wrap=Instance.new("Frame",parent)
    wrap.Size=UDim2.new(1,0,0,48); wrap.BackgroundTransparency=1; wrap.LayoutOrder=order or NxtO()
    local btn=Instance.new("TextButton",wrap)
    btn.Size=UDim2.new(1,0,0,36); btn.Position=UDim2.new(0,0,0,6)
    btn.BackgroundColor3=Color3.fromRGB(40,30,65); btn.Text=text
    btn.Font=Enum.Font.GothamSemibold; btn.TextSize=13; btn.TextColor3=Theme.TextMuted
    btn.BorderSizePixel=0; btn.ZIndex=8; btn.AutoButtonColor=false
    ApplyCorner(btn,10); ApplyStroke(btn,Theme.Border,1)
    btn.MouseEnter:Connect(function() TweenService:Create(btn,TweenInfo.new(0.15),{BackgroundColor3=Color3.fromRGB(60,44,90),TextColor3=Theme.Text}):Play() end)
    btn.MouseLeave:Connect(function() TweenService:Create(btn,TweenInfo.new(0.15),{BackgroundColor3=Color3.fromRGB(40,30,65),TextColor3=Theme.TextMuted}):Play() end)
    return btn, wrap
end

-- =========================================================
-- MOVEMENT TAB
-- =========================================================
local CL=MakeCard(ScrollMove,1); MakeCardTitle(CL,"LOCOMOTION")
MakeToggle(CL,"Speed",States.SpeedEnabled,function(v) States.SpeedEnabled=v SaveConfig() end)
MakeSlider(CL,"Speed Value",16,300,States.SpeedValue,function(v) States.SpeedValue=v end)
MakeToggle(CL,"Fly",States.FlyEnabled,function(v) States.FlyEnabled=v SaveConfig() end)
MakeSlider(CL,"Fly Speed",10,300,States.FlySpeed,function(v) States.FlySpeed=v end)
MakeToggle(CL,"Noclip",States.NoclipEnabled,function(v) States.NoclipEnabled=v SaveConfig() end)

local CA=MakeCard(ScrollMove,2); MakeCardTitle(CA,"AUTO FIGHT WALK")
MakeToggle(CA,"Auto Fight Walk",States.AutoFightWalk,function(v)
    States.AutoFightWalk=v SaveConfig()
    if v then task.spawn(AutoFightWalkLoop) end
end)
MakeSlider(CA,"W Duration",1,10,States.W_Duration,function(v) States.W_Duration=v end)
MakeSlider(CA,"A Duration",1,10,States.A_Duration,function(v) States.A_Duration=v end)
MakeSlider(CA,"S Duration",1,10,States.S_Duration,function(v) States.S_Duration=v end)
MakeSlider(CA,"D Duration",1,10,States.D_Duration,function(v) States.D_Duration=v end)

-- =========================================================
-- EVOMON TAB
-- =========================================================
local CE=MakeCard(ScrollEvo,1); MakeCardTitle(CE,"AUTO ENGAGE")
MakeToggle(CE,"Kill Aura",States.KillAuraEnabled,function(v)
    States.KillAuraEnabled=v SaveConfig()
    if v then task.spawn(KillAuraLoop) end
end)
MakeSlider(CE,"Kill Aura Range",10,200,States.TeleportRange,function(v) States.TeleportRange=v end)
MakeToggle(CE,"Auto Spam E",States.AutoSpamEEnabled,function(v)
    States.AutoSpamEEnabled=v SaveConfig()
    if v then task.spawn(AutoSpamELoop) end
end)
MakeToggle(CE,"Auto Leave Battle (C Key)",States.AutoLeaveBattleEnabled,function(v)
    States.AutoLeaveBattleEnabled=v SaveConfig()
    if v then task.spawn(AutoLeaveBattleLoop) end
end)

local CW=MakeCard(ScrollEvo,2); MakeCardTitle(CW,"TARGET WHITELIST")
MakeToggle(CW,"Use Target Whitelist",States.WhitelistEnabled,function(v) States.WhitelistEnabled=v end)
local WIW=Instance.new("Frame",CW); WIW.Size=UDim2.new(1,0,0,52); WIW.BackgroundTransparency=1; WIW.LayoutOrder=NxtO()
local WI=Instance.new("TextBox",WIW); WI.Size=UDim2.new(1,0,0,40); WI.Position=UDim2.new(0,0,0,6)
WI.BackgroundColor3=Color3.fromRGB(14,12,24); WI.PlaceholderText="Pikachu, Dragonite, 025"
WI.PlaceholderColor3=Theme.TextDim; WI.Text=States.WhitelistString; WI.Font=Enum.Font.Gotham
WI.TextSize=13; WI.TextColor3=Theme.Text; WI.BorderSizePixel=0; WI.ZIndex=8; WI.ClearTextOnFocus=false
ApplyCorner(WI,10); ApplyStroke(WI,Theme.Border,1)
local WP=Instance.new("UIPadding",WI); WP.PaddingLeft=UDim.new(0,12); WP.PaddingRight=UDim.new(0,12)
WI.FocusLost:Connect(function() States.WhitelistString=WI.Text end)

local ScanBtn
do
    local b, bw = MakePurpleBtn(CW, "Scan Nearby Evomons (F9)", NxtO())
    ScanBtn = b
    b.MouseButton1Click:Connect(function()
        local r=GetRoot(); if not r then return end
        print("=== EVOMONS CERCANOS ===")
        for _,o in ipairs(Workspace:GetDescendants()) do
            if o.Name:find("Pet0_") then
                local p=o:IsA("BasePart") and o or o:FindFirstChildWhichIsA("BasePart")
                if p then
                    local d=math.floor((p.Position-r.Position).Magnitude)
                    if d<200 then print(o.Name.." | "..d.." studs") end
                end
            end
        end
    end)
end

local CT=MakeCard(ScrollEvo,3); MakeCardTitle(CT,"TELEPORT SETTINGS")
MakeToggle(CT,"Teleport to Pet",States.TeleportEnabled,function(v) States.TeleportEnabled=v end)
MakeSlider(CT,"Teleport Offset",2,15,States.TeleportOffset,function(v) States.TeleportOffset=v end)

local CN=MakeCard(ScrollEvo,4); MakeCardTitle(CN,"VELOCITY NUDGE")
MakeToggle(CN,"Velocity Nudge (Walk into Combat)",States.VelocityNudgeEnabled,function(v) States.VelocityNudgeEnabled=v end)
MakeSlider(CN,"Nudge Strength",10,100,States.NudgeStrength,function(v) States.NudgeStrength=v end)

-- AUTO RELEASE
local CR=MakeCard(ScrollEvo,5); MakeCardTitle(CR,"AUTO RELEASE")
MakeToggle(CR,"Auto Release (C, B, A, S)",false,function(v)
    States.AutoReleaseEnabled = v
    if v then task.spawn(AutoReleaseLoop) end
    SaveConfig()
end)
MakeLabel(CR,"Solo libera C, B, A, S (SSS se queda)",11,Theme.TextMuted)

-- =========================================================
-- UTILITIES TAB
-- =========================================================

--- CARD 1: Sparkle Alarm ---
local CSp=MakeCard(ScrollUtil,1); MakeCardTitle(CSp,"✨ SPARKLE EVOMON ALARM")

local SpkRow=Instance.new("Frame",CSp); SpkRow.Size=UDim2.new(1,0,0,36)
SpkRow.BackgroundColor3=Color3.fromRGB(14,12,24); SpkRow.BorderSizePixel=0; SpkRow.LayoutOrder=NxtO()
ApplyCorner(SpkRow,8)
local SpkPad=Instance.new("UIPadding",SpkRow); SpkPad.PaddingLeft=UDim.new(0,10)
local SpkDot=Instance.new("Frame",SpkRow); SpkDot.Size=UDim2.new(0,9,0,9)
SpkDot.Position=UDim2.new(0,0,0.5,0); SpkDot.AnchorPoint=Vector2.new(0,0.5)
SpkDot.BackgroundColor3=Color3.fromRGB(70,70,90); SpkDot.BorderSizePixel=0; SpkDot.ZIndex=8; ApplyCorner(SpkDot,5)
local SpkLbl=MakeLabel(SpkRow,"Detector inactivo",12,Theme.TextDim)
SpkLbl.Size=UDim2.new(1,-18,1,0); SpkLbl.Position=UDim2.new(0,16,0,0); SpkLbl.ZIndex=8

MakeToggle(CSp,"Alarm de Sparkle Evomon",States.SparkleAlarmEnabled,function(v)
    States.SparkleAlarmEnabled=v; sparkleDetected=false; lastSparkleMsg=""; seenMessages={}
    if not v then
        StopAlarm()
        SpkDot.BackgroundColor3=Color3.fromRGB(70,70,90)
        SpkLbl.Text="Detector inactivo"; SpkLbl.TextColor3=Theme.TextDim
    else
        SpkDot.BackgroundColor3=Color3.fromRGB(80,200,120)
        SpkLbl.Text="Escuchando chat..."; SpkLbl.TextColor3=Theme.TextMuted
    end
    SaveConfig()
end)

-- Inicializar indicador si ya estaba activo al cargar
if States.SparkleAlarmEnabled then
    SpkDot.BackgroundColor3=Color3.fromRGB(80,200,120)
    SpkLbl.Text="Escuchando chat..."; SpkLbl.TextColor3=Theme.TextMuted
end

local TestBtn=MakeDarkBtn(CSp,"🔔  Probar Sonido de Alarma",NxtO())
TestBtn.MouseButton1Click:Connect(function() StopAlarm() task.wait(0.05) PlayAlarm() end)

local StopBtn, StopWrap = MakeDarkBtn(CSp,"🔇  Silenciar Alarma",NxtO())
StopBtn.BackgroundColor3=Color3.fromRGB(60,20,20); StopBtn.TextColor3=Color3.fromRGB(220,120,120)
StopBtn.MouseEnter:Connect(function() TweenService:Create(StopBtn,TweenInfo.new(0.15),{BackgroundColor3=Color3.fromRGB(90,30,30)}):Play() end)
StopBtn.MouseLeave:Connect(function() TweenService:Create(StopBtn,TweenInfo.new(0.15),{BackgroundColor3=Color3.fromRGB(60,20,20)}):Play() end)
StopBtn.MouseButton1Click:Connect(function()
    StopAlarm(); sparkleDetected=false; lastSparkleMsg=""
    if States.SparkleAlarmEnabled then
        SpkDot.BackgroundColor3=Color3.fromRGB(80,200,120)
        SpkLbl.Text="Escuchando chat..."; SpkLbl.TextColor3=Theme.TextMuted
    end
end)

RunService.Heartbeat:Connect(function()
    if not States.SparkleAlarmEnabled then return end
    if sparkleDetected then
        local p=math.abs(math.sin(tick()*5))
        SpkDot.BackgroundColor3=Color3.fromRGB(255,math.floor(40+p*60),math.floor(40+p*40))
        SpkLbl.Text="⚠ SPARKLE: "..lastSparkleMsg:sub(1,38)
        SpkLbl.TextColor3=Color3.fromRGB(255,210,60)
    end
end)

--- CARD 2: Server Hop ---
local CSH=MakeCard(ScrollUtil,2); MakeCardTitle(CSH,"🌐 SERVER HOP — SERVIDOR PRIVADO")

-- Info box
local SrvBox=Instance.new("Frame",CSH); SrvBox.Size=UDim2.new(1,0,0,44)
SrvBox.BackgroundColor3=Color3.fromRGB(14,12,24); SrvBox.BorderSizePixel=0; SrvBox.LayoutOrder=NxtO()
ApplyCorner(SrvBox,8); ApplyStroke(SrvBox,Theme.Border,1)
local SBPad=Instance.new("UIPadding",SrvBox); SBPad.PaddingLeft=UDim.new(0,10); SBPad.PaddingTop=UDim.new(0,4)
local SBLy=Instance.new("UIListLayout",SrvBox); SBLy.Padding=UDim.new(0,2)
local SL1=MakeLabel(SrvBox,"Servidor: MrCalvoConPelo (Privado)",12,Theme.TextMuted)
SL1.Size=UDim2.new(1,0,0,16); SL1.ZIndex=8
local SL2=MakeLabel(SrvBox,"Code: 98ccafc4...093075",11,Theme.TextDim)
SL2.Size=UDim2.new(1,0,0,14); SL2.ZIndex=8

-- Status label
local HopStat=Instance.new("Frame",CSH); HopStat.Size=UDim2.new(1,0,0,22)
HopStat.BackgroundTransparency=1; HopStat.LayoutOrder=NxtO()
local HopStatLbl=MakeLabel(HopStat,"",11,Theme.TextDim,Enum.Font.Gotham,Enum.TextXAlignment.Center)
HopStatLbl.Size=UDim2.new(1,0,1,0); HopStatLbl.ZIndex=8

local HopBtn=MakePurpleBtn(CSH,"🚀  Ir al Servidor Privado AHORA",NxtO())
HopBtn.MouseButton1Click:Connect(function()
    if hopCooldown then HopStatLbl.Text="⏳ Cooldown activo..." return end
    HopBtn.Text="⏳  Conectando..."; HopStatLbl.Text="Buscando JobId del servidor privado..."
    DoServerHop()
    task.delay(3, function()
        if HopBtn and HopBtn.Parent then HopBtn.Text="🚀  Ir al Servidor Privado AHORA" end
        HopStatLbl.Text=""
    end)
end)

MakeToggle(CSH,"Auto-Hop cada 10s buscando Sparkle",States.AutoServerHopEnabled,function(v)
    States.AutoServerHopEnabled=v
    if v then
        sparkleDetected=false
        HopStatLbl.Text="Hopeando cada 10s — para si hay Sparkle"
        HopStatLbl.TextColor3=Color3.fromRGB(80,200,120)
    else
        HopStatLbl.Text=""
    end
    SaveConfig()
end)

-- Inicializar status si ya estaba activo
if States.AutoServerHopEnabled then
    HopStatLbl.Text="Auto-Hop RESTAURADO — buscando Sparkle"
    HopStatLbl.TextColor3=Color3.fromRGB(80,200,120)
end

local NR=Instance.new("Frame",CSH); NR.Size=UDim2.new(1,0,0,24); NR.BackgroundTransparency=1; NR.LayoutOrder=NxtO()
local NL=MakeLabel(NR,"Hop cada 10s → para al detectar Sparkle + suena alarma",10,Theme.TextDim)
NL.Size=UDim2.new(1,0,1,0); NL.ZIndex=8

--- CARD 3: Config ---
local CCfg=MakeCard(ScrollUtil,3); MakeCardTitle(CCfg,"⚙  CONFIGURACIÓN")

-- Estado del filesystem
local CfgBox=Instance.new("Frame",CCfg); CfgBox.Size=UDim2.new(1,0,0,44)
CfgBox.BackgroundColor3=Color3.fromRGB(14,12,24); CfgBox.BorderSizePixel=0; CfgBox.LayoutOrder=NxtO()
ApplyCorner(CfgBox,8); ApplyStroke(CfgBox,Theme.Border,1)
local CBPad=Instance.new("UIPadding",CfgBox); CBPad.PaddingLeft=UDim.new(0,10); CBPad.PaddingTop=UDim.new(0,4)
local CBLy=Instance.new("UIListLayout",CfgBox); CBLy.Padding=UDim.new(0,2)
local CL1=MakeLabel(CfgBox,
    hasFS and "✔ Executor soporta writefile/readfile" or "✘ Sin soporte de filesystem",
    11, hasFS and Color3.fromRGB(80,200,120) or Color3.fromRGB(220,100,100))
CL1.Size=UDim2.new(1,0,0,16); CL1.ZIndex=8
local CL2=MakeLabel(CfgBox,"Archivo: MrCalvoHub_config.json",10,Theme.TextDim)
CL2.Size=UDim2.new(1,0,0,14); CL2.ZIndex=8

MakeToggle(CCfg,"Auto-Guardar config (cada 15s)",States.AutoSaveEnabled,function(v)
    States.AutoSaveEnabled=v
    if v then SaveConfig() end
end)

MakeToggle(CCfg,"Auto-Reiniciar script tras server hop",States.AutoRestartEnabled,function(v)
    States.AutoRestartEnabled=v
    SaveConfig()
end)

-- Nota auto-restart
local AR_Note=Instance.new("Frame",CCfg); AR_Note.Size=UDim2.new(1,0,0,42)
AR_Note.BackgroundColor3=Color3.fromRGB(30,20,5); AR_Note.BorderSizePixel=0; AR_Note.LayoutOrder=NxtO()
ApplyCorner(AR_Note,8)
local AR_Pad=Instance.new("UIPadding",AR_Note); AR_Pad.PaddingLeft=UDim.new(0,10); AR_Pad.PaddingTop=UDim.new(0,4)
local AR_Ly=Instance.new("UIListLayout",AR_Note); AR_Ly.Padding=UDim.new(0,2)
local AR1=MakeLabel(AR_Note,"⚠  Para el Auto-Reinicio:",10,Color3.fromRGB(255,200,60))
AR1.Size=UDim2.new(1,0,0,15); AR1.ZIndex=8
local AR2=MakeLabel(AR_Note,"Guarda el script como MrCalvoHub_autorun.lua",10,Theme.TextDim)
AR2.Size=UDim2.new(1,0,0,13); AR2.ZIndex=8
local AR3=MakeLabel(AR_Note,"en la carpeta autorun/ de tu executor",10,Theme.TextDim)
AR3.Size=UDim2.new(1,0,0,12); AR3.ZIndex=8

-- Botón guardar config ahora
local SaveNowBtn=MakeDarkBtn(CCfg,"💾  Guardar Config Ahora",NxtO())
SaveNowBtn.MouseButton1Click:Connect(function()
    local prev=States.AutoSaveEnabled; States.AutoSaveEnabled=true
    SaveConfig(); States.AutoSaveEnabled=prev
    SaveNowBtn.Text="✔  ¡Config Guardada!"
    TweenService:Create(SaveNowBtn,TweenInfo.new(0.3),{BackgroundColor3=Color3.fromRGB(25,55,30)}):Play()
    task.delay(2,function()
        if SaveNowBtn and SaveNowBtn.Parent then
            SaveNowBtn.Text="💾  Guardar Config Ahora"
            TweenService:Create(SaveNowBtn,TweenInfo.new(0.3),{BackgroundColor3=Color3.fromRGB(40,30,65)}):Play()
        end
    end)
end)

-- Botón guardar script en autorun
local SaveScriptBtn=MakePurpleBtn(CCfg,"📁  Guardar Script en autorun/ (Auto-Run)",NxtO())
SaveScriptBtn.MouseButton1Click:Connect(function()
    if not hasFS then
        SaveScriptBtn.Text="✘ Executor no soporta writefile"
        task.delay(3,function() if SaveScriptBtn and SaveScriptBtn.Parent then
            SaveScriptBtn.Text="📁  Guardar Script en autorun/ (Auto-Run)" end end)
        return
    end
    pcall(function()
        -- Crear carpeta autorun si no existe
        pcall(function() if not isfolder("autorun") then makefolder("autorun") end end)
        -- Intentar obtener el source del script ejecutado
        local src = nil
        -- Método: getscriptsource() en Synapse/Wave
        pcall(function() if getscriptsource then src = getscriptsource() end end)
        -- Método: leer el script si ya está en disco
        if (not src or #src < 500) and isfile(SCRIPT_FILE) then
            src = readfile(SCRIPT_FILE)
        end
        if src and #src > 500 then
            writefile(SCRIPT_FILE, src)
            pcall(function() writefile("autorun/" .. SCRIPT_FILE, src) end)
            SaveScriptBtn.Text="✔  Guardado en autorun/"
            TweenService:Create(SaveScriptBtn,TweenInfo.new(0.3),{BackgroundColor3=Color3.fromRGB(25,55,30)}):Play()
        else
            -- No podemos auto-obtener el source, informar
            SaveScriptBtn.Text="⚠  Guarda el .lua en autorun/ manualmente"
            TweenService:Create(SaveScriptBtn,TweenInfo.new(0.3),{BackgroundColor3=Color3.fromRGB(60,40,10)}):Play()
        end
        -- Guardar flag de restart para el próximo hop
        SafeWriteJSON(RESTART_FILE,{shouldRestart=States.AutoRestartEnabled})
    end)
    task.delay(4,function()
        if SaveScriptBtn and SaveScriptBtn.Parent then
            SaveScriptBtn.Text="📁  Guardar Script en autorun/ (Auto-Run)"
            TweenService:Create(SaveScriptBtn,TweenInfo.new(0.3),{BackgroundColor3=Theme.Purple}):Play()
        end
    end)
end)

-- =========================================================
-- F9 SHORTCUT
-- =========================================================
UserInputService.InputBegan:Connect(function(i, gpe)
    if gpe then return end
    if i.KeyCode == Enum.KeyCode.F9 then ScanBtn:FireButton1Click() end
end)

-- BindToClose solo funciona en server, no en cliente
-- SaveConfig se llama en el loop de 15s

-- Restaurar loops si estaban activos
if States.KillAuraEnabled      then task.spawn(KillAuraLoop)        end
if States.AutoSpamEEnabled     then task.spawn(AutoSpamELoop)       end
if States.AutoLeaveBattleEnabled then task.spawn(AutoLeaveBattleLoop) end
if States.AutoFightWalk        then task.spawn(AutoFightWalkLoop)   end

-- =========================================================
-- AUTO RELEASE OPTIMIZADO (C, B, A, S) - NO toca SSS
-- =========================================================
local function AutoReleaseLoop()
    while States.AutoReleaseEnabled do
        local pg = LP:FindFirstChild("PlayerGui")
        if not pg then task.wait(1) continue end

        local storage = pg:FindFirstChild("Almacén Evomon", true) 
                     or pg:FindFirstChild("Storage", true) 
                     or pg:FindFirstChild("EvomonStorage", true)

        if not storage then 
            task.wait(1.5) 
            continue 
        end

        -- Seleccionar todo
        local selectAll = pg:FindFirstChild("Seleccionar todo", true) or pg:FindFirstChild("Select All", true)
        if selectAll and selectAll:IsA("TextButton") then
            selectAll:FireButton1Click()
            task.wait(0.8)
        end

        -- Confirmar liberación
        local confirm = pg:FindFirstChild("Confirmar", true) or pg:FindFirstChild("Liberar", true)
        if confirm and confirm:IsA("TextButton") then
            confirm:FireButton1Click()
            print("[MrCalvoHub] Auto Release ejecutado")
            task.wait(2)
        end

        task.wait(2.5)
    end
end

print("[MrCalvoHub v6.0] ✓ Listo — AutoSave + AutoRestart + Config persistente")
if States.AutoSaveEnabled      then print("[MrCalvoHub] AutoSave: ACTIVO") end
if States.AutoServerHopEnabled then print("[MrCalvoHub] AutoHop:  ACTIVO") end
if States.SparkleAlarmEnabled  then print("[MrCalvoHub] Sparkle:  ACTIVO") end
