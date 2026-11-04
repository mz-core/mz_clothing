assert(
  type(MZClothingInventoryPreview) == 'table',
  '[mz_clothing] client/inventory_preview.lua was not loaded; deploy it before client/main.lua'
)

MZClothing = {
  open = false,
  inventoryOpen = false,
  shopId = nil,
  catalog = {},
  selections = {},
  currentSelection = nil,
  purchaseId = nil,
  originalAppearance = nil,
  applyRequestToken = 0,
  lifecycleGeneration = 0,
  pendingPreviewReason = nil
}

local function notify(message, kind)
  if GetResourceState('mz_notify') == 'started' then
    TriggerEvent('mz_notify:client:send', {
      title = 'Roupas', description = message, type = kind or 'info'
    })
    return
  end
  print(('[mz_clothing][%s] %s'):format(tostring(kind or 'info'), tostring(message)))
end

local function startHiddenPlayersLoop()
  CreateThread(function()
    while MZClothing.open do
      local ownPed = PlayerPedId()
      for _, player in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(player)
        if ped ~= ownPed and ped ~= 0 then SetEntityLocallyInvisible(ped) end
      end
      Wait(0)
    end
  end)
end

local function findCategory(slot)
  for _, category in ipairs(MZClothing.catalog or {}) do
    if category.slot == slot then return category end
  end
  return nil
end

local function requestReconcile(delayMs)
  MZClothing.applyRequestToken = MZClothing.applyRequestToken + 1
  local token = MZClothing.applyRequestToken
  CreateThread(function()
    Wait(tonumber(delayMs) or 0)
    if token == MZClothing.applyRequestToken then
      TriggerServerEvent('mz_clothing:server:requestReconcile')
    end
  end)
end

local function getShopCoords(shop)
  if type(shop) ~= 'table' or not shop.coords then return nil end
  return vec3(shop.coords.x, shop.coords.y, shop.coords.z)
end

local function startShopLifecycle()
  MZClothing.lifecycleGeneration = MZClothing.lifecycleGeneration + 1
  local generation = MZClothing.lifecycleGeneration
  CreateThread(function()
    while MZClothing.open and generation == MZClothing.lifecycleGeneration do
      Wait(250)
      if not MZClothing.open or generation ~= MZClothing.lifecycleGeneration then return end
      local ped = PlayerPedId()
      if IsEntityDead(ped) then
        MZClothing.close('player_dead')
        return
      end
      local shop = (Config.ClothingShops or {})[MZClothing.shopId]
      local coords = getShopCoords(shop)
      if not coords or #(GetEntityCoords(ped) - coords) > 6.0 then
        MZClothing.close('left_shop')
        return
      end
    end
  end)
end

local function registerSelection(selection)
  local result = lib.callback.await('mz_clothing:server:registerPreviewVariant', false, {
    shopId = MZClothing.shopId,
    variant = selection.variant
  })
  if not result or result.ok ~= true then return nil, result and result.error or 'variant_registration_failed' end
  MZClothing.purchaseId = result.purchase_id
  return math.max(0, tonumber(result.price) or 0)
end

function MZClothing.selectVariant(data)
  if not MZClothing.open or not MZClothing.originalAppearance then
    return { ok = false, error = 'not_open' }
  end
  data = type(data) == 'table' and data or {}
  local category = findCategory(tostring(data.slot or ''))
  if not category then return { ok = false, error = 'invalid_category' } end

  MZClothingAppearance.apply(MZClothing.originalAppearance)
  local selection, selectError = MZClothingAppearance.select(
    category,
    MZClothing.selections[category.slot],
    data.modelDelta,
    data.textureDelta
  )
  if not selection then return { ok = false, error = selectError or 'invalid_variant' } end
  local price, registerError = registerSelection(selection)
  if price == nil then
    MZClothingAppearance.apply(MZClothing.originalAppearance)
    return { ok = false, error = registerError }
  end

  MZClothing.selections[category.slot] = selection
  MZClothing.currentSelection = selection
  MZClothingCamera.setMode(category.camera)
  return {
    ok = true,
    slot = category.slot,
    label = category.label,
    price = price,
    model = selection.variant.model,
    collection = selection.variant.collection,
    drawable = selection.variant.drawable,
    texture = selection.variant.texture,
    palette = selection.variant.palette,
    model_index = selection.model_index,
    model_count = selection.model_count,
    texture_count = selection.texture_count
  }
end

function MZClothing.openShop(shopId)
  if MZClothing.open then return end
  local delegatedLifecycle
  if type(shopId) == 'table' then
    delegatedLifecycle, shopId = shopId.securityLifecycleId, shopId.shopId
  end
  shopId = tostring(shopId or '')
  if shopId == '' or not (Config.ClothingShops or {})[shopId] then
    notify('Loja invalida.', 'error')
    return
  end
  if IsPedInAnyVehicle(PlayerPedId(), false) then
    notify('Saia do veiculo para experimentar roupas.', 'error')
    return
  end

  local result = lib.callback.await('mz_clothing:server:beginSecuritySession', false, {
    shopId = shopId, securityLifecycleId = delegatedLifecycle
  })
  if not result or result.ok ~= true then
    notify(('Nao foi possivel abrir a loja (%s).'):format(tostring(result and result.error or 'falha')), 'error')
    return
  end

  local catalog = MZClothingAppearance.enumerate(result.categories)
  if #catalog == 0 then
    TriggerServerEvent('mz_clothing:server:endSecuritySession', 'empty_catalog')
    notify('Nenhuma roupa compativel foi encontrada para este personagem.', 'error')
    return
  end

  local ped = PlayerPedId()
  MZClothing.open = true
  MZClothing.shopId = shopId
  MZClothing.catalog = catalog
  MZClothing.selections = {}
  MZClothing.currentSelection = nil
  MZClothing.purchaseId = nil
  MZClothing.originalAppearance = MZClothingAppearance.capture()
  FreezeEntityPosition(ped, true)
  SetEntityInvincible(ped, true)
  DisplayRadar(false)
  MZClothingShops.setInteractPointsActive(false)
  startHiddenPlayersLoop()
  startShopLifecycle()
  MZClothingInventoryPreview.close()
  MZClothingCamera.start()

  local initial = MZClothing.selectVariant({ slot = catalog[1].slot })
  if not initial.ok then
    MZClothing.close('catalog_failed')
    notify(('Catalogo indisponivel (%s).'):format(tostring(initial.error)), 'error')
    return
  end
  MZClothingNui.open({
    shop = result.shop,
    categories = catalog,
    selection = initial,
    cameraModes = MZClothingCamera.getUiModes()
  })
end

function MZClothing.close(reason)
  if not MZClothing.open then return end
  MZClothing.open = false
  MZClothing.lifecycleGeneration = MZClothing.lifecycleGeneration + 1
  if MZClothing.originalAppearance then MZClothingAppearance.apply(MZClothing.originalAppearance) end
  MZClothingNui.close()
  local ped = PlayerPedId()
  FreezeEntityPosition(ped, false)
  SetEntityInvincible(ped, false)
  DisplayRadar(true)
  MZClothingShops.setInteractPointsActive(true)
  MZClothing.shopId = nil
  MZClothing.catalog = {}
  MZClothing.selections = {}
  MZClothing.currentSelection = nil
  MZClothing.purchaseId = nil
  MZClothing.originalAppearance = nil
  TriggerServerEvent('mz_clothing:server:endSecuritySession', tostring(reason or 'clothing_closed'))
  MZClothingCamera.stop()
  requestReconcile(50)
  if MZClothing.inventoryOpen then MZClothingInventoryPreview.open() end
end

function MZClothing.purchase()
  if not MZClothing.open or not MZClothing.currentSelection or not MZClothing.purchaseId then
    return { ok = false, error = 'variant_not_selected' }
  end
  MZClothingNui.setBusy(true)
  local result = lib.callback.await('mz_clothing:server:purchase', false, {
    shopId = MZClothing.shopId,
    purchaseId = MZClothing.purchaseId
  })
  MZClothingNui.setBusy(false)
  if not result or result.ok ~= true then
    notify(('Compra recusada (%s).'):format(tostring(result and result.error or 'falha')), 'error')
    return result or { ok = false, error = 'purchase_failed' }
  end

  local price, registerError = registerSelection(MZClothing.currentSelection)
  if price == nil then MZClothing.purchaseId = nil end
  notify('Roupa enviada para a bag.', 'success')
  result.next_purchase_ready = price ~= nil
  result.next_purchase_error = registerError
  return result
end

function MZClothing.listOutfits()
  return lib.callback.await('mz_clothing:server:listOutfits', false) or { ok = false }
end

function MZClothing.saveOutfit(name)
  return lib.callback.await('mz_clothing:server:saveOutfit', false, { name = name }) or { ok = false }
end

function MZClothing.applyOutfit(name)
  local result = lib.callback.await('mz_clothing:server:applyOutfit', false, { name = name }) or { ok = false }
  if result.ok then requestReconcile(50) end
  return result
end

function MZClothing.deleteOutfit(name)
  return lib.callback.await('mz_clothing:server:deleteOutfit', false, { name = name }) or { ok = false }
end

RegisterNetEvent('mz_clothing:client:openShop', MZClothing.openShop)
RegisterNetEvent('mz_clothing:client:applyEquipment', function(projection)
  local reason = MZClothing.pendingPreviewReason
  MZClothing.pendingPreviewReason = nil
  if not MZClothing.open and MZClothingAppearance.applyProjection(projection) then
    if reason == 'equip' or reason == 'unequip' then MZClothingInventoryPreview.refresh(reason) end
  end
end)
RegisterNetEvent('mz_clothing:client:requestReconcile', function()
  requestReconcile(50)
end)
RegisterNetEvent('mz_inventory:client:equipmentChanged', function(payload)
  MZClothing.pendingPreviewReason = type(payload) == 'table' and tostring(payload.reason or 'equipment') or 'equipment'
  requestReconcile(50)
end)
RegisterNetEvent('mz_inventory:client:visibilityChanged', function(visible)
  MZClothing.inventoryOpen = visible == true
  if MZClothing.inventoryOpen then
    if not MZClothing.open then MZClothingInventoryPreview.open() end
  else
    MZClothingInventoryPreview.close('inventory_closed')
  end
end)
RegisterNetEvent('mz_creator:client:appearanceApplied', function()
  requestReconcile(100)
end)
RegisterNetEvent('mz_core:client:playerLoaded', function()
  MZClothing.inventoryOpen = false
  MZClothingInventoryPreview.close('player_loaded')
  if MZClothing.open then MZClothing.close('player_loaded') else requestReconcile(2500) end
end)
RegisterNetEvent('mz_core:client:characterSelectionRequired', function()
  MZClothing.inventoryOpen = false
  MZClothingInventoryPreview.close('character_selection_required')
  if MZClothing.open then MZClothing.close('character_changed') else MZClothingCamera.stop() end
end)
RegisterNetEvent('baseevents:onPlayerDied', function()
  if MZClothing.open then MZClothing.close('player_dead') end
end)
RegisterNetEvent('baseevents:onPlayerKilled', function()
  if MZClothing.open then MZClothing.close('player_killed') end
end)
AddEventHandler('playerSpawned', function()
  requestReconcile(1200)
end)

RegisterCommand(Config.DebugCommand or 'clothing_test', function()
  if Config.Debug ~= true then return end
  for id in pairs(Config.ClothingShops or {}) do MZClothing.openShop(id) break end
end, false)

CreateThread(function()
  Wait(1000)
  MZClothingShops.registerInteractPoints()
  MZClothingShops.startLegacyLoop()
  if GetResourceState('mz_inventory') == 'started' then
    local ok, inventoryOpen = pcall(function()
      return exports['mz_inventory']:IsOpen()
    end)
    if ok and inventoryOpen == true then
      MZClothing.inventoryOpen = true
      MZClothingInventoryPreview.open()
    end
  end
  requestReconcile(500)
end)

AddEventHandler('onResourceStop', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then return end
  if MZClothing.open and MZClothing.originalAppearance then
    MZClothingAppearance.apply(MZClothing.originalAppearance)
    TriggerServerEvent('mz_clothing:server:endSecuritySession', 'resource_stopped')
  end
  MZClothingInventoryPreview.close('resource_stop')
  MZClothingCamera.stop()
  SetNuiFocusKeepInput(false)
  SetNuiFocus(false, false)
  FreezeEntityPosition(PlayerPedId(), false)
  SetEntityInvincible(PlayerPedId(), false)
  DisplayRadar(true)
  MZClothingShops.setInteractPointsActive(true)
end)
