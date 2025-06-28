local Machine = require("machines.machine")
local Blaster = setmetatable({}, { __index = Machine })
Blaster.__index = Blaster

function Blaster:new(id)
  local self = Machine.new(self, id)
  self.workType = "minecraft:blasting"
  setmetatable(self, Blaster)
  return self
end

return Blaster
