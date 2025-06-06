local Worker = {}
Worker.__index = Worker

local SERVER_ID = 2
local PROTOCOL = "crafter_worker"
local MODEM_SIDE = "LEFT"
local PERIPHERAL_NAME = "turtle_8"
local WAITING_INDICATOR_SIDE = "top"

rednet.open(MODEM_SIDE)

function Worker.new(id)
  local self = setmetatable({}, Worker)
  self.id = id or os.getComputerID()
  self.status = "IDLE"
  self.task = nil
  self.messageQueue = {}
  self.listeners = {}
  return self
end

function Worker:send(message)
  rednet.send(SERVER_ID, message, PROTOCOL)
end

function Worker:sendAndWait(request, timeout, retires)
  rs.setOutput(WAITING_INDICATOR_SIDE, true)
  local result = nil

  for i = 1, retires or 3 do
    local requestId = tostring(math.random(1, 1e9))
    request.__requestId = requestId

    local done = false

    self.listeners[requestId] = function(message)
      result = message
      done = true
    end

    self:send(request)

    local timer = os.startTimer(timeout or 5)
    while not done do
      local event, arg = os.pullEvent()
      if event == "timer" and arg == timer then
        break
      end
    end

    if result then break end

    self.listeners[requestId] = nil
  end

  rs.setOutput(WAITING_INDICATOR_SIDE, false)
  return result
end

function Worker:receive(timeout)
  local senderId, message, protocol = rednet.receive(PROTOCOL, timeout)
  print(message)
  if protocol == PROTOCOL and senderId == SERVER_ID then
    return message
  end
  return nil
end

function Worker:requestMaterials(materials)
  self:send({
    type = "request_materials",
    materials = materials,
    location = PERIPHERAL_NAME,
    workerId = self.id,
    taskId =
        self.task.id
  })
  local response = self:receive(10)
  if response and response.type == "materials_delivered" then
    print("[Worker] Materials received")
    return true
  end
  return false
end

function Worker:returnMaterials(slots)
  self:send({ type = "return_materials", slots = slots, location = PERIPHERAL_NAME, workerId = self.id })
  local response = self:receive(10)
  if response and response.type == "materials_returned" then
    print("[Worker] Materials returned")
    return true
  end
  return false
end

function Worker:reportDone()
  if not self.task then return true end
  local response = self:sendAndWait({ type = "report_done", taskId = self.task.id }, 10)
  return response
end

function Worker:scanInventory()
  local inventory = {}
  for i = 1, 16 do
    inventory[i] = turtle.getItemDetail(i)
  end
  return inventory
end

function Worker:performTask()
  if not self.task then return false end
  return true
end

function Worker:requestTask()
  print("Requesting task")
  return false
end

function Worker:run()
  local function listener()
    print("Starting Listener")
    while true do
      local senderId, message, protocol = rednet.receive(PROTOCOL)
      if protocol == PROTOCOL and senderId == SERVER_ID then
        -- Dispatch to specific listener if tagged
        if message.__requestId and self.listeners[message.__requestId] then
          local fn = self.listeners[message.__requestId]
          self.listeners[message.__requestId] = nil
          fn(message)
        else
          table.insert(self.messageQueue, message)
        end
      end
    end
  end

  local function mainLoop()
    while true do
      if self.status == "IDLE" then
        self:requestTask()
      elseif self.status == "WORKING" then
        self:performTask()
      elseif self.status == "COMPLETE" or self.status == "ERROR" then
        self.status = "IDLE"
      end
      sleep(1)
    end
  end

  parallel.waitForAny(listener, mainLoop)
end

return Worker
