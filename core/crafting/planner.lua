local Planner = {}

local storage = require("core.storage")
local taskQ = require("core.queue")
local recipeBook = require("core.recipe")
local machines = require("core.machines")

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
  local task = {
    id = taskId,
    prereqs = {},
    dependents = { parentId },
    work = {
      item = itemName,
      count = toCraft,
      recipe = nil -- We will set this to the recipe that is picked further down
    }
  }

  state.tasks[taskId] = task

  local allRecipes = recipeBook.getRecipes(itemName)
  if not allRecipes then
    state.tasks[taskId] = nil
    return "FAIL", "No recipe for item: " .. itemName
  end

  local recipesWithAvailableMachines = {}
  for _, recipeName in pairs(allRecipes) do
    local recipeType = recipeBook.getType(recipeName)
    if machines.exists(recipeType) then
      table.insert(recipesWithAvailableMachines, recipeName)
    end
  end

  -- Loop through the recipes for this item to see if any can be crafted.
  for _, recipeName in pairs(recipesWithAvailableMachines) do
    local pathVisited = {}
    for k, v in pairs(visited) do
      pathVisited[k] = v
    end

    -- Use recipeName + itemName to identify the unique path
    local visitKey = recipeName .. "|" .. itemName
    if pathVisited[visitKey] then
      state.tasks[taskId] = nil
      return "FAIL", "Cycle detected for recipe: " .. recipeName
    end
    pathVisited[visitKey] = true
    local output = recipeBook.getOutput(recipeName)
    local ingredientsPerCraft = recipeBook.getRequiredIngredients(recipeName)
    local recipeOk = true
    local resolvedIngredients = {}
    for ingredient, count in pairs(ingredientsPerCraft) do
      -- Handle tags
      if ingredient:sub(1, 4) == "tag:" then
        local tagName = ingredient:sub(5)
        local tagItems = recipeBook.getTagItems(tagName)
        local tagResolved = false
        for _, actualItem in ipairs(tagItems or {}) do
          local ingredientsNeeded = math.ceil((count * toCraft) / output)
          local status, err = Planner.planRecursive(actualItem, ingredientsNeeded, taskId, state, pathVisited)
          if status ~= "FAIL" then
            resolvedIngredients[ingredient] = actualItem
            tagResolved = true
            break
          end
        end

        if not tagResolved then
          recipeOk = false
          break
        end
      else
        local ingredientsNeeded = math.ceil((count * toCraft) / output)
        local status, err = Planner.planRecursive(ingredient, ingredientsNeeded, taskId, state, pathVisited)
        if status == "FAIL" then
          recipeOk = false
          -- print("Crafting failed for " .. recipeName .. " " .. err)
          break
        end
        resolvedIngredients[ingredient] = ingredient
      end
    end

    if recipeOk then
      -- Lock the to-be crafted items for the parent
      table.insert(state.locks, {
        taskId = parentId,
        itemName = itemName,
        amount = toCraft
      })

      task.work.recipe = recipeBook.get(recipeName)
      task.work.recipe.meta = {
        output = output,
        ingredientsPerCraft = ingredientsPerCraft,
        resolvedIngredients = resolvedIngredients
      }
      task.work.recipeName = recipeName
      task.work.type = recipeBook.getType(recipeName)

      -- Link this task to its parent
      if parentId and state.tasks[parentId] then
        table.insert(state.tasks[parentId].prereqs, taskId)
      end
      return "CRAFT", nil
    end
  end

  state.tasks[taskId] = nil
  return "FAIL", "No possible recipe for: " .. itemName
end

return Planner
