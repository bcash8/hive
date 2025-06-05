local StorageManager = {}

--[[
  {
    [item_name] = {
      locations = {
        [inventory_name] = {[slot] = 30}
      }
    }
  }
]] --
local inventoryCache = {}

--[[{
  [item_name] = {
    total = 12,
    tasks = {
      [taskId] = 5
    }
  }
]] --}
local lockTable = {}
local freeSlots = {}
local partialStacks = {}
local maxStackSizeMap = {}

if fs.exists("data/maxStackSizeMap.txt") then
  local file = fs.open("hive/data/maxStackSizeMap.txt", "r")
  local contents = file.readAll()
  maxStackSizeMap = textutils.unserialise(contents)
  file.close()
end

local function addItemToMaxStackSizeMap(itemName, maxStackSize)
  print(itemName)
  maxStackSizeMap[itemName] = maxStackSize
  local file = fs.open("hive/data/maxStackSizeMap.txt", "w")
  file.write(textutils.serialise(maxStackSizeMap))
  file.close()
end

local function isStoragePeripheral(name)
  return peripheral.getType(name) == "minecraft:chest"
end

function StorageManager.scanAll()
  inventoryCache = {}
  for _, inventoryName in ipairs(peripheral.getNames()) do
    if isStoragePeripheral(inventoryName) then
      local chest = peripheral.wrap(inventoryName)
      local items = chest.list()
      freeSlots[inventoryName] = {}

      for slot = 1, chest.size() do
        local item = items[slot]
        if item then
          -- Add the item to the maxStackSizeMap if it hasn't been seen before
          if not maxStackSizeMap[item.name] then
            local detail = chest.getItemDetail(slot)
            if detail then
              addItemToMaxStackSizeMap(detail.name, detail.maxCount)
            end
            item.maxCount = maxStackSizeMap[item.name] or 0
          else
            item.maxCount = maxStackSizeMap[item.name] or 0
          end

          if not inventoryCache[item.name] then
            inventoryCache[item.name] = { locations = {} }
          end
          inventoryCache[item.name].locations[inventoryName] = inventoryCache[item.name].locations[inventoryName] or {}
          inventoryCache[item.name].locations[inventoryName][slot] = item.count

          -- Track partial stacks
          if item.count < item.maxCount then
            partialStacks[item.name] = partialStacks[item.name] or {}
            partialStacks[item.name][inventoryName] = partialStacks[item.name][inventoryName] or {}
            partialStacks[item.name][inventoryName][slot] = item.maxCount - item.count
          end
        else
          table.insert(freeSlots[inventoryName], slot)
        end
      end
    end
  end
end

function StorageManager.countItem(itemName, taskId)
  if inventoryCache[itemName] == nil or inventoryCache[itemName].locations == nil then return 0 end
  local locations = inventoryCache[itemName].locations
  local count = 0
  for _, slots in pairs(locations) do
    for _, amount in pairs(slots) do
      count = count + amount
    end
  end

  local locked = 0
  local itemLock = lockTable[itemName]
  if itemLock then
    locked = itemLock.total or 0
    if taskId and itemLock.tasks then
      -- Don't subtract this task's own lock
      locked = locked - (itemLock.tasks[taskId] or 0)
    end
  end

  return count - locked
end

function StorageManager.lockItem(itemName, count, taskId)
  print(itemName, count, taskId)
  if StorageManager.countItem(itemName) < count then
    return false
  end

  lockTable[itemName] = lockTable[itemName] or { total = 0, tasks = {} }
  lockTable[itemName].tasks[taskId] = (lockTable[itemName].tasks[taskId] or 0) + count
  lockTable[itemName].total = lockTable[itemName].total + count
  return true
end

function StorageManager.unlockItem(itemName, count, taskId)
  local entry = lockTable[itemName]
  if not entry or not entry.tasks[taskId] then return end

  local taskLock = entry.tasks[taskId]
  local toRemove = math.min(count, taskLock)

  entry.tasks[taskId] = taskLock - toRemove
  entry.total = entry.total - toRemove

  if entry.tasks[taskId] <= 0 then
    entry.tasks[taskId] = nil
  end

  if next(entry.tasks) == nil then
    lockTable[itemName] = nil
  end
end

function StorageManager.getLocksByTask(taskId)
  local result = {}
  for itemName, entry in pairs(lockTable) do
    local count = entry.tasks[taskId]
    if count then
      result[itemName] = count
    end
  end
  return result
end

function StorageManager.releaseAllLocks(taskId)
  for itemName, entry in pairs(lockTable) do
    if entry.tasks[taskId] then
      local count = entry.tasks[taskId]
      entry.total = entry.total - count
      entry.tasks[taskId] = nil
    end
    if next(entry.tasks) == nil then
      lockTable[itemName] = nil
    end
  end
end

function StorageManager.moveItem(itemName, count, destination, taskId)
  if inventoryCache[itemName] == nil
      or inventoryCache[itemName].locations == nil
      or StorageManager.countItem(itemName, taskId) < count
  then
    print(taskId)
    print(count, StorageManager.countItem(itemName, taskId))
    return false
  end

  local remaining = count

  -- First pull from partial stacks
  for inventoryName, slots in pairs(partialStacks[itemName] or {}) do
    for slot, _ in pairs(slots) do
      local amount = inventoryCache[itemName].locations[inventoryName][slot]
      local moveCount = math.min(amount, remaining)
      local actualMovedCount = peripheral.call(inventoryName, "pushItems", destination, slot, moveCount)
      if taskId then StorageManager.unlockItem(itemName, actualMovedCount, taskId) end
      remaining = remaining - actualMovedCount

      -- Update or remove the slot
      if actualMovedCount >= amount then
        slots[slot] = nil
        inventoryCache[itemName].locations[inventoryName][slot] = nil
      else
        slots[slot] = amount - actualMovedCount
        inventoryCache[itemName].locations[inventoryName][slot] = amount - actualMovedCount
      end

      if next(slots) == nil then
        partialStacks[itemName][inventoryName] = nil
      end
      if next(inventoryCache[itemName].locations[inventoryName]) == nil then
        inventoryCache[itemName].locations[inventoryName] = nil
      end

      if remaining == 0 then
        return true
      end
    end
  end
  print("After partial")

  -- Continue to full stacks
  for inventoryName, slots in pairs(inventoryCache[itemName].locations or {}) do
    for slot, amount in pairs(slots) do
      local moveCount = math.min(amount, remaining)
      local actualMovedCount = peripheral.call(inventoryName, "pushItems", destination, slot, moveCount)
      if taskId then StorageManager.unlockItem(itemName, actualMovedCount, taskId) end

      remaining = remaining - actualMovedCount

      -- Update or remove the slot
      if actualMovedCount >= amount then
        slots[slot] = nil
      else
        slots[slot] = amount - actualMovedCount
      end

      if next(slots) == nil then
        inventoryCache[itemName].locations[inventoryName] = nil
      end

      if remaining == 0 then
        return true
      end
    end
  end
  print("After full")

  return false
end

function StorageManager.pullItemsIn(source, sourceSlot, count)
  local itemDetail = peripheral.call(source, "getItemDetail", sourceSlot)
  if not itemDetail then return true end

  local itemName = itemDetail.name
  local remaining = count or itemDetail.count

  -- Try stacking first
  if partialStacks[itemName] then
    for inventoryName, slots in pairs(partialStacks[itemName]) do
      for slot, room in pairs(slots) do
        if remaining <= 0 then break end
        local moved = peripheral.call(inventoryName, "pullItems", source, sourceSlot, math.min(room, remaining), slot)
        if moved and moved > 0 then
          inventoryCache[itemName].locations[inventoryName][slot] =
              (inventoryCache[itemName].locations[inventoryName][slot] or 0) + moved
          partialStacks[itemName][inventoryName][slot] = partialStacks[itemName][inventoryName][slot] - moved

          if partialStacks[itemName][inventoryName][slot] <= 0 then
            partialStacks[itemName][inventoryName][slot] = nil
          end
          remaining = remaining - moved
        end
      end
    end
  end

  -- Fallback to free slots
  for inventoryName, slots in pairs(freeSlots) do
    for i = #slots, 1, -1 do
      local slot = slots[i]
      if remaining <= 0 then break end
      local moved = peripheral.call(inventoryName, "pullItems", source, sourceSlot, remaining, slot)
      if moved and moved > 0 then
        -- Update cache
        inventoryCache[itemName] = inventoryCache[itemName] or { locations = {} }
        inventoryCache[itemName].locations[inventoryName] = inventoryCache[itemName].locations[inventoryName] or {}
        inventoryCache[itemName].locations[inventoryName][slot] = moved

        -- Setup partial stack tracker if needed
        if moved < itemDetail.maxCount then
          partialStacks[itemName] = partialStacks[itemName] or {}
          partialStacks[itemName][inventoryName] = partialStacks[itemName][inventoryName] or {}
          partialStacks[itemName][inventoryName][slot] = itemDetail.maxCount - moved
        end

        -- Remove from freeSlots
        table.remove(slots, i)
        remaining = remaining - moved
      end
    end
  end

  return remaining <= 0
end

return StorageManager
