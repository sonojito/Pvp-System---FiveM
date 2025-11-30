-- Sistema di classifica
MySQL.ready(function()
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `pvp_leaderboard` (
            `identifier` VARCHAR(60) NOT NULL,
            `name` VARCHAR(100) NOT NULL,
            `kills` INT(11) NOT NULL DEFAULT 0,
            `wins` INT(11) NOT NULL DEFAULT 0,
            PRIMARY KEY (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {}, function()
        print('[PVP] Tabella leaderboard creata')
    end)
end)

local leaderboardData = {}

function UpdatePlayerStats(playerId, kills, win)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return end

    MySQL.Async.fetchScalar('SELECT 1 FROM pvp_leaderboard WHERE identifier = @id', 
    {['@id'] = xPlayer.identifier}, 
    function(exists)
        local query
        if exists then
            query = [[
                UPDATE pvp_leaderboard 
                SET kills = kills + @kills, wins = wins + @wins, name = @name
                WHERE identifier = @identifier
            ]]
        else
            query = [[
                INSERT INTO pvp_leaderboard (identifier, name, kills, wins)
                VALUES (@identifier, @name, @kills, @wins)
            ]]
        end

        MySQL.Async.execute(query, {
            ['@identifier'] = xPlayer.identifier,
            ['@name'] = xPlayer.getName(),
            ['@kills'] = kills,
            ['@wins'] = win
        }, function()
            LoadLeaderboard()
        end)
    end)
end

function LoadLeaderboard()
    MySQL.Async.fetchAll('SELECT * FROM pvp_leaderboard ORDER BY wins DESC, kills DESC LIMIT 10', {}, 
    function(results)
        leaderboardData = results
        TriggerClientEvent('PVP:updateLeaderboard', -1, leaderboardData)
    end)
end

RegisterNetEvent('PVP:requestLeaderboard')
AddEventHandler('PVP:requestLeaderboard', function()
    local src = source
    TriggerClientEvent('PVP:updateLeaderboard', src, leaderboardData)
end)

if PVP.ESX then
    ESX = exports.es_extended:getSharedObject()
end

InCerca = {} 
local InAttesa = false
local Match = 0

-- Gestione coda matchmaking
RegisterNetEvent('PVP:1v1')
AddEventHandler('PVP:1v1', function()
    if not InAttesa then
        InAttesa = true
        InCerca = {source}
        TriggerClientEvent("PVP_noty", source, PVP.Translate_Coda)
    else
        table.insert(InCerca, source)
        if #InCerca >= 2 then
            local player1 = InCerca[1]
            local player2 = InCerca[2]
            TriggerClientEvent('PVP:1v1confermato', player1, player1, player2, player2)  
            TriggerClientEvent('PVP:1v1confermato', player2, player2, player1, player1)   
            InAttesa = false
            Match = Match + 1
            SetPlayerRoutingBucket(player1, Match)
            SetPlayerRoutingBucket(player2, Match)
            TriggerClientEvent("PVP_noty", player1, PVP.Translate_EnterMatch..Match.."\n"..GetPlayerName(player2))
            TriggerClientEvent('PVP_noty', player2, PVP.Translate_EnterMatch..Match.."\n"..GetPlayerName(player1))  
            if PVPlogs.Weebhooks ~= "" then
                PVPlog("**Game Started** \n <@"..string.gsub(GetPlayerIdentifier(player1, 3), "discord:", "").."> VS <@"..string.gsub(GetPlayerIdentifier(player2, 3), "discord:", "").."> ", PVPlogs.Weebhooks)
            end
            InCerca = {}
        end
    end 
end)

-- Gestione disconnessione giocatori in coda
AddEventHandler('playerDropped', function(reason)
    local source = source
    if InAttesa then
        for i = #InCerca, 1, -1 do
            if InCerca[i] == source then
                table.remove(InCerca, i)
            end
        end
        if #InCerca == 0 then
            InAttesa = false
        end
    end
end)

RegisterNetEvent('PVP:stop')
AddEventHandler('PVP:stop', function(id2)
    SetPlayerRoutingBucket(source, 0)
    SetPlayerRoutingBucket(id2, 0)
    TriggerClientEvent("PVP:stop", source)
    TriggerClientEvent("PVP:stop", id2)
    if PVP.ESX then
        local uno = ESX.GetPlayerFromId(source)
        local due = ESX.GetPlayerFromId(id2)
        uno.removeInventoryItem(PVP.Weapon, 1)
        due.removeInventoryItem(PVP.Weapon, 1)
        local unoammo = uno.getInventoryItem(PVP.Ammo).count
        if unoammo > 0 then
            uno.removeInventoryItem(PVP.Ammo, unoammo)
        end
        local dueammo = due.getInventoryItem(PVP.Ammo).count
        if dueammo > 0 then
            due.removeInventoryItem(PVP.Ammo, dueammo)
        end
    end
end)

RegisterNetEvent('PVP:addwin')
AddEventHandler('PVP:addwin', function(idavversario)
    TriggerClientEvent("PVP_restart", source)
    TriggerClientEvent("PVP:claddwin", idavversario)
end)

PVPlog = function(Descrizione,Webhook)
    if Webhook ~= "" then
        PerformHttpRequest(Webhook, function()
        end, "POST", json.encode({
            embeds = {{
                author = {
                    name = PVPlogs.Name,
                    url = "",
                    icon_url = PVPlogs.Img},
                title = PVPlogs.Title,
                description = Descrizione,
                color = PVPlogs.Color
            }}}),{["Content-Type"] = "application/json"})
    end
end

RegisterNetEvent('PVP_result')
AddEventHandler('PVP_result', function(r, idown, idavv)
    if PVPlogs.Weebhooks ~= "" then
        if r == PVP.Round - r then
            PVPlog('Match finito: **Pareggio !** \n\nRisultati: \n<@'.. string.gsub(GetPlayerIdentifier(idown, 3), "discord:", "") ..'>: '..r..'\n<@'..string.gsub(GetPlayerIdentifier(idavv, 3), "discord:", "")..'> '.. PVP.Round - r, PVPlogs.Weebhooks)
        else
            PVPlog('Match finito: \n**<@'.. string.gsub(GetPlayerIdentifier(idown, 3), "discord:", "") ..'> Ha vinto !** \n\nRisultati: \n<@'.. string.gsub(GetPlayerIdentifier(idown, 3), "discord:", "") ..'>: '..r..'\n<@'..string.gsub(GetPlayerIdentifier(idavv, 3), "discord:", "")..'> '.. PVP.Round - r, PVPlogs.Weebhooks)
        end
    end
    
    -- Aggiorna statistiche
    local totalRounds = PVP.Round
    local player1Wins = r
    local player2Wins = totalRounds - r
    local player1MatchWin = player1Wins > player2Wins and 1 or 0
    local player2MatchWin = player2Wins > player1Wins and 1 or 0

    UpdatePlayerStats(idown, player1Wins, player1MatchWin)
    UpdatePlayerStats(idavv, player2Wins, player2MatchWin)
end)    
  
RegisterNetEvent('PVP_esx')
AddEventHandler('PVP_esx', function()
    local xPlayer = ESX.GetPlayerFromId(source)
    local modder = true
    for k,v in pairs(InCerca) do
        if source == v then
            modder = false
        end
    end
    if modder then
        if PVPlogs.Weebhooks ~= "" then
            PVPlog('**MODDER** ha provato a givvarsi un arma, il player è stato disconnesso automaticamente dal server\n<@'.. string.gsub(GetPlayerIdentifier(source, 3), "discord:", "") ..'>' , PVPlogs.Weebhooks)
        end
        DropPlayer(source, "Sei Un Modder")
    else
        -- Aggiunge arma e munizioni
        xPlayer.addInventoryItem(PVP.Weapon, 1)
        xPlayer.addInventoryItem(PVP.Ammo, 200)
        
        -- Notifica al client
        TriggerClientEvent('esx:showNotification', source, "Hai ricevuto: "..ESX.GetWeaponLabel(PVP.Weapon).." con 200 colpi")
    end
end)

-- Carica classifica all'avvio
Citizen.CreateThread(function()
    Wait(5000)
    LoadLeaderboard()
end)