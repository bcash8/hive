return {
  ["minecraft:sticks"] = {
    output = 4,
    inputs = {
      [2] = "a",
      [6] = "a"
    },
    ingredients = {
      ["a"] = "minecraft:oak_planks"
    }
  },
  ["minecraft:oak_planks"] = {
    output = 4,
    inputs = {
      [6] = "a"
    },
    ingredients = {
      ["a"] = "minecraft:oak_log"
    }
  },
  ["minecraft:chest"] = {
    output = 1,
    inputs = {
      [1] = "a",
      [2] = "a",
      [3] = "a",
      [5] = "a",
      [7] = "a",
      [9] = "a",
      [10] = "a",
      [11] = "a",
    },
    ingredients = {
      ["a"] = "minecraft:oak_planks"
    }
  },
  ["minecraft:piston"] = {
    output = 1,
    inputs = {
      [1] = "a",
      [2] = "a",
      [3] = "a",
      [5] = "b",
      [6] = "c",
      [7] = "b",
      [9] = "b",
      [10] = "d",
      [11] = "b",
    },
    ingredients = {
      ["a"] = "minecraft:oak_planks",
      ["b"] = "minecraft:cobblestone",
      ["c"] = "minecraft:iron_ingot",
      ["d"] = "minecraft:redstone",
    }
  }
}
