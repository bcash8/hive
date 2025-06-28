local recipeBook = require("core.recipe")

local function splitOversizedCraftingTask(task, state, splitState)
  local recipeName = task.work.recipeName
  local output = recipeBook.getOutput(recipeName)
  local count = task.work.count
  local craftsNeeded = math.ceil(task.work.count / output)
  local outputStackSize = recipeBook.getStackSize(task.work.item)
  local smallestStackSize = math.max(16, outputStackSize)

  local ingredientsPerCraft = recipeBook.getRequiredIngredients(recipeName)
  for ingredient, _ in pairs(ingredientsPerCraft) do
    smallestStackSize = math.min(smallestStackSize, recipeBook.getStackSize(ingredient) or 64)
  end

  local numberOfBatchesRequired = math.ceil(craftsNeeded / smallestStackSize)

  if numberOfBatchesRequired > 1 then
    local recipe = task.work.recipe
    splitState.splitMap[task.id] = {}
    local remainingToCraft = count
    for i = 1, numberOfBatchesRequired do
      local craftsThisBatch = math.min(smallestStackSize, craftsNeeded - (i - 1) * smallestStackSize)
      local outputAmount = craftsThisBatch * output
      local actualAmount = math.min(outputAmount, remainingToCraft)

      local splitId = task.id .. "-" .. i
      local splitTask = {
        id = splitId,
        work = {
          type = task.work.type,
          item = task.work.item,
          count = actualAmount,
          recipe = recipe,
          recipeName = recipeName
        },
        prereqs = { unpack(task.prereqs or {}) },
        dependents = {}
      }

      for ingredient, amount in pairs(ingredientsPerCraft) do
        table.insert(splitState.newLocks, {
          taskId = splitId,
          itemName = ingredient,
          amount = amount * actualAmount
        })
      end

      splitState.newTasks[splitId] = splitTask
      table.insert(splitState.splitMap[task.id], splitId)
      remainingToCraft = remainingToCraft - actualAmount
    end
  else
    splitState.newTasks[task.id] = task
    table.insert(splitState.newLocks, state.locks[task.id])
  end
end



return {
  ["minecraft:crafting_shaped"] = splitOversizedCraftingTask,
  ["minecraft:crafting_shapeless"] = splitOversizedCraftingTask,
}
