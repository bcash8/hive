local Planner = {}

local storage = require("core.storage")
local taskQ = require("core.queue")
local recipeBook = require("core.recipe")
local machines = require("core.machineRegistry")
local maps = require("core.crafting.maps")

local function makeTask(taskId, parentId, itemName, count)
  return {
    id = taskId,
    prereqs = {},
    dependents = parentId and { parentId } or {},
    work = {
      item = itemName,
      count = count,
      recipe = nil
    }
  }
end

local function resolveTagItem(tagIngredient, countNeeded, taskId, state, visited)
  local tagName = tagIngredient:sub(5)
  local tagItems = recipeBook.getTagItems(tagName)
  for _, actualItem in ipairs(tagItems or {}) do
    local status = Planner.planRecursive(actualItem, countNeeded, taskId, state, visited)
    if status ~= "FAIL" then
      return actualItem
    end
  end
  return nil
end

local function copyVisited(visited)
  local newVisited = {}
  for k, v in pairs(visited) do
    newVisited[k] = v
  end
  return newVisited
end

---@param itemName string
---@param amount number
---@params parentId string
---@param state any
---@return string, string | nil "CRAFT,STORAGE,FAIL", error
function Planner.planRecursive(itemName, amount, parentId, state, visited)
  visited = visited or {}

  local alreadyLocked = 0
  for _, lock in pairs(state.locks) do
    if lock.itemName == itemName then
      alreadyLocked = alreadyLocked + lock.amount
    end
  end

  local available = math.max(0, storage.countItem(itemName) - alreadyLocked)
  local toCraft = math.max(0, amount - available)

  -- Lock available items (even if partial)
  if available > 0 then
    table.insert(state.locks, {
      taskId = parentId,
      itemName = itemName,
      amount = math.min(available, amount)
    })
  end

  if toCraft <= 0 then
    return "STORAGE", nil
  end

  -- Need to craft the rest
  local taskId = taskQ.generateId()
  local allRecipes = recipeBook.getRecipes(itemName)
  if not allRecipes then return "FAIL", "No recipe for item: " .. itemName end

  for _, recipeName in pairs(allRecipes) do
    local recipeType = recipeBook.getType(recipeName)
    local output = recipeBook.getOutput(recipeName)
    local ingredientsPerCraft = recipeBook.getRequiredIngredients(recipeName)
    local machineTypes = machines.getMachineTypesForRecipeType(recipeType)

    if machines.exists(recipeType) then
      for _, machineType in pairs(machineTypes) do
        local machineMeta = machines.getMachineMetadata(machineType) or {}
        local supplementalItems = machineMeta.supplementalItems or {}

        local visitKey = recipeName .. "|" .. itemName
        local branchVisited = copyVisited(visited)
        if branchVisited[visitKey] then
          return "FAIL", "Cycle detected: " .. visitKey
        end

        branchVisited[visitKey] = true

        local tempTask = makeTask(taskId, parentId, itemName, toCraft)
        tempTask.work.recipe = recipeBook.get(recipeName)
        tempTask.work.recipeName = recipeName
        tempTask.work.type = recipeType
        tempTask.work.recipe.meta = {
          output = output,
          ingredientsPerCraft = ingredientsPerCraft,
          resolvedIngredients = {},
          supplementalItems = {}
        }
        state.tasks[taskId] = tempTask

        local ok = true

        -- Ingredient Planning
        for ingredient, count in pairs(ingredientsPerCraft) do
          local resolvedName = ingredient
          local needed = math.ceil((count * toCraft) / output)

          if ingredient:sub(1, 4) == "tag:" then
            resolvedName = resolveTagItem(ingredient, needed, taskId, state, branchVisited)
            if not resolvedName then
              ok = false
              break
            end
          else
            local status = Planner.planRecursive(ingredient, needed, taskId, state, branchVisited)
            if status == "FAIL" then
              ok = false
              break
            end
          end

          tempTask.work.recipe.meta.resolvedIngredients[ingredient] = resolvedName
        end

        if ok then
          -- Supplemental Planning
          for _, supplement in ipairs(supplementalItems) do
            local supplementalItemMetadata = {}
            if supplement.item:sub(1, 4) == "map:" then
              -- Maps from the recipe book.
              local mapName = supplement.item:sub(5)
              if not maps[mapName] then
                ok = false
                break
              end
              local rankedItemList = maps[mapName](itemName, toCraft * supplement.perCraft, taskId, state, branchVisited)
              -- validate that one of the items exists
              ok = false
              for item, amount in pairs(rankedItemList) do
                local status, err = Planner.planRecursive(item, amount, taskId, state, branchVisited)
                if status ~= "FAIL" then
                  ok = true
                  supplementalItemMetadata = {
                    item = item,
                    amount = amount
                  }
                  break
                end
              end
            else
              local status = Planner.planRecursive(
                supplement.item,
                supplement.perCraft * toCraft,
                taskId,
                state,
                branchVisited
              )
              if status == "FAIL" then
                ok = false
                break
              end
              supplementalItemMetadata = {
                item = supplement.item,
                amount = supplement.perCraft
              }
            end

            tempTask.work.recipe.meta.supplementalItems[supplement.item] = supplementalItemMetadata
          end
        end


        if ok then
          table.insert(state.locks, {
            taskId = parentId,
            itemName = itemName,
            amount = toCraft
          })
          if parentId and state.tasks[parentId] then
            table.insert(state.tasks[parentId].prereqs, taskId)
          end

          return "CRAFT", nil
        else
          state.tasks[taskId] = nil
          for i = #state.locks, 1, -1 do
            if state.locks[i].taskId == taskId then
              table.remove(state.locks, i)
            end
          end
        end
      end
    end
  end

  state.tasks[taskId] = nil
  for i = #state.locks, 1, -1 do
    if state.locks[i].taskId == taskId then
      table.remove(state.locks, i)
    end
  end
  return "FAIL", "No valid recipe/machine path found for item: " .. itemName
end

return Planner
