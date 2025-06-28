local Machine = {}
Machine.__index = Machine

function Machine:new(id)
  local self = setmetatable({}, Machine)
  self.id = id
  self.status = "UNKNOWN"
  self.type = "UNKNOWN"
  return self
end

function Machine:isAvailable()
  return self.status == "IDLE"
end

function Machine:startTask()
  self.status = "BUSY"
end

function Machine:endTask()
  self.status = "IDLE"
end

function Machine:process(task)
  -- Add logic for each machine type here.
end
