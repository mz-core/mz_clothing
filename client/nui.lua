MZClothingNui = {}

function MZClothingNui.open(payload)
  SetNuiFocusKeepInput(false)
  SetNuiFocus(true, true)
  SendNUIMessage({ action = 'open', payload = payload })
end

function MZClothingNui.close()
  SetNuiFocusKeepInput(false)
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
end

function MZClothingNui.setBusy(value)
  SendNUIMessage({ action = 'busy', busy = value == true })
end

RegisterNUICallback('close', function(_, cb)
  MZClothing.close('nui_closed')
  cb({ ok = true })
end)

RegisterNUICallback('selectVariant', function(data, cb)
  cb(MZClothing.selectVariant(data))
end)

RegisterNUICallback('purchase', function(_, cb)
  cb(MZClothing.purchase())
end)

RegisterNUICallback('listOutfits', function(_, cb)
  cb(MZClothing.listOutfits())
end)

RegisterNUICallback('saveOutfit', function(data, cb)
  cb(MZClothing.saveOutfit(data and data.name))
end)

RegisterNUICallback('applyOutfit', function(data, cb)
  cb(MZClothing.applyOutfit(data and data.name))
end)

RegisterNUICallback('deleteOutfit', function(data, cb)
  cb(MZClothing.deleteOutfit(data and data.name))
end)

for callback, action in pairs({
  rotateLeft = function() MZClothingCamera.rotate(-(tonumber((Config.Camera or {}).rotateStep) or 18.0)) end,
  rotateRight = function() MZClothingCamera.rotate(tonumber((Config.Camera or {}).rotateStep) or 18.0) end,
  zoomIn = MZClothingCamera.zoomIn,
  zoomOut = MZClothingCamera.zoomOut,
  resetCamera = MZClothingCamera.reset
}) do
  RegisterNUICallback(callback, function(_, cb)
    action()
    cb({ ok = true })
  end)
end

RegisterNUICallback('setCameraMode', function(data, cb)
  MZClothingCamera.setMode(data and data.mode)
  cb({ ok = true })
end)
