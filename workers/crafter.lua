local Worker = require("worker")
local CraftingWorker = {}
CraftingWorker.__index = CraftingWorker
setmetatable(CraftingWorker, { __index = Worker })

local WORK_TYPE = "CRAFT"

function CraftingWorker.new(id)
  local self = setmetatable(Worker.new(id), CraftingWorker)
  self.machineType = "crafting_turtle"
  return self
end

local craftingSlots = { 1, 2, 3, 5, 6, 7, 9, 10, 11 }
local bufferSlots = { 4, 8, 12, 13, 14, 15, 16 }

local function moveToBufferSlot(slot)
  turtle.select(slot)
  for _, slot in pairs(bufferSlots) do
    if turtle.transferTo(slot) and turtle.getItemCount(slot) == 0 then
      return
    end
  end
end

local function craftShapedRecipe(recipe, toCraft)
  local pattern = recipe.pattern
  local itemsPerSlot = toCraft
  local resolvedIngredientKey = {}
  for char, info in pairs(recipe.key) do
    local itemName = info.item or ("tag:" .. info.tag)
    resolvedIngredientKey[char] = recipe.meta.resolvedIngredients[itemName]
  end

  local slotToItem = {}

  local width = 0
  for _, row in ipairs(pattern) do
    width = math.max(width, #row)
  end
  local height = #pattern
  print(width, height)

  -- For each pattern row/col, map to the correct turtle slot
  for row = 1, height do
    local line = pattern[row]
    for col = 1, #line do
      local symbol = line:sub(col, col)
      if symbol ~= " " and resolvedIngredientKey[symbol] then
        local slotIndex = (row - 1) * 3 + col
        local turtleSlot = craftingSlots[slotIndex]
        slotToItem[turtleSlot] = resolvedIngredientKey[symbol]
      end
    end
  end

  local itemToSlot = {}
  for slot, item in pairs(slotToItem) do
    itemToSlot[item] = itemToSlot[item] or {}
    table.insert(itemToSlot[item], slot)
  end

  -- TODO Fix this logic
  local function moveItemToCorrectSlot(fromSlot)
    turtle.select(fromSlot)
    local fromDetails = turtle.getItemDetail(fromSlot)
    if not fromDetails then return end
    local slotsForItem = itemToSlot[fromDetails.name]
    local toMove = math.max(0, fromDetails.count - itemsPerSlot)
    if toMove < 0 then return end

    for _, slot in pairs(slotsForItem) do
      local toSlotDetails = turtle.getItemDetail(slot)
      if toSlotDetails then
        if toSlotDetails.name == fromDetails.name then
          local canMove = math.max(0, itemsPerSlot - toSlotDetails.count)
          local realMoveAmount = math.min(toMove, canMove)
          turtle.transferTo(slot, realMoveAmount)
          toMove = toMove - realMoveAmount
        else
          moveToBufferSlot(slot)
          turtle.select(fromSlot)
          turtle.transferTo(slot, toMove)
          return
        end
      else
        turtle.select(fromSlot)
        turtle.transferTo(slot, toMove)
        return
      end
    end
  end

  for _, slot in pairs(craftingSlots) do
    moveItemToCorrectSlot(slot)
  end

  for _, slot in pairs(bufferSlots) do
    moveItemToCorrectSlot(slot)
  end

  turtle.select(1)
  turtle.craft()
end

local function craftShapelessRecipe(recipe, toCraft)
  turtle.craft()
end

local function craftRecipe(recipe, toCraft)
  if recipe.type == "minecraft:crafting_shaped" then
    craftShapedRecipe(recipe, toCraft)
  elseif recipe.type == "minecraft:crafting_shapeless" then
    craftShapelessRecipe(recipe, toCraft)
  end
end

function CraftingWorker:performTask()
  local task = self.task
  if task == nil then return false end

  print(task.work.recipeName)
  local recipe = task.work.recipe
  local itemsPerSlot = math.ceil(task.work.count / recipe.meta.output)
  local requiredMaterials = {}
  for ingredientTag, count in pairs(recipe.meta.ingredientsPerCraft) do
    requiredMaterials[recipe.meta.resolvedIngredients[ingredientTag]] = count * itemsPerSlot
  end

  if self:requestMaterials(requiredMaterials) == false then
    error("Could not retrieve materials")
  end

  craftRecipe(recipe, itemsPerSlot)

  local slotsToReturn = {}
  for i = 1, 16 do
    if turtle.getItemCount(i) > 0 then
      table.insert(slotsToReturn, i)
    end
  end

  print(#slotsToReturn)
  if self:returnMaterials(slotsToReturn) then
    self:reportDone()
  end

  self.status = "COMPLETE"
end

function CraftingWorker:requestTask()
  local response = self:sendAndWait({ type = "request_task", workType = WORK_TYPE })
  if response and response.type == "task" then
    print(response.task.id)
    self.task = response.task
    self.status = "WORKING"
    return true
  end
  return false
end

return CraftingWorker
