local player_meta = FindMetaTable("Player")

function player_meta:SavePlayer()
  local saveData = {
    steamID = self:SteamID(),
    name = self:name(),
    joinTime = self.flJoinTime or os.time(),
    lastPlayTime = os.time(),
    data = fl.serialize(self:get_data())
  }

  hook.Run("SavePlayerData", self, saveData)

  fl.db:EasyWrite("fl_players", {"steamID", self:SteamID()}, saveData)
end

function player_meta:set_data(data)
  self:SetNetVar("flData", data or {})
end

function player_meta:SetPlayerData(key, value)
  local data = self:get_data()

  data[key] = value

  self:set_data(data)
end

function player_meta:GetPlayerData(key, default)
  local data = self:get_data()

  return data[key] or default
end

function player_meta:SetInitialized(bIsInitialized)
  if (bIsInitialized == nil) then bIsInitialized = true end

  self:SetDTBool(BOOL_INITIALIZED, bIsInitialized)
end

function player_meta:Notify(message)
  fl.player:Notify(self, message)
end

function player_meta:GetAmmoTable()
  local ammoTable = {}

  for k, v in pairs(game.GetAmmoList()) do
    local ammoCount = self:GetAmmoCount(k)

    if (ammoCount > 0) then
      ammoTable[k] = ammoCount
    end
  end

  return ammoTable
end

function player_meta:RestorePlayer()
  fl.db:EasyRead("fl_players", {"steamID", self:SteamID()}, function(result, hasData)
    if (hasData) then
      result = result[1]

      if (result.data) then
        self:set_data(fl.deserialize(result.data))
      end

      if (result.joinTime) then
        self.flJoinTime = result.joinTime
      end

      if (result.lastPlayTime) then
        self.flLastPlayTime = result.lastPlayTime
      end

      hook.Run("RestorePlayer", self, result)
    else
      ServerLog(self:name().." has joined for the first time!")

      self:SavePlayer()
    end

    hook.Run("OnPlayerRestored", self)
  end)
end