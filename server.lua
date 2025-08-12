local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent("streetfight:payOfficer", function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    amount = math.floor(tonumber(amount) or 0)

    if not Player or amount <= 0 then return end
    local job = Player.PlayerData.job
    if not job or (job.name ~= "police" and job.type ~= "leo") then return end

    -- pay into bank; change to "cash" if you prefer
    Player.Functions.AddMoney("cash", amount, "processed-suspects")

    -- feedback to the officer
    TriggerClientEvent('QBCore:Notify', src, ("Paid $%d for processing suspect(s)."):format(amount), "success")
end)
