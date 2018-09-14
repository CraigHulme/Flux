class 'Log' extends 'ActiveRecord::Base'

function Log:write(message, action, object, subject, io)
  action = isstring(action) and action:to_snake_case() or ''

  if SERVER then
    local log = Log.new()
      log.body = message
      log.action = action
      log.object = object
      log.subject = subject
    log:save()
  end

  if isfunction(io) then
    io(message, action:snake_to_pascal_case(), object, subject)
  end

  return self
end

function Log:print(message, action, object, subject)
  return self:write(message, action, object, subject, function(message, action, object, subject)
    local prefix = (isstring(action) and action:capitalize()..' - ' or '')

    if SERVER then
      ServerLog(prefix..message)
    else
      print(prefix..message)
    end
  end)
end

function Log:colored(color, message, action, object, subject)
  return self:write(message, action, object, subject, function(message, action, object, subject)
    MsgC(color, (isstring(action) and action:capitalize()..' - ' or '')..message)
  end)
end

function Log:notify(message, arguments)
  self:print(message, arguments.action, arguments.object, arguments.subject)
  fl.player:broadcast(message, arguments)
  return self
end
