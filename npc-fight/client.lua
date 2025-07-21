local QBCore = exports['qb-core']:GetCoreObject()

local spawnCoords = vector3(-825.62, -1164.09, 7.16)
local modelA = `g_m_y_famfor_01`
local modelB = `g_m_y_famdnf_01`

local function loadModel(model)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end
end

local function spawnFightingPeds()
    loadModel(modelA)
    loadModel(modelB)

    AddRelationshipGroup('FIGHTER_A')
    AddRelationshipGroup('FIGHTER_B')

    local pedA = CreatePed(4, modelA, spawnCoords.x + 1.0, spawnCoords.y, spawnCoords.z - 1.0, 0.0, false, true)
    local pedB = CreatePed(4, modelB, spawnCoords.x - 1.0, spawnCoords.y, spawnCoords.z - 1.0, 180.0, false, true)

    SetPedRelationshipGroupHash(pedA, `FIGHTER_A`)
    SetPedRelationshipGroupHash(pedB, `FIGHTER_B`)

    SetRelationshipBetweenGroups(5, `FIGHTER_A`, `FIGHTER_B`)
    SetRelationshipBetweenGroups(5, `FIGHTER_B`, `FIGHTER_A`)

    SetPedCombatAttributes(pedA, 46, true)
    SetPedCombatAttributes(pedB, 46, true)
    SetPedFleeAttributes(pedA, 0, false)
    SetPedFleeAttributes(pedB, 0, false)

    TaskCombatPed(pedA, pedB, 0, 16)
    TaskCombatPed(pedB, pedA, 0, 16)
end

CreateThread(function()
    spawnFightingPeds()
end)
