local CraftingSystem = {}

local storage = require("core.storage")
local taskQ = require("core.queue")
local recipeBook = require("core.recipe")

local function topologicalSort(tasks)
  local sorted = {}
  local visited = {}

  local function visit(task)
    print(task.id)
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
  local available = storage.countItem(itemName)
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
    local ingredientsNeeded = count * toCraft
    local status, error = planRecursive(ingredient, ingredientsNeeded, taskId, state)
    if status == "FAIL" then
      return "FAIL", error
    end
  end

  return "CRAFT", nil
end

-- TODO: replace this whole request system with a simplier more straight forward one that
-- only creates new task ids when an item needs to be crafted.
---@param itemName string
---@param amount number
function CraftingSystem.request(itemName, amount)
  local state = {
    locks = {},
    tasks = {}
  }

  local rootId = taskQ.generateId()
  state.tasks[rootId] = { id = rootId, prereqs = {}, work = { type = "ROOT" } }

  local status, error = planRecursive(itemName, amount, rootId, state)
  if error then
    return false, error
  end

  if status == "STORAGE" then
    return true
  end

  local sortedTasks = topologicalSort(state.tasks)

  for _, lock in pairs(state.locks) do
    storage.lockItem(lock.itemName, lock.amount, lock.taskId)
  end

  for _, task in pairs(sortedTasks) do
    if task.work.type ~= "ROOT" then
      taskQ.addTask(task)
    end
  end

  return true
end

return CraftingSystem
