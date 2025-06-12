local storage = require("core.storage")
local crafter = require("core.crafter")
local server = require("core.server")
storage.scanAll()

local function main()
  --  crafter.request("minecraft:piston", 3456, function() print("Crafting complete minecraft:piston") end)
  -- crafter.request("minecraft:iron_pickaxe", 54, function() print("Crafting complete minecraft:iron_pickaxe") end)
  crafter.request("minecraft:piston", 17, function() print("Crafting complete minecraft:stick") end)
end

parallel.waitForAll(function() server.runServer() end, main)
