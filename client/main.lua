MZClothing = {
  open = false,
  shopId = nil,
  originalAppearance = nil,
  currentAppearance = nil,
  applyRequestToken = 0
}

local function debugPrint(message)
  if Config.Debug == true then
    print(('[mz_clothing] %s'):format(tostring(message)))
  end
end

local function notify(title, message, kind)
  if GetResourceState('mz_notify') == 'started' then
    TriggerEvent('mz_notify:client:send', {
      title = title,
      description = message,
      type = kind or 'info'
    })
    return
  end

  print(('[mz_clothing][%s] %s - %s'):format(tostring(kind or 'info'), tostring(title), tostring(message)))
end

local function buildPayload(shopId, appearance)
  local shop = (Config.ClothingShops or {})[shopId] or {}
  return {
    shopId = shopId,
    shop = {
      label = shop.label or 'Loja de Roupas'
    },
    price = Config.UseMoney == true and Config.ClothingPrice or 0,
    useMoney = Config.UseMoney == true,
    appearance = appearance,
    limits = MZClothingAppearance.getLimits(appearance),
    definitions = MZClothingAppearance.getDefinitions(),
    cameraModes = MZClothingCamera.getUiModes()
  }
end

local function startHiddenPlayersLoop()
  CreateThread(function()
    while MZClothing.open == true do
      local myPed = PlayerPedId()

      for _, player in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(player)
        if ped ~= myPed and ped ~= 0 then
          SetEntityLocallyInvisible(ped)
        end
      end

      Wait(0)
    end
  end)
end

function MZClothing.openShop(shopId)
  if MZClothing.open == true then
    return
  end

  shopId = tostring(shopId or '')
  if shopId == '' or not (Config.ClothingShops or {})[shopId] then
    notify('Roupas', 'Loja invalida.', 'error')
    return
  end

  if IsPedInAnyVehicle(PlayerPedId(), false) then
    notify('Roupas', 'Saia do veiculo para trocar de roupa.', 'error')
    return
  end

  local ped = PlayerPedId()
  MZClothing.open = true
  MZClothing.shopId = shopId
  MZClothing.originalAppearance = MZClothingAppearance.capture()
  MZClothing.currentAppearance = MZClothingAppearance.clone(MZClothing.originalAppearance)

  FreezeEntityPosition(ped, true)
  SetEntityInvincible(ped, true)
  DisplayRadar(false)
  MZClothingShops.setInteractPointsActive(false)
  startHiddenPlayersLoop()
  MZClothingCamera.start()
  MZClothingNui.open(buildPayload(shopId, MZClothing.currentAppearance))
end

function MZClothing.close(restore)
  if MZClothing.open ~= true then
    return
  end

  if restore == true and MZClothing.originalAppearance then
    MZClothingAppearance.apply(MZClothing.originalAppearance)
  end

  local ped = PlayerPedId()
  MZClothingCamera.stop()
  MZClothingNui.close()
  FreezeEntityPosition(ped, false)
  SetEntityInvincible(ped, false)
  DisplayRadar(true)
  MZClothingShops.setInteractPointsActive(true)

  MZClothing.open = false
  MZClothing.shopId = nil
  MZClothing.originalAppearance = nil
  MZClothing.currentAppearance = nil
end

function MZClothing.reset()
  if MZClothing.open ~= true or not MZClothing.originalAppearance then
    return { ok = false, error = 'not_open' }
  end

  MZClothing.currentAppearance = MZClothingAppearance.clone(MZClothing.originalAppearance)
  MZClothingAppearance.apply(MZClothing.currentAppearance)
  MZClothingNui.update(buildPayload(MZClothing.shopId, MZClothing.currentAppearance))

  return {
    ok = true,
    appearance = MZClothing.currentAppearance,
    limits = MZClothingAppearance.getLimits(MZClothing.currentAppearance)
  }
end

function MZClothing.preview(appearance)
  if MZClothing.open ~= true or type(appearance) ~= 'table' then
    return { ok = false, error = 'invalid_appearance' }
  end

  MZClothing.currentAppearance = MZClothingAppearance.clone(appearance)
  MZClothingAppearance.apply(MZClothing.currentAppearance)

  return {
    ok = true,
    limits = MZClothingAppearance.getLimits(MZClothing.currentAppearance)
  }
end

function MZClothing.save(data)
  if MZClothing.open ~= true or type(MZClothing.currentAppearance) ~= 'table' then
    return { ok = false, error = 'not_open' }
  end

  if type(data) == 'table' and type(data.appearance) == 'table' then
    MZClothing.currentAppearance = MZClothingAppearance.clone(data.appearance)
    MZClothingAppearance.apply(MZClothing.currentAppearance)
  end

  debugPrint('save requested')
  MZClothingNui.setBusy(true)

  local result = lib.callback.await('mz_clothing:server:saveCurrent', false, {
    shopId = MZClothing.shopId,
    appearance_json = MZClothing.currentAppearance
  })

  MZClothingNui.setBusy(false)

  if result and result.ok == true then
    debugPrint('save success')
    if type(result.appearance) == 'table' then
      MZClothingAppearance.apply(result.appearance)
    end
    MZClothing.close(false)
    notify('Roupas', 'Roupa salva com sucesso.', 'success')
    return result
  end

  debugPrint(('save failed: %s'):format(tostring(result and result.error or 'save_failed')))
  notify('Roupas', 'Nao foi possivel salvar a roupa.', 'error')
  return result or { ok = false, error = 'save_failed' }
end

RegisterNetEvent('mz_clothing:client:openShop', function(shopId)
  MZClothing.openShop(shopId)
end)

RegisterNetEvent('mz_clothing:client:applyClothing', function(appearance)
  MZClothingAppearance.apply(appearance)
end)

local function requestApplySavedAfterDelay(delayMs)
  MZClothing.applyRequestToken = (MZClothing.applyRequestToken or 0) + 1
  local token = MZClothing.applyRequestToken

  CreateThread(function()
    Wait(tonumber(delayMs) or 0)
    if token ~= MZClothing.applyRequestToken then
      return
    end

    TriggerServerEvent('mz_clothing:server:requestApplySaved')
  end)
end

RegisterNetEvent('mz_core:client:playerLoaded', function()
  requestApplySavedAfterDelay(2500)
end)

AddEventHandler('playerSpawned', function()
  requestApplySavedAfterDelay(1200)
end)

RegisterCommand(Config.DebugCommand or 'clothing_test', function()
  if Config.Debug ~= true then
    return
  end

  local firstShopId = nil
  for shopId in pairs(Config.ClothingShops or {}) do
    firstShopId = shopId
    break
  end

  MZClothing.openShop(firstShopId)
end, false)

CreateThread(function()
  Wait(1000)
  MZClothingShops.registerInteractPoints()
  MZClothingShops.startLegacyLoop()
end)

AddEventHandler('onResourceStop', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then
    return
  end

  if MZClothing.open == true and MZClothing.originalAppearance then
    MZClothingAppearance.apply(MZClothing.originalAppearance)
  end

  MZClothingCamera.stop()
  SetNuiFocus(false, false)
  FreezeEntityPosition(PlayerPedId(), false)
  DisplayRadar(true)
  MZClothingShops.setInteractPointsActive(true)
end)
