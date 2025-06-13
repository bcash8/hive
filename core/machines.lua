local Machines = {}

local machineRegistry = {}

local recipeTypeToMachineType = {
  ["minecraft:crafting_shaped"] = { "crafting_turtle" },
  ["minecraft:crafting_shapless"] = { "crafting_turtle" },
  ["minecraft:smelting"] = { "minecraft:furnace" },
  ["minecraft:blasting"] = { "minecraft:blast_furnace" },
  ["minecraft:smoking"] = { "minecraft:smoker" },
}

function Machines.register(machineType, machineId)
  machineRegistry[machineType] = machineRegistry[machineType] or {}
  table.insert(machineRegistry[machineType], machineId)
end

function Machines.exists(recipeType)
  local machineType = recipeTypeToMachineType[recipeType]
  if not machineType then error("No known machines for recipe type: " .. recipeType) end
  local machines = machineRegistry[machineType]
  return machines ~= nil and #machines > 0
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

return Machines
