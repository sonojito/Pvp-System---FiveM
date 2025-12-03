--[[
    ARENA PVP - CLIENT
    Versione completamente riscritta
]]

-- Variabili
ESX = nil
local isNuiOpen = false
local inQueue = false
local inGame = false
local opponent = nil
local myScore = 0
local enemyScore = 0
local roundsLeft = 0

-- Init ESX
Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(100)
    end
    
    -- Crea NPC
    if PVP.NPC.Enabled then
        SpawnNPC()
    end
    
    -- Carica classifica
    Wait(1000)
    TriggerServerEvent('PVP:requestLeaderboard')
end)

-- Spawna NPC
function SpawnNPC()
    local model = GetHashKey(PVP.NPC.Model)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(100) end
    
    local ped = CreatePed(4, model, PVP.NPC.Coords.x, PVP.NPC.Coords.y, PVP.NPC.Coords.z - 1.0, 0.0, false, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    
    -- Thread interazione
    Citizen.CreateThread(function()
        while true do
            local wait = 500
            local dist = #(GetEntityCoords(PlayerPedId()) - PVP.NPC.Coords)
            
            if dist < 20.0 then
                wait = 0
                DrawMarker(1, PVP.NPC.Coords.x, PVP.NPC.Coords.y, PVP.NPC.Coords.z + 1.0, 0,0,0, 0,0,0, 0.5,0.5,0.3, 0,200,255,150, false, true, 2, nil, nil, false)
                
                if dist < 2.5 then
                    ESX.ShowHelpNotification("Premi ~INPUT_CONTEXT~ per aprire Arena PVP")
                    if IsControlJustPressed(0, 38) then
                        OpenMenu()
                    end
                end
            end
            
            Citizen.Wait(wait)
        end
    end)
end

-- =====================
-- NUI FUNCTIONS
-- =====================

function OpenMenu()
    if inGame then
        Notifica("Non puoi aprire il menu in partita!")
        return
    end
    
    isNuiOpen = true
    SetNuiFocus(true, true)
    
    SendNUIMessage({
        type = "open",
        inQueue = inQueue,
        inGame = inGame
    })
end

function CloseMenu()
    isNuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = "close" })
end

-- Comando /pvp
RegisterCommand('pvp', function()
    OpenMenu()
end, false)

-- =====================
-- NUI CALLBACKS
-- =====================

RegisterNUICallback('close', function(data, cb)
    CloseMenu()
    cb('ok')
end)

RegisterNUICallback('join_queue', function(data, cb)
    if not inQueue and not inGame then
        inQueue = true
        TriggerServerEvent('PVP:JoinQueue')
        SendNUIMessage({ type = "queue_joined" })
    end
    cb('ok')
end)

RegisterNUICallback('leave_queue', function(data, cb)
    if inQueue then
        inQueue = false
        TriggerServerEvent('PVP:LeaveQueue')
        SendNUIMessage({ type = "queue_left" })
    end
    cb('ok')
end)

RegisterNUICallback('leave_match', function(data, cb)
    if inGame and opponent then
        TriggerServerEvent('PVP:LeaveMatch', opponent)
    end
    cb('ok')
end)

RegisterNUICallback('get_leaderboard', function(data, cb)
    TriggerServerEvent('PVP:requestLeaderboard')
    cb('ok')
end)

RegisterNUICallback('get_stats', function(data, cb)
    TriggerServerEvent('PVP:requestPlayerStats')
    cb('ok')
end)

-- =====================
-- SERVER EVENTS
-- =====================

-- Match trovato
RegisterNetEvent('PVP:MatchFound')
AddEventHandler('PVP:MatchFound', function(myId, enemyId, enemyServerId)
    inQueue = false
    inGame = true
    opponent = enemyServerId
    myScore = 0
    enemyScore = 0
    roundsLeft = PVP.Round
    
    -- Chiudi menu
    CloseMenu()
    
    -- Posiziona giocatore
    for _, arena in pairs(Game) do
        local spawnPos = myId > enemyId and arena.uno or arena.due
        SetEntityCoords(PlayerPedId(), spawnPos, false, false, false, true)
        FreezeEntityPosition(PlayerPedId(), true)
    end
    
    -- Countdown
    Countdown()
    
    -- Inizia partita
    FreezeEntityPosition(PlayerPedId(), false)
    StartMatch(enemyServerId)
    
    -- Mostra HUD
    SendNUIMessage({
        type = "match_start",
        rounds = PVP.Round,
        enemy = GetPlayerName(GetPlayerFromServerId(enemyServerId))
    })
end)

-- Countdown
function Countdown()
    for i = 3, 1, -1 do
        ShowCountdown(tostring(i))
        Wait(1000)
    end
    ShowCountdown("GO!")
    Wait(500)
end

function ShowCountdown(text)
    local scaleform = RequestScaleformMovie("COUNTDOWN")
    while not HasScaleformMovieLoaded(scaleform) do Wait(0) end
    
    BeginScaleformMovieMethod(scaleform, "FADE_MP")
    ScaleformMovieMethodAddParamTextureNameString(text)
    EndScaleformMovieMethod()
    
    local timer = GetGameTimer() + 800
    while GetGameTimer() < timer do
        DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255, 0)
        Wait(0)
    end
    
    SetScaleformMovieAsNoLongerNeeded(scaleform)
end

-- Inizia match
function StartMatch(enemyId)
    -- Dai arma
    if PVP.ESX then
        TriggerServerEvent('PVP_esx')
    else
        GiveWeaponToPed(PlayerPedId(), GetHashKey(PVP.Weapon), 200, false, true)
    end
    
    -- Thread controllo morte
    Citizen.CreateThread(function()
        while inGame do
            if GetEntityHealth(PlayerPedId()) <= 0 then
                TriggerServerEvent('PVP:PlayerDied', enemyId)
                Wait(500)
            end
            Wait(1)
        end
    end)
    
    -- Thread anti-leave arena
    Citizen.CreateThread(function()
        while inGame do
            local pos = GetEntityCoords(PlayerPedId())
            local center = Game.uno.uno
            if #(pos - center) > 100.0 then
                Notifica("Sei uscito dall'arena!")
                TriggerServerEvent('PVP:LeaveMatch', enemyId)
            end
            Wait(1000)
        end
    end)
end

-- Ho vinto round
RegisterNetEvent('PVP:RoundWon')
AddEventHandler('PVP:RoundWon', function()
    myScore = myScore + 1
    roundsLeft = roundsLeft - 1
    
    SendNUIMessage({
        type = "score_update",
        myScore = myScore,
        enemyScore = enemyScore,
        round = PVP.Round - roundsLeft
    })
    
    if roundsLeft > 0 then
        Notifica("Hai vinto il round! " .. myScore .. " - " .. enemyScore)
        Wait(500)
        SetEntityCoords(PlayerPedId(), Game.uno.due, false, false, false, true)
    else
        -- Match finito, ho vinto
        TriggerServerEvent('PVP:MatchEnd', myScore, opponent)
    end
end)

-- Ho perso round
RegisterNetEvent('PVP:RoundLost')
AddEventHandler('PVP:RoundLost', function()
    enemyScore = enemyScore + 1
    roundsLeft = roundsLeft - 1
    
    SendNUIMessage({
        type = "score_update",
        myScore = myScore,
        enemyScore = enemyScore,
        round = PVP.Round - roundsLeft
    })
    
    if roundsLeft > 0 then
        Notifica("Hai perso il round! " .. myScore .. " - " .. enemyScore)
        Wait(500)
        SetEntityCoords(PlayerPedId(), Game.uno.uno, false, false, false, true)
    else
        -- Match finito
        TriggerServerEvent('PVP:MatchEnd', myScore, opponent)
    end
end)

-- Match terminato
RegisterNetEvent('PVP:MatchEnded')
AddEventHandler('PVP:MatchEnded', function()
    inGame = false
    inQueue = false
    opponent = nil
    
    -- Torna spawn
    SetEntityCoords(PlayerPedId(), Game.uno.start, false, false, false, true)
    
    SendNUIMessage({ type = "match_end" })
    Notifica("Partita terminata!")
end)

-- Aggiorna coda
RegisterNetEvent('PVP:QueueUpdate')
AddEventHandler('PVP:QueueUpdate', function(count)
    SendNUIMessage({ type = "queue_count", count = count })
end)

-- Rimosso dalla coda
RegisterNetEvent('PVP:QueueLeft')
AddEventHandler('PVP:QueueLeft', function()
    inQueue = false
    SendNUIMessage({ type = "queue_left" })
end)

-- Leaderboard
RegisterNetEvent('PVP:updateLeaderboard')
AddEventHandler('PVP:updateLeaderboard', function(data)
    SendNUIMessage({ type = "leaderboard", data = data })
end)

-- Stats personali
RegisterNetEvent('PVP:updatePlayerStats')
AddEventHandler('PVP:updatePlayerStats', function(stats)
    SendNUIMessage({ type = "stats", data = stats })
end)

-- Notifica server
RegisterNetEvent('PVP:Notify')
AddEventHandler('PVP:Notify', function(msg)
    Notifica(msg)
end)

-- Cleanup
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        SetNuiFocus(false, false)
    end
end)
