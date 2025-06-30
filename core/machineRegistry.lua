local implementations = require("machines.implementations")
local taskQ = require("core.queue")

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
    heartbeat = os.time(),
    busy = false
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

function MachineRegistry.getMachineTypesForRecipeType(recipeType)
  return recipeTypeToMachineType[recipeType]
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

function MachineRegistry.getSupportedRecipeTypes()
  local recipeTypes = {}
  for _, impl in pairs(implementations) do
    if impl.supportedRecipeTypes then
      for _, recipeType in pairs(impl.supportedRecipeTypes) do
        recipeTypes[recipeType] = true
      end
    end
  end
  return recipeTypes
end

function MachineRegistry.getMachineMetadata(machineType)
  if not implementations[machineType] then return nil end
  return implementations[machineType].meta
end

local function findAvailableMachine(recipeType)
  for machineType, impl in pairs(implementations) do
    if impl.supportsRecipeType and impl.supportsRecipeType(recipeType) then
      local machines = MachineRegistry.getMachines(machineType)
      for _, machineId in pairs(machines) do
        local detail = machineDetails[machineId]
        if detail and not detail.busy then
          return machineId, impl
        end
      end
    end
  end
  return nil, nil
end

function MachineRegistry.runManager()
  while true do
    local didWork = false
    for recipeType, _ in pairs(MachineRegistry.getSupportedRecipeTypes()) do
      while taskQ.hasWork(recipeType) do
        local task = taskQ.getNextReadyTask(recipeType)
        if not task then break end

        local machineId, impl = findAvailableMachine(recipeType)
        if machineId and impl and impl.runTask and machineDetails[machineId] then
          machineDetails[machineId].busy = true
          didWork = true

          -- Run the task in the background
          impl.runTask(machineId, task, function()
            if machineDetails[machineId] then machineDetails[machineId].busy = false end
            taskQ.markDone(task.id)
          end)
        else
          taskQ.requeue(task.id)
          break
        end
      end
    end

    if not didWork then
      sleep(1)
    end
  end
end

return MachineRegistry
