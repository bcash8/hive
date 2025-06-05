local Worker = require("worker")
local CraftingWorker = {}
CraftingWorker.__index = CraftingWorker
setmetatable(CraftingWorker, { __index = Worker })

function CraftingWorker.new(id)
  local self = setmetatable(Worker.new(id), CraftingWorker)
  return self
end

function CraftingWorker:performTask()
  local task = self.task
  if task == nil then return false end

  local recipe = task.work.recipe
  local itemsPerSlot = math.ceil(task.work.count / recipe.output)
  local requiredMaterials = {}
  for _, char in pairs(recipe.inputs) do
    local ingredient = recipe.ingredients[char]
    if ingredient == nil then error("Unknown character in recipe: " .. char) end
    requiredMaterials[ingredient] = (requiredMaterials[ingredient] or 0) + itemsPerSlot
  end

  print(textutils.serialise(requiredMaterials))
  if self:requestMaterials(requiredMaterials) == false then
    error("Could not retrieve materials")
  end

  local craftingSlots = { 1, 2, 3, 5, 6, 7, 9, 10, 11 }
  local bufferSlots = { 4, 8, 12, 13, 14, 15, 16 }
  local function moveSlotToBuffer(slot)
    turtle.select(slot)
    for _, bufferSlot in pairs(bufferSlots) do
      if turtle.transferTo(bufferSlot) then
        if turtle.getItemCount() == 0 then
          return true
        end
      end
    end

    return false
  end

  local function moveItemToCorrectSlots(item, fromSlot)
    local inputChar = nil
    for char, ingredient in pairs(recipe.ingredients) do
      if ingredient == item.name then
        inputChar = char
        break
      end
    end

    if inputChar == nil then
      print("item not needed")
      turtle.select(fromSlot)
      turtle.dropUp()
      return
    end

    local desiredSlots = {}
    for slot, char in pairs(recipe.inputs) do
      if char == inputChar then
        table.insert(desiredSlots, slot)
      end
    end

    -- Clear out any items in the desiredSlots that are not what we are crafting with
    local itemsInDesiredSlots = {}
    for _, slot in pairs(desiredSlots) do
      local detail = turtle.getItemDetail(slot)
      itemsInDesiredSlots[slot] = 0
      if detail then
        if detail.name ~= item.name then
          if not moveSlotToBuffer(slot) then error("Could not clear crafting space") end
        else
          itemsInDesiredSlots[slot] = detail.count
        end
      end
    end

    turtle.select(fromSlot)
    for _, slot in pairs(desiredSlots) do
      if itemsInDesiredSlots[slot] < itemsPerSlot then
        turtle.transferTo(slot, itemsPerSlot - itemsInDesiredSlots[slot])
      end
    end
  end

  -- Clear crafting slots
  for _, slot in pairs(craftingSlots) do
    local detail = turtle.getItemDetail(slot)
    if detail then
      moveItemToCorrectSlots(detail, slot)
    end
  end

  -- Clean up the bufferSlots
  for _, slot in pairs(bufferSlots) do
    local detail = turtle.getItemDetail(slot)
    if detail then
      moveItemToCorrectSlots(detail, slot)
    end
  end

  turtle.select(1)
  turtle.craft()

  local slotsToReturn = {}
  for i = 1, 16 do
    if turtle.getItemCount(i) > 0 then
      table.insert(slotsToReturn, i)
    end
  end

  local response = self:sendAndWait({ type = "return_materials", slots = slotsToReturn })

  self.status = "COMPLETE"
end

function CraftingWorker:requestTask()
  local response = self:sendAndWait({ type = "request_task" })
  if response and response.type == "task" then
    print(response.task.id)
    self.task = response.task
    self.status = "WORKING"
    return true
  end
  return false
end

return CraftingWorker
