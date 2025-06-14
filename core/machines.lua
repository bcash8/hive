local Machines = {}

local machineRegistry = {}
local machineDetails = {}

local recipeTypeToMachineType = {
  ["minecraft:crafting_shaped"] = { "crafting_turtle" },
  ["minecraft:crafting_shapeless"] = { "crafting_turtle" },
  ["minecraft:smelting"] = { "minecraft:furnace" },
  ["minecraft:blasting"] = { "minecraft:blast_furnace" },
  ["minecraft:smoking"] = { "minecraft:smoker" },
}

function Machines.register(machineType, machineId)
  machineRegistry[machineType] = machineRegistry[machineType] or {}
  table.insert(machineRegistry[machineType], machineId)
  machineDetails[machineId] = {
    type = machineType,
    heartbeat = os.time()
  }
end

function Machines.exists(recipeType)
  print(textutils.serialise(machineRegistry))
  local machineTypes = recipeTypeToMachineType[recipeType]
  if not machineTypes then error("No known machines for recipe type: " .. recipeType) end
  for _, machineType in pairs(machineTypes) do
    if machineRegistry[machineType] and #machineRegistry[machineType] > 0 then return true end
  end
  return false;
end

function Machines.getMachines(machineType)
  return machineRegistry[machineType] or {}
end

function Machines.discoverPeripherals()
  for _, name in ipairs(peripheral.getNames()) do
    local pType = peripheral.getType(name)
    Machines.register(pType, name)
  end
end

function Machines.heartbeat(machineId)
  local machine = machineDetails[machineId]
  if not machine then return end
  machine.heartbeat = os.time()
end

function Machines.cleanup()
  while true do
    local now = os.time()
    for machineId, details in pairs(machineDetails) do
      if now - details.heartbeat > 10 then
        -- Remove from machineRegistry
        local list = machineRegistry[details.type]
        if list then
          for i = #list, 1, -1 do
            if list[i] == machineId then
              table.remove(list, i)
            end
          end
          if #list == 0 then
            machineRegistry[details.type] = nil
          end
        end

        -- Remove from machineDetails
        machineDetails[machineId] = nil
      end
    end
    sleep(5)
  end
end

return Machines
