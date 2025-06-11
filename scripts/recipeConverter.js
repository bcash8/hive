import fs from "fs/promises";
import path from "path";
const recipeDir = "C:/Users/benja/Desktop/New folder/recipes";
const tagDir = "C:/Users/benja/Desktop/New folder/tags";
const itemsFile = "C:/Users/benja/Desktop/New folder/items/items.json";

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
    const taggedTagName = `minecraft:${path.basename(file, ".json")}`;
    const data = await fs.readFile(filePath, "utf8");
    tagsData[taggedTagName] = JSON.parse(data);
  }

  return tagsData;
}

async function itemsToJSON() {
  const itemsData = {};
  const data = JSON.parse(await fs.readFile(itemsFile, "utf8"));
  for (const item of data) {
    const taggedName = `minecraft:${item.name}`;
    itemsData[taggedName] = {
      ...item,
      name: taggedName,
    };
  }

  return itemsData;
}

recipesToJSON().then(async (recipes) => {
  await fs.writeFile("../data/recipes.json", JSON.stringify(recipes));
});

tagsToJSON().then(async (tags) => {
  await fs.writeFile("../data/tags.json", JSON.stringify(tags));
});

itemsToJSON().then(async (items) => {
  await fs.writeFile("../data/items.json", JSON.stringify(items));
});
