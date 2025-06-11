local recipes = require("data.recipes")

local RecipeBook = {}
local maxStackSizeMap = {}

if fs.exists("data/maxStackSizeMap.txt") then
  local file = fs.open("data/maxStackSizeMap.txt", "r")
  local contents = file.readAll()
  maxStackSizeMap = textutils.unserialise(contents)
  file.close()
end


function RecipeBook.get(itemName)
  return recipes[itemName]
end

function RecipeBook.addItemToMaxStackSizeMap(itemName, maxStackSize)
  maxStackSizeMap[itemName] = maxStackSize
  local file = fs.open("data/maxStackSizeMap.txt", "w")
  file.write(textutils.serialise(maxStackSizeMap))
  file.close()
end

function RecipeBook.getMaxStackSize(itemName)
  return maxStackSizeMap[itemName]
end

return RecipeBook
