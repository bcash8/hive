local taskQ = require("core.queue")
local storage = require("core.storage")
local handlers = {}

function handlers.request_task(_, message)
  local task = taskQ.getNextReadyTask()
  if task then
    return { type = "task", task = task }
  else
    return { type = "no_task" }
  end
end

function handlers.report_done(_, message)
  if not message.taskId then
    return { type = "report_result", success = false, error = "Missing taskId" }
  end
  taskQ.markDone(message.taskId)
  return { type = "report_result", success = true }
end

function handlers.request_materials(_, message)
  local materials = message.materials
  if materials == nil then return { type = "error", error = "Missing materials list" } end

  local success = true
  for material, amount in pairs(materials) do
    success = success and storage.moveItem(material, amount, message.location, message.taskId)
    print(material, amount, success)
  end

  if success then
    return { type = "materials_delivered" }
  else
    return { type = "failed_delivery" }
  end
end

function handlers.return_materials(_, message)
  local source = message.location
  local slots = message.slots
  if not source or not slots then return { type = "error", error = "Invalid parameters" } end

  for _, slot in pairs(slots) do
    storage.pullItemsIn(source, slot)
  end

  return { type = "materials_returned" }
end

-- Generic message handler
local function handleMessage(id, message)
  if type(message) ~= "table" or not message.type then
    return { error = "Invalid message format" }
  end

  local handler = handlers[message.type]
  if handler then
    local response = handler(id, message)
    response.__requestId = message.__requestId or nil
    return response
  else
    print("Unknown request type", message.type)
    return { error = "Unknown request type", type = "error", __requestId = message.__requestId or nil }
  end
end

-- Server loop
local function runServer(side)
  rednet.open(side)
  print("Task Queue Server running")

  while true do
    local id, message, protocol = rednet.receive()
    local response = handleMessage(id, message)
    rednet.send(id, response, protocol)
  end
end

return { runServer = runServer }
