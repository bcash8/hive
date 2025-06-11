local json = require("packages.json")

local RecipeBook = {}
local items = {}
local recipes = {}
local tags = {}

if fs.exists("data/items.json") then
  local file = fs.open("data/items.json", "r")
  local contents = file.readAll()
  items = json.decode(contents)
  file.close()
else
  error("Missing data/items.json file.")
end

if fs.exists("data/recipes.json") then
  local file = fs.open("data/recipes.json", "r")
  local contents = file.readAll()
  recipes = json.decode(contents)
  file.close()
else
  error("Missing data/recipes.json file.")
end

if fs.exists("data/tags.json") then
  local file = fs.open("data/tags.json", "r")
  local contents = file.readAll()
  tags = json.decode(contents)
  file.close()
else
  error("Missing data/tags.json file.")
end

function RecipeBook.get(itemName)
  return recipes[itemName]
end

function RecipeBook.addItemToItemsMap(item)
  items[item.name] = {
    name = item.name,
    displayName = item.displayName,
    stackSize = item.maxCount
  }
  local file = fs.open("data/items.json", "w")
  file.write(json.encode(items))
  file.close()
end

function RecipeBook.getMaxStackSize(itemName)
  return items[itemName].stackSize
end

return RecipeBook
