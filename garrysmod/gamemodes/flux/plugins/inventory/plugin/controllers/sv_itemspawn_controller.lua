mvc.handler("SpawnMenu::SpawnItem", function(player, itemID)
  if (!player:can("spawn_items")) then
    player:notify(L("Err_No_Permission", player:Name()))

    return
  end

  local itemTable = item.New(itemID)

  if (itemTable) then
    local trace = player:GetEyeTraceNoCursor()

    item.Spawn(trace.HitPos, nil, itemTable)
  end
end)