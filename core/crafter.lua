local CraftingSystem = {}

local storage = require("core.storage")
local taskQ = require("core.queue")
local recipeBook = require("core.recipe")
local machines = require("core.machines")

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
local function planRecursive(itemName, amount, parentId, state, visited)
  visited = visited or {}

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
  local taskId = taskQ.generateId()
  local task = {
    id = taskId,
    prereqs = {},
    dependents = { parentId },
    work = {
      item = itemName,
      count = toCraft,
      recipe = nil -- We will set this to the recipe that is picked further down
    }
  }

  state.tasks[taskId] = task
  print(taskId, itemName)

  local allRecipes = recipeBook.getRecipes(itemName)
  if not allRecipes then
    state.tasks[taskId] = nil
    return "FAIL", "No recipe for item: " .. itemName
  end

  local recipesWithAvailableMachines = {}
  for _, recipeName in pairs(allRecipes) do
    local recipeType = recipeBook.getType(recipeName)
    if machines.exists(recipeType) then
      table.insert(recipesWithAvailableMachines, recipeName)
    end
  end

  -- Loop through the recipes for this item to see if any can be crafted.
  for _, recipeName in pairs(recipesWithAvailableMachines) do
    local pathVisited = {}
    for k, v in pairs(visited) do
      pathVisited[k] = v
    end

    -- Use recipeName + itemName to identify the unique path
    local visitKey = recipeName .. "|" .. itemName
    if pathVisited[visitKey] then
      state.tasks[taskId] = nil
      return "FAIL", "Cycle detected for recipe: " .. recipeName
    end
    pathVisited[visitKey] = true
    local output = recipeBook.getOutput(recipeName)
    local ingredientsPerCraft = recipeBook.getRequiredIngredients(recipeName)
    local recipeOk = true
    local resolvedIngredients = {}
    for ingredient, count in pairs(ingredientsPerCraft) do
      -- Handle tags
      if ingredient:sub(1, 4) == "tag:" then
        local tagName = ingredient:sub(5)
        local tagItems = recipeBook.getTagItems(tagName)
        local tagResolved = false
        for _, actualItem in ipairs(tagItems or {}) do
          local ingredientsNeeded = math.ceil((count * toCraft) / output)
          local status, err = planRecursive(actualItem, ingredientsNeeded, taskId, state, pathVisited)
          if status ~= "FAIL" then
            resolvedIngredients[ingredient] = actualItem
            tagResolved = true
            break
          end
        end

        if not tagResolved then
          recipeOk = false
          break
        end
      else
        local ingredientsNeeded = math.ceil((count * toCraft) / output)
        local status, err = planRecursive(ingredient, ingredientsNeeded, taskId, state, pathVisited)
        if status == "FAIL" then
          recipeOk = false
          -- print("Crafting failed for " .. recipeName .. " " .. err)
          break
        end
        resolvedIngredients[ingredient] = ingredient
      end
    end

    if recipeOk then
      -- Lock the to-be crafted items for the parent
      table.insert(state.locks, {
        taskId = parentId,
        itemName = itemName,
        amount = toCraft
      })

      task.work.recipe = recipeBook.get(recipeName)
      task.work.recipe.meta = {
        output = output,
        ingredientsPerCraft = ingredientsPerCraft,
        resolvedIngredients = resolvedIngredients
      }
      task.work.recipeName = recipeName
      task.work.type = recipeBook.getType(recipeName)

      -- Link this task to its parent
      if parentId and state.tasks[parentId] then
        table.insert(state.tasks[parentId].prereqs, taskId)
      end
      return "CRAFT", nil
    end
  end

  state.tasks[taskId] = nil
  return "FAIL", "No possible recipe for: " .. itemName
end

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

local function splitOversizedTasks(state)
  local splitState = {
    newTasks = {},
    newLocks = {},
    splitMap = {}
  }

  for _, task in pairs(state.tasks) do
    if task.work then
      if task.work.type == "minecraft:crafting_shaped" or task.work.type == "minecraft:crafting_shapeless" then
        splitOversizedCraftingTask(task, state, splitState)
      else
        splitState.newTasks[task.id] = task
        table.insert(splitState.newLocks, state.locks[task.id])
      end
    else
      splitState.newTasks[task.id] = task
      table.insert(splitState.newLocks, state.locks[task.id])
    end
  end

  -- Rewire prereqs
  for _, task in pairs(splitState.newTasks) do
    if task.prereqs then
      local newPrereqs = {}
      for _, prereqId in pairs(task.prereqs) do
        if splitState.splitMap[prereqId] then
          for _, splitId in pairs(splitState.splitMap[prereqId]) do
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
  for _, task in pairs(splitState.newTasks) do
    for _, prereqId in ipairs(task.prereqs or {}) do
      newDependents[prereqId] = newDependents[prereqId] or {}
      table.insert(newDependents[prereqId], task.id)
    end
  end
  for taskId, task in pairs(splitState.newTasks) do
    task.dependents = newDependents[taskId] or {}
  end

  return splitState.newTasks, splitState.newLocks
end

---@param itemName string
---@param amount number
---@param onFinish function | nil
function CraftingSystem.request(itemName, amount, onFinish)
  local state = {
    locks = {},
    tasks = {}
  }

  local rootId = taskQ.generateId()
  state.tasks[rootId] = {
    id = rootId,
    prereqs = {},
    work = { type = "CRAFT_ROOT" },
    dependents = {},
    __onFinish = onFinish,
    __onReady = function() taskQ.markDone(rootId) end
  }

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
    -- print(task.id, textutils.serialise(task.prereqs), task.work.recipeName)
    taskQ.addTask(task)
  end

  return true
end

return CraftingSystem
