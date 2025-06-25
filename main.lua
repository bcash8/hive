local storage = require("core.storage")
local crafter = require("core.crafter")
local server = require("core.server")
local machines = require("core.machines")
machines.discoverPeripherals()
storage.scanAll()

local function main()
  --  crafter.request("minecraft:piston", 3456, function() print("Crafting complete minecraft:piston") end)
  -- crafter.request("minecraft:iron_pickaxe", 54, function() print("Crafting complete minecraft:iron_pickaxe") end)
  sleep(4)
  crafter.request("minecraft:piston", 8, function() print("Crafting complete minecraft:stick") end)
end

parallel.waitForAll(server.runServer, machines.cleanup, main)
