-- client.lua for qb-policeaimissions

local QBCore = exports['qb-core']:GetCoreObject()

-- Make sure Config is loaded
if not Config then
    Config = {}
    Config.PedLocation = vector3(-1105.75, -826.99, 14.29)
    Config.PedHeading = 124.5
end

local targetPed = nil

local function SpawnAIPed()
    if targetPed and DoesEntityExist(targetPed) then return end

    RequestModel(`s_m_m_fiboffice_01`)
    while not HasModelLoaded(`s_m_m_fiboffice_01`) do Wait(0) end

    targetPed = CreatePed(0, `s_m_m_fiboffice_01`, Config.PedLocation.x, Config.PedLocation.y, Config.PedLocation.z - 1, Config.PedHeading, false, true)
    FreezeEntityPosition(targetPed, true)
    SetEntityInvincible(targetPed, true)
    SetBlockingOfNonTemporaryEvents(targetPed, true)

    exports['qb-target']:AddTargetEntity(targetPed, {
        options = {
            {
                type = "client",
                icon = "fas fa-user-secret",
                label = "Talk to Agent",
                action = function()
                    TriggerEvent("policeai:client:OpenMenu")
                end,
                job = {"police"}
            }
        },
        distance = 2.5
    })
end

RegisterNetEvent("policeai:client:SpawnAIPed", function()
    SpawnAIPed()
end)

CreateThread(function()
    SpawnAIPed()
end)

RegisterNetEvent("policeai:client:OpenMenu", function()
    local menu = {
        {
            header = "Police AI Missions",
            isMenuHeader = true
        },
        {
            header = "Start Mission",
            txt = "Begin an AI mission.",
            params = {
                event = "policeai:client:StartMission"
            }
        },
        {
            header = "Close",
            txt = "",
            params = {
                event = "qb-menu:client:closeMenu"
            }
        }
    }

    exports['qb-menu']:openMenu(menu)
end)

RegisterNetEvent("policeai:client:StartMission", function()
    QBCore.Functions.Notify("Mission started!", "success")
    TriggerEvent("policeai:client:SendFightDispatch")
    -- Insert AI fight logic here
end)

RegisterNetEvent("policeai:client:SendFightDispatch", function()
    exports['ps-dispatch']:CustomAlert({
        coords = GetEntityCoords(PlayerPedId()),
        message = "10-10 | Fight in Progress",
        dispatchCode = "10-10",
        description = "Suspects engaged in a fight",
        radius = 45,
        sprite = 650,
        color = 1,
        scale = 1.2,
        length = 6000,
        sound = true,
        caller = "Civilian",
        job = {"police", "leo"},
    })
end)
