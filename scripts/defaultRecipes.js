import fs from "fs/promises";

const preferedTypeOrder = [
  "minecraft:crafting_shapeless",
  "minecraft:crafting_shaped",
  "minecraft:blasting",
  "minecraft:smoking",
  "minecraft:smelting",
];

async function main() {
  const data = JSON.parse(await fs.readFile("../data/recipes.json"));
  const groupedRecipes = groupRecipesByOutput(data);

  const prioritizedRecipes = {};
  for (const [outputName, recipes] of Object.entries(groupedRecipes)) {
    const sorted = recipes.sort(sortRecipe);
    const names = sorted.map((recipe) => recipe.recipeName);
    prioritizedRecipes[outputName] = names;
  }

  return prioritizedRecipes;
}

function groupRecipesByOutput(data) {
  const groupedRecipes = {};
  for (const [recipeName, recipe] of Object.entries(data)) {
    let resultItem = "";
    if (typeof recipe.result === "object") {
      if (recipe.result.item === undefined)
        throw error("Missing item for " + recipeName);
      resultItem = recipe.result.item;
    } else {
      resultItem = recipe.result;
    }
    groupedRecipes[resultItem] = groupedRecipes[resultItem] || [];
    groupedRecipes[resultItem].push({ ...recipe, recipeName });
  }

  return groupedRecipes;
}

function sortRecipe(recipeA, recipeB) {
  // First sort by type
  const typeIndexA = preferedTypeOrder.indexOf(recipeA.type);
  const typeIndexB = preferedTypeOrder.indexOf(recipeB.type);

  if (typeIndexA !== typeIndexB) return typeIndexA - typeIndexB;

  // Step 2: Prefer recipes with fewer unique ingredients
  const ingredientCountA = Object.keys(recipeA.ingredients || {}).length;
  const ingredientCountB = Object.keys(recipeB.ingredients || {}).length;
  if (ingredientCountA !== ingredientCountB) {
    return ingredientCountA - ingredientCountB;
  }

  // Step 3: Prefer higher output
  const outputA = extractRecipeOutput(recipeA);
  const outputB = extractRecipeOutput(recipeB);
  if (outputA !== outputB) {
    return outputB - outputA;
  }

  // If the recipes are equivelent sort alphabetically by name
  return recipeA.recipeName.localeCompare(recipeB.recipeName);
}

function extractRecipeOutput(recipe) {
  if (typeof recipe.result === "object") return recipe.result.count;
  if (typeof recipe.count === "number") return recipe.count;
  return 1;
}

main().then((recipes) => {
  fs.writeFile("../data/recipePriority.json", JSON.stringify(recipes));
});
