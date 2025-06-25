local taskQ = require("core.queue")
local storage = require("core.storage")
local machines = require("core.machines")
local handlers = {}
local messageQueue = {}
local MODEM_SIDE = "back"

local function buildPeripheralMap()
  local map = {}
  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "turtle" then
      local ok, id = pcall(peripheral.call, name, "getID")
      if ok and id then
        map[id] = name
      end
    end
  end
  return map
end

local peripheralMap = buildPeripheralMap()

local craftingWorkTypes = { "minecraft:crafting_shaped", "minecraft:crafting_shapeless" }
function handlers.request_task(_, message)
  local task = nil
  if message.workType == "CRAFT" then
    for _, workType in pairs(craftingWorkTypes) do
      task = taskQ.getNextReadyTask(workType)
      if task then break end
    end
  end
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

function handlers.request_materials(senderId, message)
  local materials = message.materials
  if materials == nil then return { type = "error", error = "Missing materials list" } end

  local location = peripheralMap[senderId]
  if location == nil then
    return { type = "failed_delivery" }
  end

  local success = true
  for material, amount in pairs(materials) do
    success = success and storage.moveItem(material, amount, location, message.taskId)
  end

  if success then
    return { type = "materials_delivered" }
  else
    return { type = "failed_delivery" }
  end
end

function handlers.return_materials(senderId, message)
  local source = peripheralMap[senderId]
  local slots = message.slots
  if not source or not slots then return { type = "error", error = "Invalid parameters" } end

  for _, slot in pairs(slots) do
    storage.pullItemsIn(source, slot)
  end

  return { type = "materials_returned" }
end

function handlers.register_machine(senderId, message)
  if type(message.machineType) ~= "string" then
    return { type = "error", error = "Missing Machine Type" }
  end

  local peripheralName = peripheralMap[senderId]
  if not peripheralName then
    return { type = "error", error = "Unknown ID" }
  end

  machines.register(message.machineType, peripheralName)
  return { type = "registered", }
end

function handlers.heartbeat(senderId, message)
  local machineId = peripheralMap[senderId]
  if not machineId then return { type = "error", error = "Unknown machine" } end
  machines.heartbeat(machineId)
  return { type = "success" }
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
local function processMessages()
  while true do
    if #messageQueue > 0 then
      local entry = table.remove(messageQueue, 1)
      if entry.protocol == "network_discovery" then
        rednet.send(entry.id, { type = "ack" }, entry.protocol)
      else
        local response = handleMessage(entry.id, entry.message)
        rednet.send(entry.id, response, entry.protocol)
      end
    else
      sleep(0.1)
    end
  end
end

local function startListener()
  rednet.open(MODEM_SIDE)
  print("Task Queue Server running")

  while true do
    local id, message, protocol = rednet.receive()
    if message then
      table.insert(messageQueue, { id = id, message = message, protocol = protocol })
    end

    sleep(0.05)
  end
end

local function runServer()
  parallel.waitForAll(startListener, processMessages)
end

return { runServer = runServer }
