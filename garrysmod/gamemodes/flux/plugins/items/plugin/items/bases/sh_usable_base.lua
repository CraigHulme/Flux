--[[
  Flux © 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

-- Alternatively, you can use item.CreateBase("CItemUsable")
class "CItemUsable" extends "CItem"

CItemUsable.Name = "Usable Items Base"
CItemUsable.Description = "An item that can be used."

-- Returns:
-- nothing/nil = removes item from the inventory as soon as it's used.
-- false = prevents item from being used at all.
-- true = prevents item from being removed upon use.
function CItem:OnUse(player) end

ItemUsable = CItemUsable
