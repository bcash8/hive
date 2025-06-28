local storage = require("core.storage")
local craftingSystem = require("core.crafting.craftingSystem")
local server = require("core.server")
local machineRegistry = require("core.machineRegistry")
machineRegistry.discoverPeripherals()
storage.scanAll()

local function main()
  --  crafter.request("minecraft:piston", 3456, function() print("Crafting complete minecraft:piston") end)
  -- crafter.request("minecraft:iron_pickaxe", 54, function() print("Crafting complete minecraft:iron_pickaxe") end)
  sleep(4)
  craftingSystem.request("minecraft:piston", 8, function() print("Crafting complete minecraft:stick") end)
end

parallel.waitForAll(server.runServer, machineRegistry.cleanup, main)
