local storage = require("core.storage")

local BlastFurnace = {}
local INPUT_SLOT = 1
local FUEL_SLOT = 2
local OUTPUT_SLOT = 3

BlastFurnace.supportedRecipeTypes = { "minecraft:blasting" }
BlastFurnace.meta = {
  supplementalItems = {
    { item = "map:fuel", perCraft = 200 }
  }
}

function BlastFurnace.supportsRecipeType(recipeType)
  for _, type in pairs(BlastFurnace.supportedRecipeTypes) do
    if type == recipeType then return true end
  end


  return false
end

local function run(machineId, task, onDone)
  print(textutils.serialise(task.work.recipe.meta))
  local fuel = task.work.recipe.meta.supplementalItems["map:fuel"]
  storage.moveItem(fuel.item, fuel.amount, machineId, task.id, FUEL_SLOT)

  local itemsToSmelt = task.work.count
  local itemTag = next(task.work.recipe.meta.resolvedIngredients)
  local item = task.work.recipe.meta.resolvedIngredients[itemTag]
  local amount = task.work.recipe.meta.ingredientsPerCraft[itemTag] * itemsToSmelt
  storage.moveItem(item, amount, machineId, task.id, INPUT_SLOT)

  local secondsToWait = ((100 * itemsToSmelt) / 20) + 1
  local timer = os.startTimer(secondsToWait)

  while true do
    local event, arg = os.pullEvent()
    if event == "timer" and arg == timer then
      break
    end
  end

  storage.pullItemsIn(machineId, OUTPUT_SLOT)
  onDone()
end

function BlastFurnace.runTask(machineId, task, onDone)
  print("Starting blast:", task.work.item, "on", machineId)
  run(machineId, task, onDone)
end

return BlastFurnace
