MZClothingNui = {}

function MZClothingNui.open(payload)
  SetNuiFocus(true, true)
  SendNUIMessage({
    action = 'open',
    payload = payload
  })
end

function MZClothingNui.close()
  SetNuiFocus(false, false)
  SendNUIMessage({
    action = 'close'
  })
end

function MZClothingNui.setBusy(value)
  SendNUIMessage({
    action = 'busy',
    busy = value == true
  })
end

function MZClothingNui.update(payload)
  SendNUIMessage({
    action = 'update',
    payload = payload
  })
end

RegisterNUICallback('close', function(_, cb)
  MZClothing.close(true)
  cb({ ok = true })
end)

RegisterNUICallback('reset', function(_, cb)
  local result = MZClothing.reset()
  cb(result)
end)

RegisterNUICallback('preview', function(data, cb)
  local result = MZClothing.preview(data and data.appearance)
  cb(result)
end)

RegisterNUICallback('save', function(data, cb)
  if Config.Debug == true then
    print('[mz_clothing][debug] nui save callback')
  end

  local result = MZClothing.save(data)
  cb(result)
end)

RegisterNUICallback('rotateLeft', function(_, cb)
  MZClothingCamera.rotate(-(tonumber((Config.Camera or {}).rotateStep) or 18.0))
  cb({ ok = true })
end)

RegisterNUICallback('rotateRight', function(_, cb)
  MZClothingCamera.rotate(tonumber((Config.Camera or {}).rotateStep) or 18.0)
  cb({ ok = true })
end)

RegisterNUICallback('zoomIn', function(_, cb)
  MZClothingCamera.zoomIn()
  cb({ ok = true })
end)

RegisterNUICallback('zoomOut', function(_, cb)
  MZClothingCamera.zoomOut()
  cb({ ok = true })
end)

RegisterNUICallback('resetCamera', function(_, cb)
  MZClothingCamera.reset()
  cb({ ok = true })
end)

RegisterNUICallback('setCameraMode', function(data, cb)
  MZClothingCamera.setMode(data and data.mode)
  cb({ ok = true })
end)

RegisterNUICallback('rotate', function(data, cb)
  MZClothingCamera.rotate(data and data.amount or 0.0)
  cb({ ok = true })
end)

RegisterNUICallback('zoom', function(data, cb)
  if data and tonumber(data.value) then
    MZClothingCamera.setMode(MZClothingCamera.mode or (Config.Camera or {}).defaultMode or 'full')
  end
  cb({ ok = true })
end)
