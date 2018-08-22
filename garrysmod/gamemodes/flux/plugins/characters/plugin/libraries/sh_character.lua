﻿--[[
  Derpy © 2018 TeslaCloud Studios
  Do not use, re-distribute or share unless authorized.
--]]library.New "character"

local stored = character.stored or {}
character.stored = stored

function character.Create(player, data)
  if (!isstring(data.name) or (data.name:utf8len() < config.Get("character_min_name_len")
    or data.name:utf8len() > config.Get("character_max_name_len"))) then
    return CHAR_ERR_NAME
  end

  if (!isstring(data.physDesc) or (data.physDesc:utf8len() < config.Get("character_min_desc_len")
    or data.physDesc:utf8len() > config.Get("character_max_desc_len"))) then
    return CHAR_ERR_DESC
  end

  if (!isnumber(data.gender) or (data.gender < CHAR_GENDER_MALE or data.gender > CHAR_GENDER_NONE)) then
    return CHAR_ERR_GENDER
  end

  if (!isstring(data.model) or data.model == "") then
    return CHAR_ERR_MODEL
  end

  local hooked, result = hook.Run("PlayerCreateCharacter", player, data)

  if (hooked == false) then
    return result or CHAR_ERR_UNKNOWN
  end

  local steamID = player:SteamID()

  stored[steamID] = stored[steamID] or {}

  data.id = #stored[steamID] + 1

  table.insert(stored[steamID], data)

  if (SERVER) then
    local charID = #stored[steamID]

    hook.Run("PostCreateCharacter", player, charID, data)

    character.Save(player, charID)
  end

  return CHAR_SUCCESS
end

if (SERVER) then
  function character.Load(player)
    local steamID = player:SteamID()

    stored[steamID] = stored[steamID] or {}

    fl.db:EasyRead("fl_characters", {"steamID", steamID}, function(result, hasData)
      if (hasData) then
        for k, v in ipairs(result) do
          local charID = tonumber(v.id) or k

          stored[steamID][charID] = {
            steamID = steamID,
            name = v.name,
            physDesc = v.physDesc,
            inventory = util.JSONToTable(v.inventory or ""),
            ammo = util.JSONToTable(v.ammo or ""),
            money = tonumber(v.money or "0"),
            charPermissions = util.JSONToTable(v.charPermissions or ""),
            data = util.JSONToTable(v.data or ""),
            id = tonumber(v.id or k),
            key = v.key
          }

          hook.Run("RestoreCharacter", player, charID, v)
        end
      end

      character.SendToClient(player)

      hook.Run("PostRestoreCharacters", player)
    end)
  end

  function character.SendToClient(player)
    netstream.Start(player, "fl_loadcharacters", stored[player:SteamID()])
  end

  function character.ToSaveable(player, char)
    if (!IsValid(player) or !char) then return end

    return {
      steamID = player:SteamID(),
      name = char.name,
      physDesc = char.physDesc or "This character has no physical description set!",
      model = char.model or "models/humans/group01/male_02.mdl",
      inventory = util.TableToJSON(char.inventory),
      ammo = util.TableToJSON(player:GetAmmoTable()),
      money = char.money,
      charPermissions = util.TableToJSON(char.charPermissions),
      data = util.TableToJSON(char.data),
      id = char.id
    }
  end

  function character.Save(player, index)
    if (!IsValid(player) or !isnumber(index) or hook.Run("PreSaveCharacter", player, index) == false) then return end

    local char = stored[player:SteamID()][index]
    local saveData = character.ToSaveable(player, char)

    hook.Run("SaveCharaterData", player, char, saveData)

    fl.db:EasyWrite("fl_characters", {"id", index}, saveData)

    hook.Run("PostSaveCharacter", player, char, saveData)
  end

  function character.SaveAll(player)
    if (!IsValid(player)) then return end

    for k, v in ipairs(stored[player:SteamID()]) do
      character.Save(player, k)
    end
  end

  function character.Get(player, index)
    local steamID = player:SteamID()

    if (stored[steamID][index]) then
      return stored[steamID][index]
    end
  end

  function character.SetName(player, index, newName)
    local char = character.Get(player, index)

    if (char) then
      char.name = newName or char.name

      player:SetNetVar("name", char.name)

      character.Save(player, index)
    end
  end

  function character.SetModel(player, index, model)
    local char = character.Get(player, index)

    if (char) then
      char.model = model or char.model

      player:SetNetVar("model", char.model)
      player:SetModel(char.model)

      character.Save(player, index)
    end
  end
else
  netstream.Hook("fl_loadcharacters", function(data)
    stored[fl.client:SteamID()] = stored[fl.client:SteamID()] or {}
    stored[fl.client:SteamID()] = data
  end)
end

if (SERVER) then
  netstream.Hook("CreateCharacter", function(player, data)
    data.gender  = (data.gender and data.gender == "Female" and CHAR_GENDER_FEMALE) or CHAR_GENDER_MALE
    data.physDesc = data.description

    local status = character.Create(player, data)

    fl.DevPrint("Creating character. Status: "..status)

    if (status == CHAR_SUCCESS) then
      character.SendToClient(player)
      netstream.Start(player, "PlayerCreatedCharacter", true, status)

      fl.DevPrint("Success")
    else
      netstream.Start(player, "PlayerCreatedCharacter", false, status)

      fl.DevPrint("Error")
    end
  end)

  netstream.Hook("PlayerSelectCharacter", function(player, id)
    fl.DevPrint(player:Name().." has loaded character #"..id)

    player:SetActiveCharacter(id)
  end)
end

do
  local player_meta = FindMetaTable("Player")

  function player_meta:GetActiveCharacterID()
    return self:GetNetVar("ActiveCharacter", nil)
  end

  function player_meta:GetCharacterKey()
    return self:GetNetVar("key", -1)
  end

  function player_meta:CharacterLoaded()
    if (self:IsBot()) then return true end

    local id = self:GetActiveCharacterID()

    return id and id > 0
  end

  function player_meta:GetInventory()
    return self:GetNetVar("inventory", {})
  end

  function player_meta:GetPhysDesc()
    return self:GetNetVar("physDesc", "This character has no description!")
  end

  function player_meta:GetCharacterVar(id, default)
    if (SERVER) then
      return self:GetCharacter()[id] or default
    else
      return self:GetNetVar(id, default)
    end
  end

  function player_meta:GetCharacterData(key, default)
    return self:GetCharacterVar("data", {})[key] or default
  end

  function player_meta:GetCharacter()
    local charID = self:GetActiveCharacterID()

    if (charID) then
      return stored[self:SteamID()][charID]
    end

    if (self:IsBot()) then
      self.charData = self.charData or {}

      return self.charData
    end
  end

  function player_meta:GetAllCharacters()
    return stored[self:SteamID()] or {}
  end
end
