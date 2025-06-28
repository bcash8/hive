local storage = require("core.storage")

local BlastFurnace = {}
local INPUT_SLOT = 1
local FUEL_SLOT = 2
local OUTPUT_SLOT = 3

BlastFurnace.supportedRecipeTypes = { "minecraft:blasting" }

function BlastFurnace.supportsRecipeType(recipeType)
  for _, type in pairs(BlastFurnace.supportedRecipeTypes) do
    if type == recipeType then return true end
  end

  return false
end

local function run(task)
  print(textutils.serialise(task.work))
end

function BlastFurnace.runTask(machineId, task, onDone)
  local p = peripheral.wrap(machineId)

  print("Starting blast:", task.work.item, "on", machineId)

  parallel.waitForAll(function()
    run(task)
    onDone()
  end)
end

return BlastFurnace
