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
  self.machineType = nil
  self.registered = false
  return self
end

function Worker:send(message)
  rednet.send(SERVER_ID, message, PROTOCOL)
end

function Worker:sendAndWait(request, timeout, retires)
  rs.setOutput(WAITING_INDICATOR_SIDE, true)
  local result = nil

  for i = 1, retires or 15 do
    local requestId = tostring(math.random(1, 1e9))
    request.__requestId = requestId

    local done = false

    self.listeners[requestId] = function(message)
      result = message
      done = true
    end

    self:send(request)

    local timer = os.startTimer(timeout or i)
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
  local response = self:sendAndWait({
    type = "request_materials",
    materials = materials,
    location = PERIPHERAL_NAME,
    workerId = self.id,
    taskId =
        self.task.id
  })

  if response and response.type == "materials_delivered" then
    print("[Worker] Materials received")
    return true
  end
  return false
end

function Worker:returnMaterials(slots)
  local response = self:sendAndWait({
    type = "return_materials",
    slots = slots,
    location = PERIPHERAL_NAME,
    workerId =
        self.id
  })
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

function Worker:heartbeat()
  while true do
    if not self.registered then
      local response = self:sendAndWait({ type = "register_machines", self.machineType }, 2, 10)
      if response == nil then
        print("Unable to register")
      else
        self.registered = true
      end
    else
      local response = self:sendAndWait({ type = "heartbeat" })
      if not response then
        print("Connection lost to server.")
        self.registered = false
      end
    end
    sleep(5)
  end
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

  parallel.waitForAny(listener, mainLoop, function() self:heartbeat() end)
end

return Worker
