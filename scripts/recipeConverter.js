import fs from "fs/promises";
import path from "path";
const recipeDir = "C:/Users/benja/Desktop/New folder/recipes";
const tagDir = "C:/Users/benja/Desktop/New folder/tags";

async function recipesToJSON() {
  const recipeData = {};
  const files = await fs.readdir(recipeDir);
  for (const file of files) {
    const filePath = path.join(recipeDir, file);
    const recipeName = path.basename(file, ".json");
    const data = await fs.readFile(filePath, "utf8");
    recipeData[recipeName] = JSON.parse(data);
  }

  return recipeData;
}

async function tagsToJSON() {
  const tagsData = {};
  const files = await fs.readdir(tagDir);
  for (const file of files) {
    const filePath = path.join(tagDir, file);
    const tagName = path.basename(file, ".json");
    const data = await fs.readFile(filePath, "utf8");
    tagsData[tagName] = JSON.parse(data);
  }

  return tagsData;
}

recipesToJSON().then(async (recipes) => {
  await fs.writeFile("../data/recipes.json", JSON.stringify(recipes));
});

tagsToJSON().then(async (tags) => {
  await fs.writeFile("../data/tags.json", JSON.stringify(tags));
});
