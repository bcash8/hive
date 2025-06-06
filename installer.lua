local tArgs = { ... }
local targetIndex = table.find(tArgs, "-t")
local target = targetIndex and tArgs[targetIndex + 1] or "worker"

local base = "https://raw.githubusercontent.com/bcash8/hive/main/"

local targets = {
  server = {
    "core/crafter.lua",
    "core/queue.lua",
    "core/recipe.lua",
    "core/server.lua",
    "core/storage.lua",
    "data/recipes.lua",
    "data/maxStackSizeMap.txt",
    "main.lua"
  },
  worker = {
    "workers/crafter.lua",
    "workers/run.lua",
    "workers/worker.lua",
  }
}

local installDir = "hive/" .. target

if not fs.exists(installDir) then
  fs.makeDir(installDir)
end

local files = targets[target]
if not files then
  print("Unknown target: " .. target)
  return
end

for _, path in ipairs(files) do
  local dest = fs.combine(installDir, path)

  -- Ensure subdirectories exist
  local dir = fs.getDir(dest)
  if dir and not fs.exists(dir) then
    fs.makeDir(dir)
  end

  -- Download the file
  local url = base .. path
  print("Installing " .. path .. " to " .. dest)
  shell.run("wget", "-f", url, dest)
end

print("✅ Installation complete for: " .. target)
