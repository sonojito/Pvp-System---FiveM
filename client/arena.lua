-- Variabili per il sistema di classifica
GlobalLeaderboard = {}
local leaderboardLoaded = false
local InGame = false
local attesa = false
UltimaPosizione = {} 
idavversario = nil
round = 0 
roundtot = PVP.Round
Avversario = {}
req = false
numerovittore = 0

-- NPC
local npcEntity = nil
ESX = nil

-- Carica la classifica dal server
RegisterNetEvent('PVP:updateLeaderboard')
AddEventHandler('PVP:updateLeaderboard', function(leaderboard)
    GlobalLeaderboard = leaderboard
    leaderboardLoaded = true
end)

-- Menu interazione NPC
function OpenPVPMenu()
    ESX.UI.Menu.CloseAll()
    
    local elements = {
        {label = 'Inizia 1v1', value = 'start'},
        {label = 'Visualizza Classifica', value = 'leaderboard'}
    }
    
    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'pvp_main_menu',
    {
        title = 'Arena PVP',
        align = 'top-left',
        elements = elements
    }, function(data, menu)
        if data.current.value == 'start' then
            if not req then
                req = true
                TriggerServerEvent("PVP:1v1")
                Notifica(PVP.Translate_Coda)
            else
                Notifica("Sei già in attesa")
            end
        elseif data.current.value == 'leaderboard' then
            TriggerServerEvent('PVP:requestLeaderboard')
            ShowLeaderboard()
        end
    end, function(data, menu)
        menu.close()
    end)
end

-- Visualizza classifica
function ShowLeaderboard()
    local elements = {}
    
    if not leaderboardLoaded then
        table.insert(elements, {label = "Caricamento classifica... Premi Ricarica", value = "reload"})
    elseif #GlobalLeaderboard == 0 then
        table.insert(elements, {label = "Nessun dato disponibile", value = "empty"})
        table.insert(elements, {label = "Ricarica", value = "reload"})
    else
        for i, entry in ipairs(GlobalLeaderboard) do
            table.insert(elements, {
                label = string.format("#%d %s - Vittorie: %d  Uccisioni: %d", 
                    i, entry.name, entry.wins, entry.kills),
                value = "entry"
            })
        end
        table.insert(elements, {label = "Ricarica", value = "reload"})
    end
    
    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'leaderboard_menu',
    {
        title = 'Classifica Globale',
        align = 'top-left',
        elements = elements
    }, function(data, menu)
        if data.current.value == "reload" then
            menu.close()
            TriggerServerEvent('PVP:requestLeaderboard')
            Notifica("Classifica ricaricata")
            Citizen.Wait(300)
            ShowLeaderboard()
        end
    end, function(data, menu)
        menu.close()
    end)
end

-- Inizializzazione ESX
Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(100)
    end

    -- Ora che ESX è pronto, crea l'NPC se abilitato
    if PVP.NPC.Enabled then
        CreateNPC()
        StartNPCThread()
    end
    
    -- Carica classifica all'avvio
    TriggerServerEvent('PVP:requestLeaderboard')
end)

function CreateNPC()
    local model = GetHashKey(PVP.NPC.Model)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(500)
    end
    
    -- Verifica e aggiusta l'altezza Z per evitare che l'NPC sia in aria
    local ground, z = GetGroundZFor_3dCoord(PVP.NPC.Coords.x, PVP.NPC.Coords.y, PVP.NPC.Coords.z, 1)
    local spawnZ = ground and z or PVP.NPC.Coords.z
    
    npcEntity = CreatePed(4, model, PVP.NPC.Coords.x, PVP.NPC.Coords.y, spawnZ + 0.05, 0.0, false, true)
    FreezeEntityPosition(npcEntity, true)
    SetEntityInvincible(npcEntity, true)
    SetBlockingOfNonTemporaryEvents(npcEntity, true)
    TaskStartScenarioInPlace(npcEntity, PVP.NPC.Scenario, 0, true)
end

function StartNPCThread()
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local distanza = #(playerCoords - PVP.NPC.Coords)
            
            if distanza < 3.0 then
                ESX.ShowHelpNotification(PVP.Translate_Start)
                if IsControlJustReleased(0, 38) then -- Tasto E
                    OpenPVPMenu()
                end
            elseif distanza < PVP.NPC.Marker.DrawDistance then
                DrawMarker(
                    PVP.NPC.Marker.Type,
                    PVP.NPC.Coords.x, PVP.NPC.Coords.y, PVP.NPC.Coords.z + 1.0,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    PVP.NPC.Marker.Size.x, PVP.NPC.Marker.Size.y, PVP.NPC.Marker.Size.z,
                    PVP.NPC.Marker.Color.r, PVP.NPC.Marker.Color.g, PVP.NPC.Marker.Color.b, PVP.NPC.Marker.Color.a,
                    false, true, 2, nil, nil, false
                )
            end
        end
    end)
end

-- Pulizia NPC
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        if DoesEntityExist(npcEntity) then
            DeleteEntity(npcEntity)
        end
    end
end)

RegisterNetEvent('PVP:1v1confermato')
AddEventHandler('PVP:1v1confermato', function(id, id2, av)
    for k,v in pairs(Game) do 
        if id > id2 then
            Avversario = {av}
            UltimaPosizione = {v.uno}
            SetEntityCoords(PlayerPedId(), v.uno, false, false, false, true)
        else
            SetEntityCoords(PlayerPedId(), v.due, false, false, false, true)
            UltimaPosizione = {v.due}
        end
        FreezeEntityPosition(PlayerPedId(), true)
        messaggio("4", 1)
        messaggio("3", 1)
        messaggio("2", 1)
        messaggio("1", 1)
        messaggio("GO", 1)
        FreezeEntityPosition(PlayerPedId(), false)
        start(id, id2)
        InGame = true
        continua = true
    end
end)

local afk = 90

function start(id, id2)
    InGame = true
    roundtot = PVP.Round
    numerovittore = 0
    
    -- Verifica se è ESX o no
    if PVP.ESX then
        TriggerServerEvent("PVP_esx")
    else
        GiveWeaponToPed(PlayerPedId(), GetHashKey(PVP.Weapon), 999, false, true)
        SetCurrentPedWeapon(PlayerPedId(), GetHashKey(PVP.Weapon), true)
        SetPedAmmo(PlayerPedId(), GetHashKey(PVP.Weapon), 200)
    end
    
    afk = 90
    idavversario = id2
    
    Citizen.CreateThread(function()
        while InGame do
            local playerCoords = GetEntityCoords(PlayerPedId())
            local arenaCenter = (Game.uno.uno + Game.uno.due) / 2
            local distanza = #(playerCoords - arenaCenter)
            
            if distanza > 105 then
                InGame = false
                Notifica(PVP.Translate_Stopped)
                TriggerServerEvent("PVP:stop", id2)
                break
            end
            
            if PVP.Afk then
                if IsControlPressed(0, 32) or IsControlPressed(0, 33) or 
                   IsControlPressed(0, 34) or IsControlPressed(0, 35) or 
                   IsControlPressed(0, 22) then
                    afk = 90
                end
                
                afk = afk - 1
                if afk <= 0 then  
                    InGame = false
                    Notifica("Sei stato AFK troppo a lungo!")
                    TriggerServerEvent("PVP:stop", id2)
                    break
                end 
            end
            
            Citizen.Wait(500)
        end
    end)
end

RegisterCommand("leave", function()
    if InGame and #Avversario > 0 then
        TriggerServerEvent("PVP:stop", Avversario[1])
    else
        Notifica("Non sei in una partita")
    end
end)

RegisterNetEvent('PVP:stop')
AddEventHandler('PVP:stop', function()
    if InGame then
        InGame = false
        req = false
        for k,v in pairs(Game) do 
            SetEntityCoords(PlayerPedId(), v.start, false, false, false, true)
        end
        ClearPedTasks(PlayerPedId())
        ClearPedBloodDamage(PlayerPedId())
        Revive()
    end
end)

continua = true
Citizen.CreateThread(function()
    while true do 
        local asp = 500
        if InGame and continua then
            asp = 1
            if GetEntityHealth(PlayerPedId()) <= 0 then
                asp = 500
                TriggerServerEvent("PVP:addwin", idavversario)
            end
        end
        Citizen.Wait(asp)
    end
end)

RegisterNetEvent("PVP:claddwin")
AddEventHandler('PVP:claddwin', function()
    Revive()
    if roundtot ~= 1 then
        numerovittore = numerovittore + 1
        roundtot = roundtot - 1 
        Notifica("Hai vinto il round, numero vittore: ".. numerovittore.. "\nRound rimanenti: "..roundtot)
        Citizen.Wait(500)
        SetEntityCoords(PlayerPedId(), Game.uno.due)
    else
        numerovittore = numerovittore + 1
        continua = false
        ClearPedTasks(PlayerPedId())
        TriggerServerEvent('PVP_result', numerovittore, GetPlayerServerId(PlayerId()), idavversario)
        TriggerServerEvent("PVP:stop", idavversario)
    end
end)

RegisterNetEvent('PVP_restart')
AddEventHandler('PVP_restart', function()
    Revive()
    if roundtot ~= 1 then
        ClearPedTasks(PlayerPedId())
        roundtot = roundtot - 1 
        Citizen.Wait(500)
        Notifica("Hai perso il round, round rimanenti: "..roundtot)
        SetEntityCoords(PlayerPedId(), Game.uno.uno)
    else
        continua = false
        ClearPedTasks(PlayerPedId())
        TriggerServerEvent("PVP:stop", idavversario)
        ClearPedTasks(PlayerPedId())
    end
end)

function messaggio(title, sec)
    local scaleform = ESX.Scaleform.Utils.RequestScaleformMovie('COUNTDOWN')
    BeginScaleformMovieMethod(scaleform, 'FADE_MP')
    ScaleformMovieMethodAddParamTextureNameString(title)
    EndScaleformMovieMethod()
    while sec > 0 do
        Citizen.Wait(0)
        sec = sec - 0.01
        DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255)
    end
    SetScaleformMovieAsNoLongerNeeded(scaleform)
end

RegisterNetEvent("PVP_noty")
AddEventHandler("PVP_noty", function(msg)
    Notifica(msg)
end)