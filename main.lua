local storage = require("core.storage")
local crafter = require("core.crafter")
local server = require("core.server")
local taskQ = require("core.queue")
storage.scanAll()

local function main()
  storage.moveItem("minecraft:black_wool", 30, "minecraft:chest_60")
  crafter.request("minecraft:piston", 64)
  taskQ.log()
end

parallel.waitForAll(function() server.runServer("back") end, main)
