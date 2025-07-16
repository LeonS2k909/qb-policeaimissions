-- Converted from ox_target to qb-target for qb-policeaimissions

local QBCore = exports['qb-core']:GetCoreObject()

local targetPed = nil

CreateThread(function()
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
    -- Mission logic goes here
    QBCore.Functions.Notify("Mission started!", "success")
end)
