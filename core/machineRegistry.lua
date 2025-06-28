local MachineRegistry = {}

local machines = {}
local machineDetails = {}

local recipeTypeToMachineType = {
  ["minecraft:crafting_shaped"] = { "crafting_turtle" },
  ["minecraft:crafting_shapeless"] = { "crafting_turtle" },
  ["minecraft:smelting"] = { "minecraft:furnace" },
  ["minecraft:blasting"] = { "minecraft:blast_furnace" },
  ["minecraft:smoking"] = { "minecraft:smoker" },
}

function MachineRegistry.register(machineType, machineId)
  machines[machineType] = machines[machineType] or {}
  table.insert(machines[machineType], machineId)
  machineDetails[machineId] = {
    type = machineType,
    heartbeat = os.time()
  }
end

function MachineRegistry.exists(recipeType)
  local machineTypes = recipeTypeToMachineType[recipeType]
  if not machineTypes then error("No known machines for recipe type: " .. recipeType) end
  for _, machineType in pairs(machineTypes) do
    if machines[machineType] and #machines[machineType] > 0 then return true end
  end
  return false;
end

function MachineRegistry.getMachines(machineType)
  return machines[machineType] or {}
end

function MachineRegistry.discoverPeripherals()
  for _, name in ipairs(peripheral.getNames()) do
    local pType = peripheral.getType(name)
    MachineRegistry.register(pType, name)
  end
end

function MachineRegistry.heartbeat(machineId)
  local machine = machineDetails[machineId]
  if not machine then return end
  machine.heartbeat = os.time()
end

function MachineRegistry.cleanup()
  while true do
    local now = os.time()
    for machineId, details in pairs(machineDetails) do
      if now - details.heartbeat > 10 then
        -- Remove from machines
        local list = machines[details.type]
        if list then
          for i = #list, 1, -1 do
            if list[i] == machineId then
              table.remove(list, i)
            end
          end
          if #list == 0 then
            machines[details.type] = nil
          end
        end

        -- Remove from machineDetails
        machineDetails[machineId] = nil
      end
    end
    sleep(5)
  end
end

function MachineRegistry.runManager()

end

return MachineRegistry
