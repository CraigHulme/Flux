local COMMAND = Command.new('giveitem')
COMMAND.name = 'GiveItem'
COMMAND.description = 'Gives specified item to a player.'
COMMAND.syntax = '<string target> <string item name or unique ID>'
COMMAND.category = 'character_management'
COMMAND.arguments = 2
COMMAND.player_arg = 1
COMMAND.aliases = { 'chargiveitem', 'plygiveitem' }

function COMMAND:on_run(player, targets, itemName, amount)
  local item_table = item.Find(itemName)

  if item_table then
    amount = tonumber(amount) or 1

    for k, v in ipairs(targets) do
      for i = 1, amount do
        v:GiveItem(item_table.id)
      end

      fl.player:notify(v, (get_player_name(player))..' has given you '..amount..' '..item_table.name.."'s.")
    end

    fl.player:notify(player, 'You have given '..amount..' '..item_table.name.."'s to "..util.player_list_to_string(targets)..'.')
  else
    fl.player:notify(player, "'"..itemName.."' is not a valid item!")
  end
end

COMMAND:register()
