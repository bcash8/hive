local storage = require("core.storage")

local BlastFurnace = {}
local INPUT_SLOT = 1
local FUEL_SLOT = 2
local OUTPUT_SLOT = 3

BlastFurnace.supportedRecipeTypes = { "minecraft:blasting" }
BlastFurnace.meta = {
  supplementalItems = {
    { item = "map:minecraft:fuel", perCraft = 100 }
  }
}

function BlastFurnace.supportsRecipeType(recipeType)
  for _, type in pairs(BlastFurnace.supportedRecipeTypes) do
    if type == recipeType then return true end
  end


  return false
end

local function run(machineId, task)
  print(textutils.serialise(task.work))
  local resolvedIngredients = task.recipe.meta.resolvedIngredients
  local _, itemNeeded = next(resolvedIngredients)
  local amountNeeded = task.work.count
  storage.moveItem(itemNeeded, amountNeeded, machineId, task.id)
end

function BlastFurnace.runTask(machineId, task, onDone)
  print("Starting blast:", task.work.item, "on", machineId)

  parallel.waitForAll(function()
    run(machineId, task)
    onDone()
  end)
end

return BlastFurnace
