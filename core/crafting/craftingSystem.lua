local CraftingSystem = {}

local taskQ = require("core.queue")
local storage = require("core.storage")
local splitters = require("core.crafting.splitters")
local planner = require("core.crafting.planner")
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

local function splitOversizedTasks(state)
  local splitState = {
    newTasks = {},
    newLocks = {},
    splitMap = {}
  }

  for _, task in pairs(state.tasks) do
    if task.work and splitters[task.work.type] then
      splitters[task.work.type](task, state, splitState)
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

  local status, err = planner.planRecursive(itemName, amount, rootId, state)
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
