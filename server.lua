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
