--[[
    File Name: Remotes.lua
    Author(s): Pkamara (GameAnnounce)
    Type: ModuleScript

    A dynamic wrapper for remoteevents (and only remote events)
]]--

local Remote = {}

function Remote:new(remote, remoteKey)
    if not remote then
        remote = Instance.new("RemoteEvent") -- doesn't need a parent, user can do it themselves
    end

    local newRemote = newproxy(true)
    local remoteMeta = getmetatable(newRemote)
    local remoteData = setmetatable({
        users = {}, -- store the users who have called this remote
        buffer = {}, -- a buffer of all current packets (should be cleared often to avoid high memory usage)
        remoteKey = remoteKey, -- yes yes, I know but still - some type of key
        total_packets_recieved = 0, -- how many packets have we recieved and read
        total_packets_discarded = 0, -- how many packets have we recieved and discarded
    }, 
    {
        __metatable="locked"
    }) -- all data that we store about the remote

    -- get table of all users
    function remoteData:getUsers()
        return remoteData.users
    end

    -- get a specific user
    function remoteData:getUser(userId)
        remoteData.users[userId]
    end

    return newRemote
end

-- return lib
return Remote