local CraftingSystem = {}

local storage = require("core.storage")
local taskQ = require("core.queue")
local recipeBook = require("core.recipe")

local function planRecursive(itemName, amount, state, parentId)
  local available = storage.countItem(itemName) - (state.locks[itemName] or 0)
  local toLock = math.min(available, amount)
  state.locks[itemName] = state.locks[itemName] or { total = 0, tasks = {} }
  state.locks[itemName].total = state.locks[itemName].total + toLock
  state.locks[itemName].tasks[parentId] = toLock

  local remainder = amount - toLock
  if remainder <= 0 then return true end -- The items requested are already in storage

  local recipe = recipeBook.get(itemName)
  if not recipe then return false, nil, "No recipe for " .. itemName end

  local tempId = taskQ.generateId()
  local ingCount = {}
  for _, char in pairs(recipe.inputs) do
    local ing = recipe.ingredients[char]
    ingCount[ing] = (ingCount[ing] or 0) + 1
  end

  local multiplier = math.ceil(remainder / recipe.output)
  local prereqsTemp = {}

  for ing, count in pairs(ingCount) do
    local total = count * multiplier
    local ok, prereqId, err = planRecursive(ing, total, state, tempId)
    if not ok then return false, nil, err end
    table.insert(prereqsTemp, prereqId)
  end


  table.insert(state.tasks, {
    tempId = tempId,
    prereqsTemp = prereqsTemp,
    work = {
      type = "CRAFT",
      output = itemName,
      count = remainder,
      recipe = recipe
    }
  })

  return true, tempId
end

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


-- TODO: replace this whole request system with a simplier more straight forward one that
-- only creates new task ids when an item needs to be crafted.
function CraftingSystem.request(itemName, amount)
  local rootId = taskQ.generateId()
  local state = {
    locks = {},
    tasks = {}
  }

  local success, taskId, err = planRecursive(itemName, amount, state, rootId)
  print(success, taskId, err)
  if not success then return false, err end

  -- The item can be crafted
  -- Lock the items necessary to craft
  for itemName, lock in pairs(state.locks) do
    for taskId, count in pairs(lock.tasks) do
      storage.lockItem(itemName, count, taskId)
    end
  end

  local sortedTasks = topologicalSort(state.tasks)

  local idToTask = {}
  local tempToReal = {}
  for _, task in ipairs(sortedTasks) do
    local realId = taskQ.generateId()
    tempToReal[task.tempId] = realId

    local realPrereqs = {}
    for _, temp in ipairs(task.prereqsTemp or {}) do
      table.insert(realPrereqs, tempToReal[temp])
    end

    idToTask[realId] = {
      id = realId,
      prereqs = realPrereqs,
      dependents = {},
      ready = false,
      work = task.work
    }
  end

  for _, task in pairs(idToTask) do
    for _, prereqId in pairs(task.prereqs) do
      local prereqTask = idToTask[prereqId]
      table.insert(prereqTask.dependents, task.id)
    end
  end

  for _, task in pairs(idToTask) do
    print(task.work.output)
    taskQ.addTask(task)
  end

  return true
end

return CraftingSystem
