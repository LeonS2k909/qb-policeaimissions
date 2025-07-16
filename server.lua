QBCore = exports['qb-core']:GetCoreObject()


RegisterNetEvent('copilot-ai:sendDispatch', function(coords)
    local src = source
    local data = {
        dispatchcodename = "streetfight",
        dispatchCode = "10-74",
        firstStreet = GetStreetNameAtCoord(coords.x, coords.y, coords.z),
        gender = "unknown",
        model = "Unknown Civilians",
        location = coords,
        priority = 2,
        job = {"police"},
        dispatchMessage = "Street fight in progress between suspects!",
        caller = "CCTV",
        evidence = { weapon = 'fist' },
    }

    TriggerEvent('ps-dispatch:server:sendCall', data)
end)

RegisterCommand("aiscene", function(source, args, rawCommand)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player and Player.PlayerData.job.name == "police" then
        TriggerClientEvent("policeai:client:SpawnAIPed", src)
    else
        TriggerClientEvent("QBCore:Notify", src, "You do not have permission to use this command.", "error")
    end
end, false)

