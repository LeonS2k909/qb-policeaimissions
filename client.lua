local QBCore = exports['qb-core']:GetCoreObject()

-- ======= CONFIG =======
local SCENE_POS = vector3(83.29, -1670.46, 29.07)
local PED_MODELS = { `g_m_y_famdnf_01`, `g_m_y_ballaeast_01` }
local SPAWN_RADIUS = 2.0
local JAIL_POS = vector3(441.13, -981.13, 30.69)
local JAIL_RADIUS = 3.0
local FIGHT_INTERVAL_MS = 5 * 60 * 1000

-- ======= STATE =======
local FIGHT_STARTED = false
local suspects = {}           -- [ped] = { surrendered=false, following=false, targetId=nil }
local reservedSeats = {}      -- reservedSeats[veh][seat] = true

-- ======= UTILS =======
local function loadModel(hash)
    if not IsModelValid(hash) then return false end
    if not HasModelLoaded(hash) then
        RequestModel(hash)
        local t = GetGameTimer()
        while not HasModelLoaded(hash) do
            Wait(10)
            if GetGameTimer() - t > 10000 then return false end
        end
    end
    return true
end

local function isPolice()
    local pdata = QBCore.Functions.GetPlayerData()
    if not pdata or not pdata.job then return false end
    local job = pdata.job
    if job.type and job.type == "leo" then return true end
    return job.name == "police"
end

local function setPedBasics(ped)
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)
    SetPedCanRagdoll(ped, true)
    SetPedDropsWeaponsWhenDead(ped, false)
    RemoveAllPedWeapons(ped, true)
    SetPedRelationshipGroupHash(ped, `FIGHTERS`)
end

local function handsUp(ped, holder)
    if not DoesEntityExist(ped) then return end
    ClearPedTasksImmediately(ped)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskHandsUp(ped, -1, holder or 0, -1, true)
    if suspects[ped] then suspects[ped].surrendered = true end
end

local function startFollow(ped, playerPed)
    if not DoesEntityExist(ped) then return end
    ClearPedTasks(ped)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskFollowToOffsetOfEntity(ped, playerPed, 0.0, -1.5, 0.0, 2.0, -1, 2.0, true)
    if suspects[ped] then
        suspects[ped].following = true
        suspects[ped].targetId = NetworkGetPlayerIndexFromPed(playerPed)
        suspects[ped].surrendered = true
    end
end

local function stopFollow(ped)
    if not DoesEntityExist(ped) then return end
    ClearPedTasks(ped)
    TaskStandStill(ped, -1)
    if suspects[ped] then
        suspects[ped].following = false
        suspects[ped].targetId = nil
    end
end

local function anyFollowingSuspectForPlayer(playerPed)
    local idx = NetworkGetPlayerIndexFromPed(playerPed)
    for ped, st in pairs(suspects) do
        if st.following and st.targetId == idx and DoesEntityExist(ped) then
            return ped
        end
    end
    return nil
end

local function suspectsCount()
    local c = 0
    for ped,_ in pairs(suspects) do
        if DoesEntityExist(ped) and not IsEntityDead(ped) then c = c + 1 end
    end
    return c
end

local function activePlayersCount()
    return #GetActivePlayers()
end

-- ======= SEAT RESERVATION =======
local function ensureVehTable(veh)
    if reservedSeats[veh] == nil then reservedSeats[veh] = {} end
end

local function seatFreeAndUnreserved(veh, seat)
    ensureVehTable(veh)
    return IsVehicleSeatFree(veh, seat) and not reservedSeats[veh][seat]
end

local function reserveSeat(veh, seat)
    ensureVehTable(veh)
    if seatFreeAndUnreserved(veh, seat) then
        reservedSeats[veh][seat] = true
        return true
    end
    return false
end

local function releaseSeat(veh, seat)
    if reservedSeats[veh] then reservedSeats[veh][seat] = nil end
end

local function seatPedRear(ped, veh)
    if not DoesEntityExist(ped) or not DoesEntityExist(veh) then return false end
    local candidates = {1, 2}
    local chosen = nil
    for _, s in ipairs(candidates) do
        if reserveSeat(veh, s) then chosen = s break end
    end
    if not chosen then
        for s = -1, 6 do
            if seatFreeAndUnreserved(veh, s) and reserveSeat(veh, s) then
                chosen = s
                break
            end
        end
    end
    if not chosen then return false end

    ClearPedTasks(ped)
    TaskEnterVehicle(ped, veh, 5000, chosen, 1.0, 1, 0)

    CreateThread(function()
        local t0 = GetGameTimer()
        while GetGameTimer() - t0 < 8000 do
            Wait(250)
            if IsPedInVehicle(ped, veh, false) then
                local actual = -2
                for s = -1, 6 do
                    if GetPedInVehicleSeat(veh, s) == ped then actual = s break end
                end
                if actual ~= chosen then releaseSeat(veh, chosen) end
                return
            end
        end
        releaseSeat(veh, chosen)
    end)
    return true
end

local function extractRearSuspects(veh, maxCount)
    if not DoesEntityExist(veh) then return 0 end
    local playerPed = PlayerPedId()
    local out = 0
    for _, seat in ipairs({1, 2}) do
        if maxCount > 0 then
            local ped = GetPedInVehicleSeat(veh, seat)
            if ped ~= 0 and DoesEntityExist(ped) and suspects[ped] then
                TaskLeaveVehicle(ped, veh, 0)
                releaseSeat(veh, seat)
                CreateThread(function()
                    local t0 = GetGameTimer()
                    while GetGameTimer() - t0 < 4000 and IsPedInVehicle(ped, veh, false) do
                        Wait(100)
                    end
                    if DoesEntityExist(ped) then
                        startFollow(ped, playerPed)
                        QBCore.Functions.Notify(("Suspect from rear seat %d extracted."):format(seat), "success")
                    end
                end)
                out = out + 1
                maxCount = maxCount - 1
            end
        end
    end
    return out
end

-- ======= qb-target: SUSPECT MENU =======
local function addTargetForSuspect(ped)
    exports['qb-target']:AddTargetEntity(ped, {
        options = {
            {
                icon = "fa-solid fa-person-walking",
                label = "Follow me",
                canInteract = function(ent)
                    return suspects[ent] and suspects[ent].surrendered and not suspects[ent].following and isPolice()
                end,
                action = function(ent)
                    startFollow(ent, PlayerPedId())
                    QBCore.Functions.Notify("Suspect is following.", "success")
                end
            },
            {
                icon = "fa-solid fa-hand",
                label = "Stop following",
                canInteract = function(ent)
                    return suspects[ent] and suspects[ent].following and isPolice()
                end,
                action = function(ent)
                    stopFollow(ent)
                    QBCore.Functions.Notify("Suspect stopped.", "primary")
                end
            }
        },
        distance = 2.5
    })
end

-- ======= SPAWN & FIGHT =======
local function sendPSDispatchAtCoords(pos)
    -- Force ps-dispatch to blip at scene using CustomAlert
    exports["ps-dispatch"]:CustomAlert({
        coords = vector3(pos.x, pos.y, pos.z),
        dispatchCode = "10-10",
        message = "Fight in progress",
        description = "Disturbance reported",
        radius = 35.0,
        sprite = 64,
        color = 1,
        scale = 1.2,
        length = 120,
        recipientList = { "police" }
    })
end

local function spawnFighters()
    if FIGHT_STARTED then return end

    AddRelationshipGroup("FIGHTERS")
    local peds = {}

    for i=1,2 do
        local mdl = PED_MODELS[i]
        if loadModel(mdl) then
            local offset = GetRandomFloatInRange(-SPAWN_RADIUS, SPAWN_RADIUS)
            local x = SCENE_POS.x + offset
            local y = SCENE_POS.y - offset
            local z = SCENE_POS.z
            local ped = CreatePed(4, mdl, x, y, z, 0.0, true, true)
            setPedBasics(ped)
            suspects[ped] = { surrendered=false, following=false, targetId=nil }
            addTargetForSuspect(ped)
            SetModelAsNoLongerNeeded(mdl)
            peds[#peds+1] = ped
        end
    end

    if #peds == 2 then
        SetRelationshipBetweenGroups(5, `FIGHTERS`, `FIGHTERS`)
        TaskCombatPed(peds[1], peds[2], 0, 16)
        TaskCombatPed(peds[2], peds[1], 0, 16)
        FIGHT_STARTED = true
        sendPSDispatchAtCoords(SCENE_POS)
    end
end

local function canSpawnFight()
    if FIGHT_STARTED then return false end
    if activePlayersCount() >= 10 then return false end
    return true
end

-- initial and periodic spawn
CreateThread(function()
    Wait(5000)
    if canSpawnFight() then spawnFighters() end
    while true do
        Wait(FIGHT_INTERVAL_MS)
        if canSpawnFight() then spawnFighters() end
    end
end)

-- ======= SURRENDER WHEN POLICE AIMS =======
CreateThread(function()
    while true do
        Wait(100)
        if FIGHT_STARTED and isPolice() then
            local player = PlayerPedId()
            if IsPlayerFreeAiming(PlayerId()) then
                local _, entity = GetEntityPlayerIsFreeAimingAt(PlayerId())
                if entity and DoesEntityExist(entity) and suspects[entity] and not suspects[entity].surrendered then
                    local weap = GetSelectedPedWeapon(player)
                    local isGun = IsPedArmed(player, 4) or IsPedArmed(player, 6)
                    local isTaser = (weap == `WEAPON_STUNGUN` or weap == `WEAPON_STUNGUN_MP`)
                    if isGun or isTaser then
                        handsUp(entity, player)
                    end
                end
            end
        end
    end
end)

-- ======= qb-target: POLICE VEHICLES =======
exports['qb-target']:AddGlobalVehicle({
    options = {
        {
            icon = "fa-solid fa-car-side",
            label = "Seat suspect in rear",
            canInteract = function(veh)
                if not isPolice() then return false end
                if GetVehicleClass(veh) ~= 18 then return false end
                local ped = anyFollowingSuspectForPlayer(PlayerPedId())
                if not ped then return false end
                return seatFreeAndUnreserved(veh, 1) or seatFreeAndUnreserved(veh, 2)
            end,
            action = function(veh)
                local ped = anyFollowingSuspectForPlayer(PlayerPedId())
                if not ped then
                    QBCore.Functions.Notify("No suspect following you.", "error")
                    return
                end
                if seatPedRear(ped, veh) then
                    suspects[ped].following = false
                    suspects[ped].targetId = nil
                    QBCore.Functions.Notify("Suspect placed in vehicle.", "success")
                else
                    QBCore.Functions.Notify("Rear seats occupied.", "error")
                end
            end
        },
        {
            icon = "fa-solid fa-person-running",
            label = "Extract one rear suspect",
            canInteract = function(veh)
                if not isPolice() then return false end
                if GetVehicleClass(veh) ~= 18 then return false end
                for _, s in ipairs({1,2}) do
                    local ped = GetPedInVehicleSeat(veh, s)
                    if ped ~= 0 and DoesEntityExist(ped) and suspects[ped] then return true end
                end
                return false
            end,
            action = function(veh)
                local n = extractRearSuspects(veh, 1)
                if n == 0 then QBCore.Functions.Notify("No suspects to extract.", "error") end
            end
        },
        {
            icon = "fa-solid fa-people-arrows",
            label = "Extract both rear suspects",
            canInteract = function(veh)
                if not isPolice() then return false end
                if GetVehicleClass(veh) ~= 18 then return false end
                local c = 0
                for _, s in ipairs({1,2}) do
                    local ped = GetPedInVehicleSeat(veh, s)
                    if ped ~= 0 and DoesEntityExist(ped) and suspects[ped] then c = c + 1 end
                end
                return c > 0
            end,
            action = function(veh)
                local n = extractRearSuspects(veh, 2)
                if n == 0 then QBCore.Functions.Notify("No suspects to extract.", "error") end
            end
        }
    },
    distance = 2.5
})

-- ======= JAIL DELETE ZONE (E) =======
CreateThread(function()
    local showing = false
    while true do
        Wait(0)
        local me = PlayerPedId()
        local pos = GetEntityCoords(me)
        local dist = #(pos - JAIL_POS)
        if dist <= 25.0 then
            DrawMarker(1, JAIL_POS.x, JAIL_POS.y, JAIL_POS.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5, 1.5, 0.8, 255, 255, 255, 120, false, true, 2, nil, nil, false)
        end
        if dist <= JAIL_RADIUS and isPolice() then
            if not showing then
                showing = true
                BeginTextCommandDisplayHelp("STRING")
                AddTextComponentSubstringPlayerName("Press ~INPUT_CONTEXT~ to process suspects.")
                EndTextCommandDisplayHelp(0, false, true, -1)
            end
            if IsControlJustPressed(0, 38) then
                local removed = 0
                for ped,_ in pairs(suspects) do
                    if DoesEntityExist(ped) then
                        local ppos = GetEntityCoords(ped)
                        if #(ppos - JAIL_POS) <= 6.0 then
                            DeleteEntity(ped)
                            suspects[ped] = nil
                            removed = removed + 1
                        end
                    else
                        suspects[ped] = nil
                    end
                end
                if removed > 0 then
                    -- Pay $1000 per processed suspect
                    TriggerServerEvent("streetfight:payOfficer", removed * 1000)
                end
                QBCore.Functions.Notify(("Processed %d suspect(s)."):format(removed), removed > 0 and "success" or "error")
            end
        else
            showing = false
        end
    end
end)


-- ======= CLEANUP + FIGHT RESET =======
CreateThread(function()
    while true do
        Wait(2000)
        for ped,_ in pairs(suspects) do
            if not DoesEntityExist(ped) or IsEntityDead(ped) then
                suspects[ped] = nil
            end
        end
        if FIGHT_STARTED and suspectsCount() == 0 then
            FIGHT_STARTED = false
        end
        for veh, seats in pairs(reservedSeats) do
            local any = false
            for _, v in pairs(seats) do if v then any = true break end end
            if not any then reservedSeats[veh] = nil end
        end
    end
end)
