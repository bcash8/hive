local TaskQueue = {}

local tasks = {}
local readyQueue = {}

--[[
  {
    [taskId] = {
      id = taskId,
      prereqs = {prereq1, prereq2},
      dependents = {dep1, dep2},
      ready = false,
      work = {
        type: "CRAFT",
        **crafting info**
      }
    }
  }
]] --

function TaskQueue.addTask(task)
  task.id = task.id or TaskQueue.generateId()
  task.ready = (#task.prereqs == 0)
  tasks[task.id] = task

  if task.ready then table.insert(readyQueue, task.id) end
  print(task)
  return task.id
end

function TaskQueue.markDone(taskId)
  local task = tasks[taskId]
  if not task then return end

  for _, depId in ipairs(task.dependents or {}) do
    local depTask = tasks[depId]
    local newPrereqs = {}
    for _, d in ipairs(depTask.prereqs) do
      if d ~= taskId then table.insert(newPrereqs, d) end
    end
    depTask.prereqs = newPrereqs

    if #depTask.prereqs == 0 then
      depTask.ready = true
      table.insert(readyQueue, depTask.id)
    end
  end
end

function TaskQueue.hasWork()
  return #readyQueue > 0
end

function TaskQueue.length()
  return #readyQueue
end

function TaskQueue.getNextReadyTask()
  if #readyQueue == 0 then return nil end
  local id = table.remove(readyQueue, 1)
  return tasks[id], id
end

function TaskQueue.generateId()
  return tostring(math.random(1, 1e9))
end

function TaskQueue.log()
  for id, task in pairs(tasks) do
    print(id, task.work.output)
  end
end

return TaskQueue
