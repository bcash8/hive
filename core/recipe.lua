local RecipeBook = {}
local recipes = require("data.recipes")
function RecipeBook.get(itemName)
  return recipes[itemName]
end

return RecipeBook
