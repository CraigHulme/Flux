--[[
  Flux © 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

library.New("admin", fl)

local groups = fl.admin.groups or {}
fl.admin.groups = groups

local permissions = fl.admin.permissions or {}
fl.admin.permissions = permissions

local players = fl.admin.players or {}
fl.admin.players = players

local bans = fl.admin.bans or {}
fl.admin.bans = bans

local compilerCache = {}

function fl.admin:GetPermissions()
  return permissions
end

function fl.admin:GetGroups()
  return groups
end

function fl.admin:GetPlayers()
  return players
end

function fl.admin:GetBans()
  return bans
end

function fl.admin:CreateGroup(id, data)
  if (!isstring(id)) then return end

  data.id = id

  if (data.Base) then
    local parent = groups[data.Base]

    if (parent) then
      local parentCopy = table.Copy(parent)

      table.Merge(parentCopy.Permissions, data.Permissions)

      data.Permissions = parentCopy.Permissions

      for k, v in pairs(parentCopy) do
        if (k == "Permissions") then continue end

        if (!data[k]) then
          data[k] = v
        end
      end
    end
  end

  if (!groups[id]) then
    groups[id] = data
  end
end

function fl.admin:AddPermission(id, category, data, bForce)
  if (!id) then return end

  category = category or "general"
  data.id = id
  permissions[category] = permissions[category] or {}

  if (!permissions[category][id] or bForce) then
    permissions[category][id] = data
  end
end

function fl.admin:RegisterPermission(id, name, description, category)
  if (!isstring(id) or id == "") then return end

  local data = {}
    data.id = id:MakeID()
    data.Description = description or "No description provided."
    data.Category = category or "general"
    data.Name = name or id
  self:AddPermission(id, category, data, true)
end

function fl.admin:PermissionFromCommand(cmdObj)
  if (!cmdObj) then return end

  self:RegisterPermission(cmdObj.id, cmdObj.Name, cmdObj.Description, cmdObj.Category)
end

function fl.admin:CheckPermission(player, permission)
  local playerPermissions = players[player:SteamID()]

  if (playerPermissions) then
    return playerPermissions[permission]
  end
end

function fl.admin:GetPermissionsInCategory(category)
  local perms = {}

  if (category == "all") then
    for k, v in pairs(permissions) do
      for k2, v2 in pairs(v) do
        table.insert(perms, k2)
      end
    end
  else
    if (permissions[category]) then
      for k, v in pairs(permissions[category]) do
        table.insert(perms, k)
      end
    end
  end

  return perms
end

function fl.admin:IsCategory(id)
  if (id == "all" or permissions[id]) then
    return true
  end

  return false
end

function fl.admin:GetGroupPermissions(id)
  if (groups[id]) then
    return groups[id].Permissions
  else
    return {}
  end
end

function fl.admin:HasPermission(player, permission)
  if (!IsValid(player)) then return true end
  if (player:IsRoot()) then return true end

  local steamID = player:SteamID()

  if (players[steamID] and (players[steamID][permission] or players[steamID]["all"])) then
    return true
  end

  local netPerms = player:GetNetVar("flPermissions", {})

  if (netPerms and netPerms[permission]) then
    return true
  end

  return false
end

function fl.admin:FindGroup(id)
  if (groups[id]) then
    return groups[id]
  end

  return nil
end

function fl.admin:GroupExists(id)
  return self:FindGroup(id)
end

function fl.admin:CheckImmunity(player, target, canBeEqual)
  if (!IsValid(player) or !IsValid(target)) then
    return true
  end

  local group1 = self:FindGroup(player:GetUserGroup())
  local group2 = self:FindGroup(target:GetUserGroup())

  if (!isnumber(group1.Immunity) or !isnumber(group2.Immunity)) then
    return true
  end

  if (group1.Immunity > group2.Immunity) then
    return true
  end

  if (canBeEqual and group1.Immunity == group2.Immunity) then
    return true
  end

  return false
end

pipeline.Register("group", function(uniqueID, fileName, pipe)
  GROUP = Group(uniqueID)

  util.Include(fileName)

  GROUP:Register() GROUP = nil
end)

function fl.admin:IncludeGroups(directory)
  pipeline.IncludeDirectory("group", directory)
end

if (SERVER) then
  local function SetPermission(steamID, permID, value)
    players[steamID] = players[steamID] or {}
    players[steamID][permID] = value
  end

  local function DeterminePermission(steamID, permID, value)
    local permTable = compilerCache[steamID]

    permTable[permID] = permTable[permID] or PERM_NO

    if (value == PERM_NO) then return end
    if (permTable[permID] == PERM_ALLOW_OVERRIDE) then return end

    if (value == PERM_ALLOW_OVERRIDE) then
      permTable[permID] = PERM_ALLOW_OVERRIDE
      SetPermission(steamID, permID, true)

      return
    end

    if (permTable[permID] == PERM_NEVER) then return end
    if (permTable[permID] == value) then return end

    if (value == PERM_NEVER) then
      permTable[permID] = PERM_NEVER
      SetPermission(steamID, permID, false)

      return
    elseif (value == PERM_ALLOW) then
      permTable[permID] = PERM_ALLOW
      SetPermission(steamID, permID, true)

      return
    end

    permTable[permID] = PERM_ERROR
    SetPermission(steamID, permID, false)
  end

  local function DetermineCategory(steamID, permID, value)
    if (fl.admin:IsCategory(permID)) then
      local catPermissions = fl.admin:GetPermissionsInCategory(permID)

      for k, v in ipairs(catPermissions) do
        DeterminePermission(steamID, v, value)
      end
    else
      DeterminePermission(steamID, permID, value)
    end
  end

  function fl.admin:CompilePermissions(player)
    if (!IsValid(player)) then return end

    local steamID = player:SteamID()
    local userGroup = player:GetUserGroup()
    local secondaryGroups = player:GetSecondaryGroups()
    local playerPermissions = player:GetCustomPermissions()
    local groupPermissions = self:GetGroupPermissions(userGroup)

    compilerCache[steamID] = {}

    for k, v in pairs(groupPermissions) do
      DetermineCategory(steamID, k, v)
    end

    for _, group in ipairs(secondaryGroups) do
      local permTable = self:GetGroupPermissions(group)

      for k, v in pairs(permTable) do
        DetermineCategory(steamID, k, v)
      end
    end

    for k, v in pairs(playerPermissions) do
      DetermineCategory(steamID, k, v)
    end

    local extras = {}

    hook.Run("OnPermissionsCompiled", player, extras)

    if (istable(extras)) then
      for id, extra in pairs(extras) do
        for k, v in pairs(extra) do
          DeterminePermissions(steamID, k, v)
        end
      end
    end

    player:SetPermissions(players[steamID])
    compilerCache[steamID] = nil
  end

  -- INTERNAL
  function fl.admin:AddBan(steamID, name, banTime, unbanTime, duration, reason)
    bans[steamID] = {
      steamID = steamID,
      name = name,
      unbanTime = unbanTime,
      banTime = banTime,
      duration = duration,
      reason = reason
    }
  end

  function fl.admin:Ban(player, duration, reason, bPreventKick)
    if (!isstring(player) and !IsValid(player)) then return end

    duration = duration or 0
    reason = reason or "N/A"

    local steamID = player
    local name = steamID

    if (!isstring(player) and IsValid(player)) then
      name = player:SteamName()
      steamID = player:SteamID()

      if (!bPreventKick) then
        player:Kick("You have been banned: "..tostring(reason))
      end
    end

    self:AddBan(steamID, name, os.time(), os.time() + duration, duration, reason)
    fl.db:EasyWrite("fl_bans", {"steamID", steamID}, bans[steamID])
  end

  function fl.admin:RemoveBan(steamID)
    if (bans[steamID]) then
      local copy = table.Copy(bans[steamID])
      bans[steamID] = nil

      local query = fl.db:Delete("fl_bans")
        query:Where("steamID", steamID)
      query:Execute()

      return true, copy
    end

    return false
  end
end

do
  -- Translations of words into seconds.
  local tokens = {
    second = 1,
    sec = 1,
    minute = 60,
    min = 60,
    hour = 60 * 60,
    day = 60 * 60 * 24,
    week = 60 * 60 * 24 * 7,
    month = 60 * 60 * 24 * 30,
    mon = 60 * 60 * 24 * 30,
    year = 60 * 60 * 24 * 365,
    yr = 60 * 60 * 24 * 365,
    permanently = 0,
    perma = 0,
    perm = 0,
    pb = 0,
    forever = 0,
    moment = 1
  }

  local numTokens = {
    one = 1,
    two = 2,
    three = 3,
    four = 4,
    five = 5,
    six = 6,
    seven = 7,
    eight = 8,
    nine = 9,
    ten = 10,
    few = 5,
    couple = 2,
    bunch = 120,
    lot = 1000000,
    dozen = 12,
    noscope = 420
  }

  function fl.admin:InterpretBanTime(str)
    if (isnumber(str)) then return str * 60 end
    if (!isstring(str)) then return false end

    str = str:RemoveTextFromEnd(" ")
    str = str:RemoveTextFromStart(" ")
    str = str:Replace("'", "")
    str = str:lower()

    -- A regular number was entered?
    if (tonumber(str)) then
      return tonumber(str) * 60
    end

    str = str:Replace("-", "")

    local exploded = string.Explode(" ", str)
    local result = 0
    local token, num = "", 0

    for k, v in ipairs(exploded) do
      local n = tonumber(v)

      if (isstring(v)) then
        v = v:RemoveTextFromEnd("s")
      end

      if (!n and !tokens[v] and !numTokens[v]) then continue end

      if (n) then
        num = n
      elseif (isstring(v)) then
        v = v:RemoveTextFromEnd("s")

        local ntok = numTokens[v]

        if (ntok) then
          num = ntok

          continue
        end

        local tok = tokens[v]

        if (tok) then
          if (tok == 0) then
            return 0
          else
            result = result + (tok * num)
          end
        end

        token, num = "", 0
      else
        token, num = "", 0
      end
    end

    return result
  end
end

do
  -- Flags
  fl.admin:RegisterPermission("physgun", "Access Physgun", "Grants access to the physics gun.", "flags")
  fl.admin:RegisterPermission("toolgun", "Access Tool Gun", "Grants access to the tool gun.", "flags")
  fl.admin:RegisterPermission("spawn_props", "Spawn Props", "Grants access to spawn props.", "flags")
  fl.admin:RegisterPermission("spawn_chairs", "Spawn Chairs", "Grants access to spawn chairs.", "flags")
  fl.admin:RegisterPermission("spawn_vehicles", "Spawn Vehicles", "Grants access to spawn vehicles.", "flags")
  fl.admin:RegisterPermission("spawn_entities", "Spawn All Entities", "Grants access to spawn any entity.", "flags")
  fl.admin:RegisterPermission("spawn_npcs", "Spawn NPCs", "Grants access to spawn NPCs.", "flags")
  fl.admin:RegisterPermission("spawn_ragdolls", "Spawn Ragdolls", "Grants access to spawn ragdolls.", "flags")
  fl.admin:RegisterPermission("spawn_sweps", "Spawn SWEPs", "Grants access to spawn scripted weapons.", "flags")
  fl.admin:RegisterPermission("physgun_freeze", "Freeze Protected Entities", "Grants access to freeze protected entities.", "flags")
  fl.admin:RegisterPermission("physgun_pickup", "Unlimited Physgun", "Grants access to pick up any entity with the physics gun.", "flags")

  -- General permissions
  fl.admin:RegisterPermission("context_menu", "Access Context Menu", "Grants access to the context menu.", "general")
end
