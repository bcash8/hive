local TaskQueue = {}

local tasks = {}
local readyQueue = {}

function TaskQueue.addTask(task)
  task.id = task.id or TaskQueue.generateId()
  task.ready = (#task.prereqs == 0)
  tasks[task.id] = task

  if task.ready then
    print(task.work.type)
    readyQueue[task.work.type] = readyQueue[task.work.type] or {}
    table.insert(readyQueue[task.work.type], task.id)
  end
  return task.id
end

function TaskQueue.requeue(taskId)
  local task = tasks[taskId]
  if not task or not task.ready then return end

  local queue = readyQueue[task.work.type]
  if not queue then
    readyQueue[task.work.type] = { taskId }
  else
    table.insert(queue, taskId)
  end
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
      readyQueue[depTask.work.type] = readyQueue[depTask.work.type] or {}
      table.insert(readyQueue[depTask.work.type], depTask.id)
      if depTask.__onReady then depTask.__onReady() end
    end
  end

  tasks[taskId] = nil
  if task.__onFinish then task.__onFinish() end
end

function TaskQueue.hasWork(workType)
  return #readyQueue[workType] > 0
end

function TaskQueue.length(workType)
  return #readyQueue[workType]
end

function TaskQueue.getNextReadyTask(workType)
  if not readyQueue[workType] or #readyQueue[workType] == 0 then return nil end
  local id = table.remove(readyQueue[workType], 1)
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
