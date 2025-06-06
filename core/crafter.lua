local CraftingSystem = {}

local storage = require("core.storage")
local taskQ = require("core.queue")
local recipeBook = require("core.recipe")

local function topologicalSort(tasks)
  local sorted = {}
  local visited = {}

  local function visit(task)
    if visited[task.id] then return end
    visited[task.id] = true
    for _, prereqId in ipairs(task.prereqs or {}) do
      visit(tasks[prereqId])
    end

    table.insert(sorted, task)
  end

  for _, task in pairs(tasks) do
    visit(task)
  end

  return sorted
end

---@param itemName string
---@param amount number
---@params parentId string
---@param state any
---@return string, string | nil "CRAFT,STORAGE,FAIL", error
local function planRecursive(itemName, amount, parentId, state)
  local alreadyLocked = 0
  for _, lock in pairs(state.locks) do
    if lock.itemName == itemName then
      alreadyLocked = alreadyLocked + lock.amount
    end
  end

  local available = math.max(0, storage.countItem(itemName) - alreadyLocked)
  local toCraft = math.max(0, amount - available)

  -- Lock available items (even if partial)
  if available > 0 then
    table.insert(state.locks, {
      taskId = parentId,
      itemName = itemName,
      amount = math.min(available, amount)
    })
  end

  if toCraft <= 0 then
    return "STORAGE", nil
  end

  -- Need to craft the rest
  local recipe = recipeBook.get(itemName)
  if not recipe then
    return "FAIL", "No recipe for item: " .. itemName
  end


  local taskId = taskQ.generateId()
  local task = {
    id = taskId,
    prereqs = {},
    dependents = { parentId },
    work = {
      type = "CRAFT",
      count = toCraft,
      recipe = recipe
    }
  }

  state.tasks[taskId] = task

  -- Link this task to its parent
  if parentId and state.tasks[parentId] then
    table.insert(state.tasks[parentId].prereqs, taskId)
  end

  local ingredientsPerCraft = {}
  for _, char in pairs(recipe.inputs) do
    local ingredientName = recipe.ingredients[char]
    if ingredientName == nil then error("Unknown ingredient in recipe: " .. itemName) end
    ingredientsPerCraft[ingredientName] = (ingredientsPerCraft[ingredientName] or 0) + 1
  end

  for ingredient, count in pairs(ingredientsPerCraft) do
    local ingredientsNeeded = math.ceil((count * toCraft) / recipe.output)
    local status, error = planRecursive(ingredient, ingredientsNeeded, taskId, state)
    if status == "FAIL" then
      return "FAIL", error
    end
  end

  -- Lock the to-be crafted items for the parent
  table.insert(state.locks, {
    taskId = parentId,
    itemName = itemName,
    amount = toCraft
  })

  return "CRAFT", nil
end

local function splitOversizedTasks(state)
  local newTasks = {}
  local newLocks = {}
  local splitMap = {}

  for _, task in pairs(state.tasks) do
    if task.work and task.work.type == "CRAFT" then
      local recipe = task.work.recipe
      local count = task.work.count
      local craftsNeeded = math.ceil(task.work.count / recipe.output)
      local smallestStackSize = math.huge
      for _, ingredient in pairs(recipe.ingredients) do
        smallestStackSize = math.min(smallestStackSize, recipeBook.getMaxStackSize(ingredient) or 64)
      end

      local numberOfBatchesRequired = math.ceil(craftsNeeded / smallestStackSize)

      if numberOfBatchesRequired > 1 then
        splitMap[task.id] = {}
        local remainingToCraft = count
        for i = 1, numberOfBatchesRequired do
          local craftsThisBatch = math.min(smallestStackSize, craftsNeeded - (i - 1) * smallestStackSize)
          local outputAmount = craftsThisBatch * recipe.output
          local actualAmount = math.min(outputAmount, remainingToCraft)

          local splitId = task.id .. "-" .. i
          local splitTask = {
            id = splitId,
            work = {
              type = "CRAFT",
              count = actualAmount,
              recipe = recipe
            },
            prereqs = { unpack(task.prereqs or {}) },
            dependents = {}
          }

          newTasks[splitId] = splitTask
          table.insert(splitMap[task.id], splitId)
          remainingToCraft = remainingToCraft - actualAmount
        end
      else
        newTasks[task.id] = task
      end
    end
  end

  -- Rewire prereqs
  for _, task in pairs(newTasks) do
    if task.prereqs then
      local newPrereqs = {}
      for _, prereqId in pairs(task.prereqs) do
        if splitMap[prereqId] then
          for _, splitId in pairs(splitMap[prereqId]) do
            table.insert(newPrereqs, splitId)
          end
        else
          table.insert(newPrereqs, prereqId)
        end
      end
      task.prereqs = newPrereqs
    end
  end

  -- Rebuild dependents from scratch
  local newDependents = {}
  for _, task in pairs(newTasks) do
    for _, prereqId in ipairs(task.prereqs or {}) do
      newDependents[prereqId] = newDependents[prereqId] or {}
      table.insert(newDependents[prereqId], task.id)
    end
  end
  for taskId, task in pairs(newTasks) do
    task.dependents = newDependents[taskId] or {}
  end

  -- Rewrite locks based on split splitMap
  for _, lock in pairs(state.locks) do
    if splitMap[lock.taskId] then
      for _, sid in pairs(splitMap[lock.taskId]) do
        local splitWork = newTasks[sid].work
        table.insert(newLocks, {
          taskId = sid,
          itemName = lock.itemName,
          amount = math.ceil(splitWork.count / splitWork.recipe.output)
        })
      end
    else
      table.insert(newLocks, lock)
    end
  end

  return newTasks, newLocks
end

---@param itemName string
---@param amount number
function CraftingSystem.request(itemName, amount)
  local state = {
    locks = {},
    tasks = {}
  }

  local rootId = taskQ.generateId()
  state.tasks[rootId] = { id = rootId, prereqs = {}, work = { type = "CRAFT_ROOT" }, dependents = {} }

  local status, err = planRecursive(itemName, amount, rootId, state)
  print(status, err)
  if err then
    return false, err
  end

  if status == "STORAGE" then
    return true
  end

  local tasks, locks = splitOversizedTasks(state)
  local sortedTasks = topologicalSort(tasks)

  for _, lock in pairs(locks) do
    storage.lockItem(lock.itemName, lock.amount, lock.taskId)
  end

  for _, task in pairs(sortedTasks) do
    taskQ.addTask(task)
  end

  return true
end

return CraftingSystem
