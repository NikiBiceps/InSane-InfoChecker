ESX = exports["es_extended"]:getSharedObject()

local allowedGroups = {
    admin = true,
    superadmin = true,
    owner = true
}

local function isAllowed(xPlayer)
    if not xPlayer then return false end
    return allowedGroups[xPlayer.getGroup()] == true
end

local function formatMoney(amount)
    return "$" .. tostring(amount):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function getSafeIdentifier(identifier)
    if not identifier then return "Unknown" end
    
    local safeIdentifiers = {}
    for id in string.gmatch(identifier, "[^, ]+") do
        if string.sub(id, 1, 3) ~= "ip:" then
            table.insert(safeIdentifiers, id)
        end
    end

    return #safeIdentifiers > 0 and table.concat(safeIdentifiers, "\n") or "Unknown"
end

local function buildOnlinePlayerInfo(targetId)
    local targetXPlayer = ESX.GetPlayerFromId(targetId)
    if not targetXPlayer then return nil end

    local identifiers = GetPlayerIdentifiers(targetId)
    local safeIdentifierList = getSafeIdentifier(table.concat(identifiers, " "))

    local playerName = GetPlayerName(targetId) or "Unknown"
    local identityName = targetXPlayer.getName and targetXPlayer.getName() or "N/A"
    local cash = formatMoney(targetXPlayer.getMoney() or 0)
    local bank = formatMoney(targetXPlayer.getAccount("bank") and targetXPlayer.getAccount("bank").money or 0)

    local job = targetXPlayer.job and targetXPlayer.job.label or "N/A"
    local grade = targetXPlayer.job and targetXPlayer.job.grade_label or "N/A"

    local msg = "[Player Info]\n"
    msg = msg .. "━━━━━━━━━━━━━━━\n"
    msg = msg .. "🔹 Server ID: " .. targetId .. "\n"
    msg = msg .. "🔹 In-game Name: " .. playerName .. "\n"
    msg = msg .. "🔹 Identity: " .. identityName .. "\n"
    msg = msg .. "━━━━━━━━━━━━━━━\n"
    msg = msg .. "💵 Cash: " .. cash .. "\n"
    msg = msg .. "🏦 Bank: " .. bank .. "\n"
    msg = msg .. "━━━━━━━━━━━━━━━\n"
    msg = msg .. "⚒️ Job: " .. job .. " | " .. grade .. "\n"
    msg = msg .. "━━━━━━━━━━━━━━━\n"
    msg = msg .. "🆔 Identifiers:\n" .. safeIdentifierList

    return msg
end

local function buildOfflinePlayerInfo(user, jobLabel, gradeLabel)
    if not user then return nil end

    local safeIdentifier = getSafeIdentifier(user.identifier)
    local accounts = json.decode(user.accounts or "{}") or {}
    local cash = formatMoney(accounts.money or 0)
    local bank = formatMoney(accounts.bank or 0)
    local black = formatMoney(accounts.black_money or 0)

    local msg = "[Offline Player Info]\n"
    msg = msg .. "━━━━━━━━━━━━━━━\n"
    msg = msg .. "🆔 Identifier: " .. safeIdentifier .. "\n"
    msg = msg .. "👤 Identity: " .. (user.firstname or "N/A") .. " " .. (user.lastname or "") .. "\n"
    msg = msg .. "━━━━━━━━━━━━━━━\n"
    msg = msg .. "💵 Cash: " .. cash .. "\n"
    msg = msg .. "🏦 Bank: " .. bank .. "\n"
    msg = msg .. "💀 Black Money: " .. black .. "\n"
    msg = msg .. "━━━━━━━━━━━━━━━\n"
    msg = msg .. "⚒️ Job: " .. (jobLabel or user.job or "N/A") .. " | " ..
              (gradeLabel or tostring(user.job_grade) or "N/A") .. "\n"

    return msg
end

RegisterCommand("requestinfo", function(source, args)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not isAllowed(xPlayer) then
        TriggerClientEvent('brutal_notify:SendAlert', source, 'SYSTEM', 'You dont have permission', 5000, 'error', true)
        return
    end

    local targetId = tonumber(args[1])
    if not targetId or not GetPlayerName(targetId) then
        TriggerClientEvent('brutal_notify:SendAlert', source, 'SYSTEM', 'Usage: /requestinfo [playerID]', 5000, 'error', true)
        return
    end

    local msg = buildOnlinePlayerInfo(targetId)
    if msg then
        TriggerClientEvent('chat:addMessage', source, {
            color = {0, 153, 204},
            multiline = true,
            args = {'[Requested]', msg}
        })
    else
        TriggerClientEvent('brutal_notify:SendAlert', source, 'SYSTEM', 'Player not found', 5000, 'error', true)
    end
end, false)

RegisterCommand("locateinfo", function(source, args)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not isAllowed(xPlayer) then
        TriggerClientEvent('brutal_notify:SendAlert', source, 'SYSTEM', 'You dont have permission', 5000, 'error', true)
        return
    end

    local search = table.concat(args, " ")
    if search == "" then
        TriggerClientEvent('brutal_notify:SendAlert', source, 'SYSTEM', 'Usage: /locateinfo [name]', 5000, 'error', true)
        return
    end

    local searchLower = string.lower(search)
    local found = false

    for _, playerId in ipairs(GetPlayers()) do
        local targetId = tonumber(playerId)
        local targetXPlayer = ESX.GetPlayerFromId(targetId)

        if targetXPlayer then
            local playerName = GetPlayerName(targetId) or ""
            local identityName = targetXPlayer.getName and targetXPlayer.getName() or ""

            if string.find(string.lower(playerName), searchLower, 1, true) or
               string.find(string.lower(identityName), searchLower, 1, true) then

                local msg = buildOnlinePlayerInfo(targetId)
                TriggerClientEvent('chat:addMessage', source, {
                    color = {0, 153, 204},
                    multiline = true,
                    args = {'[Requested]', msg}
                })

                found = true
            end
        end
    end

    if found then return end

    exports.oxmysql:fetch(
        "SELECT identifier, firstname, lastname, accounts, job, job_grade FROM users WHERE " ..
        "LOWER(CONCAT(firstname, ' ', lastname)) LIKE ? OR " ..
        "LOWER(firstname) LIKE ? OR LOWER(lastname) LIKE ?",
        {"%" .. searchLower .. "%", "%" .. searchLower .. "%", "%" .. searchLower .. "%"},
        function(results)
            if results and #results > 0 then
                for _, user in ipairs(results) do
                    local jobLabel, gradeLabel
                    
                    if user.job then
                        local jobResult = exports.oxmysql:executeSync("SELECT label FROM jobs WHERE name = ?", {user.job})
                        if jobResult and #jobResult > 0 then
                            jobLabel = jobResult[1].label
                        end
                        
                        if user.job_grade then
                            local gradeResult = exports.oxmysql:executeSync("SELECT label FROM job_grades WHERE job_name = ? AND grade = ?", {user.job, user.job_grade})
                            if gradeResult and #gradeResult > 0 then
                                gradeLabel = gradeResult[1].label
                            end
                        end
                    end
                    
                    local msg = buildOfflinePlayerInfo(user, jobLabel, gradeLabel)
                    TriggerClientEvent('chat:addMessage', source, {
                        color = {0, 153, 204},
                        multiline = true,
                        args = {'[Requesting]', msg}
                    })
                end
            else
                TriggerClientEvent('brutal_notify:SendAlert', source, 'SYSTEM',
                    "No players found matching '" .. search .. "'", 5000, 'error', true)
            end
        end
    )
end, false)

AddEventHandler("onResourceStart", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    TriggerClientEvent("chat:addSuggestion", -1, "/requestinfo", "Request info about a player", {{
        name = "playerID",
        help = "Server ID of the player"
    }})

    TriggerClientEvent("chat:addSuggestion", -1, "/locateinfo", "Find a player by name (online or offline)", {{
        name = "name",
        help = "In-game or identity name"
    }})
end)