local storage = require("core.storage")
local crafter = require("core.crafter")
local server = require("core.server")
local taskQ = require("core.queue")
storage.scanAll()

local function main()
  crafter.request("minecraft:trapped_chest", 10)
  taskQ.log()
end

parallel.waitForAll(function() server.runServer("back") end, main)
