local Maps = {}

function Maps.fuel(itemName, totalBurnNeeded, taskId, state, visited)
  local fuels = {
    ["minecraft:coal"] = 1600,
    ["minecraft:charcoal"] = 1600,
  }

  local fuelOptions = {}

  for fuelName, burnTime in pairs(fuels) do
    local amountNeeded = math.ceil(totalBurnNeeded / burnTime)
    local totalBurn = amountNeeded * burnTime
    local waste = totalBurn - totalBurnNeeded

    table.insert(fuelOptions, {
      item = fuelName,
      amount = amountNeeded,
      waste = waste,
    })
  end

  table.sort(fuelOptions, function(a, b)
    return a.waste < b.waste
  end)

  local result = {}
  for _, option in ipairs(fuelOptions) do
    result[option.item] = option.amount
  end

  return result
end

return Maps
