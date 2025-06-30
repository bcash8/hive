local json = require("packages.json")

local RecipeBook = {}
local items = {}
local recipes = {}
local itemRecipes = {}
local tags = {}

if fs.exists("hive/data/items.json") then
  local file = fs.open("hive/data/items.json", "r")
  local contents = file.readAll()
  items = json.decode(contents)
  file.close()
else
  error("Missing hive/data/items.json file.")
end

if fs.exists("hive/data/recipes.json") then
  local file = fs.open("hive/data/recipes.json", "r")
  local contents = file.readAll()
  recipes = json.decode(contents)
  file.close()
else
  error("Missing hive/data/recipes.json file.")
end

if fs.exists("hive/data/tags.json") then
  local file = fs.open("hive/data/tags.json", "r")
  local contents = file.readAll()
  tags = json.decode(contents)
  file.close()
else
  error("Missing hive/data/tags.json file.")
end

if fs.exists("hive/data/recipePriority.json") then
  local file = fs.open("hive/data/recipePriority.json", "r")
  local contents = file.readAll()
  itemRecipes = json.decode(contents)
  file.close()
else
  error("Missing hive/data/recipePriority.json file.")
end

local function deepCopy(tbl)
  if type(tbl) ~= "table" then return tbl end
  local copy = {}
  for k, v in pairs(tbl) do
    copy[k] = deepCopy(v)
  end
  return copy
end

function RecipeBook.getRecipes(itemName)
  return deepCopy(itemRecipes[itemName])
end

function RecipeBook.get(recipeName)
  return deepCopy(recipes[recipeName])
end

function RecipeBook.getType(recipeName)
  local recipe = recipes[recipeName]
  if not recipe then error("Unknown recipe: " .. recipeName) end
  return recipe.type
end

function RecipeBook.addItemToItemsMap(item)
  items[item.name] = {
    name = item.name,
    displayName = item.displayName,
    stackSize = item.maxCount
  }
  local file = fs.open("hive/server/data/items.json", "w")
  file.write(json.encode(items))
  file.close()
end

function RecipeBook.getStackSize(itemName)
  if not items[itemName] then return nil end
  return items[itemName].stackSize
end

-- Required Ingredients

local function shapedCraftingRequiredIngredients(recipe)
  local counts = {}
  local symbolCount = {}
  for _, row in ipairs(recipe.pattern) do
    for i = 1, #row do
      local symbol = row:sub(i, i)
      if symbol ~= " " then
        symbolCount[symbol] = (symbolCount[symbol] or 0) + 1
      end
    end
  end

  for symbol, count in pairs(symbolCount) do
    local key = recipe.key[symbol]
    if key then
      local item = key.item or (key.tag and ("tag:" .. key.tag))
      if item then
        counts[item] = (counts[item] or 0) + count
      end
    end
  end

  return counts
end

local function smeltingRequiredIngredients(recipe)
  local counts = {}
  local item = recipe.ingredient.item or (recipe.ingredient.tag and ("tag:" .. recipe.ingredient.tag))
  counts[item] = 1
  return counts
end

local function shapelessCraftingRequiredIngredients(recipe)
  local counts = {}
  for _, ingredient in pairs(recipe.ingredients) do
    local item = ingredient.item or (ingredient.tag and ("tag:" .. ingredient.tag))
    counts[item] = 1
  end
  return counts
end

function RecipeBook.getRequiredIngredients(recipeName)
  local recipe = RecipeBook.get(recipeName)
  if not recipe then error("Unknown recipe: " .. recipeName) end

  local ingredients = nil

  if recipe.type == "minecraft:crafting_shaped" then
    ingredients = shapedCraftingRequiredIngredients(recipe)
  elseif
      recipe.type == "minecraft:smelting"
      or recipe.type == "minecraft:blasting"
      or recipe.type == "minecraft:smelting"
  then
    ingredients = smeltingRequiredIngredients(recipe)
  elseif recipe.type == "minecraft:crafting_shapeless" then
    ingredients = shapelessCraftingRequiredIngredients(recipe)
  else
    error("Unknown recipe type: " .. recipe.type)
  end

  return deepCopy(ingredients)
end

-- Outputs

function RecipeBook.getOutput(recipeName)
  local recipe = RecipeBook.get(recipeName)
  if not recipe then error("Unknown recipe: " .. recipeName) end

  if recipe.count then return recipe.count end
  if recipe.result then return recipe.result.count or 1 end

  error("Unknown output amount: " .. recipeName)
end

-- Tags
function RecipeBook.getTagItems(tagName)
  local items = tags[tagName]
  if not items then error("Missing items for tag: " .. tagName) end
  return items.values
end

return RecipeBook
