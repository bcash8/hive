local CraftingSystem = {}

local storage = require("core.storage")
local taskQ = require("core.queue")
local recipeBook = require("core.recipe")

local function topologicalSort(tasks)
  local sorted = {}
  local visited = {}

  local taskMap = {}
  for _, task in ipairs(tasks) do
    taskMap[task.tempId] = task
  end

  local function visit(task)
    if visited[task.tempId] then return end
    visited[task.tempId] = true
    for _, prereqId in ipairs(task.prereqsTemp or {}) do
      visit(taskMap[prereqId])
    end

    table.insert(sorted, task)
  end

  for _, task in ipairs(tasks) do
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
  local itemsInStorage = storage.countItem(itemName)
  local itemsToCraft = amount - itemsInStorage

  -- The item is in storage, we just need to lock it for the parent crafting task
  if itemsToCraft <= 0 then
    table.insert(state.locks, {taskId = parentId, itemName= itemName, amount = amount})
    return "STORAGE", nil
  end
  
  -- Lock the items that we do have in storage, then craft the rest.
  table.insert(state.locks, {taskId = parentId, itemName = itemName, amount = itemsInStorage})

  local recipe = recipeBook.get(itemName)
  local neededIngredients = {}
  for slot, char in pairs(recipe.inputs) do
    -- neededIngredients[recipe.]
  end


  return "CRAFT", nil
end

-- TODO: replace this whole request system with a simplier more straight forward one that
-- only creates new task ids when an item needs to be crafted.
---@param itemName string
---@param amount number
function CraftingSystem.request(itemName, amount)
  local state = {
    toLock = {},
    tasks = {}
  }
  local rootId = taskQ.generateId()

  local status, error = planRecursive(itemName, amount, rootId, state)
  if error then 
    return false, error
  end

  if status == "CRAFT" then
    -- Add the tasks
    return true
  end

  return false, nil
end

return CraftingSystem
