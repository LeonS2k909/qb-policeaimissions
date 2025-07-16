local allSuspects = {}

local pedModels = {
    'g_m_y_ballaorig_01',
    'g_m_y_mexgoon_02',
    'g_m_y_famdnf_01'
}

local spawnedPeds = {}
local surrenderedPeds = {}
local extractedVehicles = {}
local fightLocation = vec4(261.68, -871.16, 29.22, 45.59)
local jailLocation = vec4(441.21, -981.12, 30.69, 8.46)


function IsNearJail(coords)
    return #(vec3(coords.x, coords.y, coords.z) - vec3(jailLocation.x, jailLocation.y, jailLocation.z)) < 4.0
end

function GetStreetAndZone(coords)
    local streetName, crossingRoad = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    return string.format("%s %s", GetStreetNameFromHashKey(streetName), GetStreetNameFromHashKey(crossingRoad))
end

function MarkSuspectSurrendered(ped)
    surrenderedPeds[ped] = true
    FreezeEntityPosition(ped, true)
    ClearPedTasksImmediately(ped)
    TaskStartScenarioInPlace(ped, "WORLD_HUMAN_COP_IDLES", 0, true)
end
local function SpawnFightingPeds(location)
    AddRelationshipGroup("copilotFight")
    SetRelationshipBetweenGroups(5, `copilotFight`, `copilotFight`)
    SetRelationshipBetweenGroups(0, `copilotFight`, `PLAYER`)

    for i = 1, 2 do
        local model = GetHashKey(pedModels[math.random(#pedModels)])
        RequestModel(model)
        while not HasModelLoaded(model) do Wait(50) end

        local offset = vec3((i - 1) * 1.5, math.random(-2, 2), 0)
        local spawnPos = vec3(location.x + offset.x, location.y + offset.y, location.z)
        local ped = CreatePed(4, model, spawnPos.x, spawnPos.y, spawnPos.z, location.w, true, true)

        SetEntityAsMissionEntity(ped, true, true)
        SetPedRelationshipGroupHash(ped, `copilotFight`)
        GiveWeaponToPed(ped, `WEAPON_UNARMED`, 1, false, true)
        SetPedCombatAttributes(ped, 46, true)
        SetPedFleeAttributes(ped, 0, 0)
        SetPedCombatRange(ped, 2)
        SetPedCombatMovement(ped, 3)
        SetPedCanRagdoll(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, false)

        spawnedPeds[i] = ped
        table.insert(allSuspects, ped)


        exports.ox_target:addLocalEntity(ped, {
            {
                label = 'Cuff Suspect',
                icon = 'fas fa-handcuffs',
                canInteract = function(entity)
                    return surrenderedPeds[entity]
                end,
                onSelect = function(data)
                    MarkSuspectSurrendered(data.entity)
                end
            },
            {
                label = 'Escort Suspect',
                icon = 'fas fa-person-walking',
                canInteract = function(entity)
                    return surrenderedPeds[entity]
                end,
                onSelect = function(data)
                    local suspect = data.entity
                    AttachEntityToEntity(
                        suspect,
                        PlayerPedId(),
                        0,
                        -0.45, 0.15, 0.0,
                        0.0, 0.0, 180.0,
                        true, true, false, true, 2, true
                    )
                    lib.notify({
                        title = 'Suspect Escorted',
                        description = 'You are now escorting the suspect.',
                        type = 'inform'
                    })
                end
            },
            {
                label = 'Place in Back of Vehicle',
                icon = 'fas fa-car-side',
                canInteract = function(entity)
                    return surrenderedPeds[entity]
                end,
                onSelect = function(data)
                    local suspect = data.entity
                    local ped = PlayerPedId()
                    local pedCoords = vec3(GetEntityCoords(ped).x, GetEntityCoords(ped).y, GetEntityCoords(ped).z)
                    local vehicle = GetVehiclePedIsIn(ped, false)

                    if vehicle == 0 then
                        local vehicles = GetGamePool("CVehicle")
                        for _, v in pairs(vehicles) do
                            local vCoords = GetEntityCoords(v)
                            if #(vec3(vCoords.x, vCoords.y, vCoords.z) - pedCoords) < 6.0 then
                                vehicle = v
                                break
                            end
                        end
                    end

                    if DoesEntityExist(vehicle) and IsVehicleDriveable(vehicle, false) then
                        local vehCoords = GetEntityCoords(vehicle)
                        TaskGoToCoordAnyMeans(suspect, vehCoords.x, vehCoords.y, vehCoords.z, 2.0, 0, 0, 786603, 0xbf800000)

                        CreateThread(function()
                            local timeout = 5000
                            while timeout > 0 do
                                Wait(200)
                                local dist = #(vec3(GetEntityCoords(suspect).x, GetEntityCoords(suspect).y, GetEntityCoords(suspect).z) -
                                               vec3(vehCoords.x, vehCoords.y, vehCoords.z))
                                if dist <= 3.0 then break end
                                timeout -= 200
                            end

                            if IsVehicleSeatFree(vehicle, 2) then
                                TaskWarpPedIntoVehicle(suspect, vehicle, 2)
                            elseif IsVehicleSeatFree(vehicle, 1) then
                                TaskWarpPedIntoVehicle(suspect, vehicle, 1)
                            else
                                lib.notify({ title = 'Back Seats Full', type = 'error' })
                            end
                        end)
                    else
                        lib.notify({ title = 'No Vehicle Found', type = 'error' })
                    end
                end
            },
            {
                label = 'Jail Suspect',
                icon = 'fas fa-user-slash',
                canInteract = function(entity)
                    local pos = GetEntityCoords(entity)
                    return IsNearJail(pos)
                end,
                onSelect = function(data)
                    DeleteEntity(data.entity)
                    lib.notify({
                        title = 'Suspect Jailed',
                        description = 'Removed from the street.',
                        type = 'success'
                    })
                end
            }
        })
    end

    TaskCombatPed(spawnedPeds[1], spawnedPeds[2], 0, 16)
    TaskCombatPed(spawnedPeds[2], spawnedPeds[1], 0, 16)

    local dispatchData = {
        message = 'Street Fight in Progress',
        code = '10-32',
        codeName = 'fight',
        icon = 'fas fa-users',
        priority = 1,
        coords = vec3(location.x, location.y, location.z),
        street = GetStreetAndZone(location),
        heading = location.w,
        jobs = { 'leo' }
    }
    TriggerServerEvent('ps-dispatch:server:notify', dispatchData)
end
CreateThread(function()
    while true do
        Wait(600000)
        SpawnFightingPeds(fightLocation)
    end
end)

CreateThread(function()
    while true do
        Wait(200)
        if #spawnedPeds == 0 then goto continue end

        local player = PlayerPedId()
        local aiming, target = GetEntityPlayerIsFreeAimingAt(PlayerId())

        if aiming and DoesEntityExist(target) and not IsPedAPlayer(target) then
            for _, suspect in pairs(spawnedPeds) do
                if target == suspect and not IsEntityDead(suspect) and not surrenderedPeds[suspect] then
                    local playerCoords = vec3(GetEntityCoords(player).x, GetEntityCoords(player).y, GetEntityCoords(player).z)
                    local suspectCoords = vec3(GetEntityCoords(suspect).x, GetEntityCoords(suspect).y, GetEntityCoords(suspect).z)
                    local dist = #(playerCoords - suspectCoords)
                    if dist <= 15.0 and IsPedArmed(player, 4) then
                        ClearPedTasksImmediately(suspect)
                        TaskHandsUp(suspect, 5000, player, -1, true)
                        SetPedFleeAttributes(suspect, 0, 0)
                        SetBlockingOfNonTemporaryEvents(suspect, true)
                        SetPedCombatAttributes(suspect, 0, false)
                        SetPedSeeingRange(suspect, 0.0)
                        SetPedAlertness(suspect, 0)
                        SetPedKeepTask(suspect, true)
                        surrenderedPeds[suspect] = true
                        lib.notify({
                            title = 'Suspect Surrendered',
                            description = 'Hands are up and suspect has complied.',
                            type = 'inform'
                        })
                        break
                    end
                end
            end
        end
        ::continue::
    end
end)

RegisterCommand('release', function()
    local player = PlayerPedId()
    local nearbyPeds = GetGamePool("CPed")
    for _, ped in pairs(nearbyPeds) do
        if IsEntityAttachedToEntity(ped, player) then
            DetachEntity(ped, true, false)
            ClearPedTasksImmediately(ped)
            FreezeEntityPosition(ped, false)
            TaskStandStill(ped, 2000)
            lib.notify({
                title = 'Suspect Released',
                description = 'Suspect detached from officer.',
                type = 'inform'
            })
        end
    end
end)
CreateThread(function()
    while true do
        Wait(5000)
        local vehicles = GetGamePool('CVehicle')
        for _, vehicle in pairs(vehicles) do
            local vCoords = GetEntityCoords(vehicle)

            if #(vCoords - fightLocation.xyz) < 20.0 then
                local hasSuspectInside = false

                for _, suspect in pairs(allSuspects) do
                    if DoesEntityExist(suspect) and IsPedInVehicle(suspect, vehicle, false) then
                        hasSuspectInside = true
                        break
                    end
                end

                if hasSuspectInside then
                    exports.ox_target:removeLocalEntity(vehicle) -- 🧼 Prevent stacking

                    exports.ox_target:addLocalEntity(vehicle, {
                        {
                            label = 'Extract Suspect',
                            icon = 'fas fa-door-open',
                            canInteract = function(entity)
                                for _, suspect in pairs(allSuspects) do
                                    if DoesEntityExist(suspect) and IsPedInVehicle(suspect, entity, false) then
                                        return true
                                    end
                                end
                                return false
                            end,
                            onSelect = function(data)
                                local selectedVehicle = data.entity
                                for _, suspect in pairs(allSuspects) do
                                    if DoesEntityExist(suspect) and IsPedInVehicle(suspect, selectedVehicle, false) then
                                        TaskLeaveVehicle(suspect, selectedVehicle, 16)
                                        Wait(1000)
                                        ClearPedTasksImmediately(suspect)
                                        FreezeEntityPosition(suspect, true)
                                        TaskStandStill(suspect, 2000)
                                        lib.notify({
                                            title = 'Suspect Extracted',
                                            description = 'Removed from the vehicle.',
                                            type = 'inform'
                                        })
                                        break
                                    end
                                end
                            end
                        }
                    })
                end
            end
        end
    end
end)

RegisterCommand("aiscene", function()
    local coords = GetEntityCoords(PlayerPedId())
    local heading = GetEntityHeading(PlayerPedId())
    SpawnFightingPeds(vec4(coords.x, coords.y, coords.z, heading))
end, false)

CreateThread(function()
    while true do
        Wait(30000) -- every 30 seconds
        for i = #allSuspects, 1, -1 do
            local ped = allSuspects[i]
            if not DoesEntityExist(ped) or IsEntityDead(ped) then
                table.remove(allSuspects, i)
                surrenderedPeds[ped] = nil
            end
        end
    end
end)