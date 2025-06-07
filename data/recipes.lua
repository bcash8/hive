return {
  ["minecraft:stick"] = {
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
  ["minecraft:iron_pickaxe"] = {
    output = 1,
    inputs = {
      [1] = "a",
      [2] = "a",
      [3] = "a",
      [6] = "b",
      [10] = "b",
    },
    ingredients = {
      ["a"] = "minecraft:iron_ingot",
      ["b"] = "minecraft:stick",
    }
  },
  ["minecraft:tripwire_hook"] = {
    output = 2,
    inputs = {
      [1] = "a",
      [5] = "b",
      [9] = "c",
    },
    ingredients = {
      ["a"] = "minecraft:iron_ingot",
      ["b"] = "minecraft:stick",
      ["c"] = "minecraft:oak_planks",
    }
  },
  ["minecraft:trapped_chest"] = {
    output = 1,
    inputs = {
      [1] = "a",
      [2] = "b",
    },
    ingredients = {
      ["a"] = "minecraft:tripwire_hook",
      ["b"] = "minecraft:chest"
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
  },
  ["minecraft:hopper"] = {
    output = 1,
    inputs = {
      [1] = "a",
      [3] = "a",
      [5] = "a",
      [6] = "b",
      [7] = "a",
      [10] = "a",
    },
    ingredients = {
      ["a"] = "minecraft:iron_ingot",
      ["b"] = "minecraft:chest",
    }
  },
  ["minecraft:minecart"] = {
    output = 1,
    inputs = {
      [1] = "a",
      [3] = "a",
      [5] = "a",
      [6] = "a",
      [7] = "a",
    },
    ingredients = {
      ["a"] = "minecraft:iron_ingot",
    }
  },
  ["minecraft:hopper_minecart"] = {
    output = 1,
    inputs = {
      [1] = "a",
      [5] = "b",
    },
    ingredients = {
      ["a"] = "minecraft:hopper",
      ["b"] = "minecraft:minecart",
    }
  },
  ["minecraft:bow"] = {
    output = 1,
    inputs = {
      [2] = "a",
      [3] = "b",
      [5] = "a",
      [7] = "b",
      [10] = "a",
      [11] = "b",
    },
    ingredients = {
      ["a"] = "minecraft:stick",
      ["b"] = "minecraft:string",
    }
  },
  ["minecraft:dispenser"] = {
    output = 1,
    inputs = {
      [1] = "a",
      [2] = "a",
      [3] = "a",
      [5] = "a",
      [6] = "b",
      [7] = "a",
      [9] = "a",
      [10] = "c",
      [11] = "a",
    },
    ingredients = {
      ["a"] = "minecraft:cobblestone",
      ["b"] = "minecraft:bow",
      ["c"] = "minecraft:redstone",
    }
  },
}
