MZClothingShops = {
  registeredPoints = {},
  legacyBlips = {},
  lastInteractAt = 0
}

local function debugPrint(message)
  if Config.Debug == true then
    print(('[mz_clothing] %s'):format(tostring(message)))
  end
end

local function canUseMzInteract()
  return Config.UseMzInteract == true and GetResourceState('mz_interact') == 'started'
end

local function getShopCoords(shop)
  if type(shop.coords) == 'vector3' then
    return shop.coords
  end

  if type(shop.coords) == 'vector4' then
    return vec3(shop.coords.x, shop.coords.y, shop.coords.z)
  end

  return nil
end

local function mergeTable(defaults, value)
  local out = {}

  for key, child in pairs(defaults or {}) do
    out[key] = child
  end

  for key, child in pairs(value or {}) do
    out[key] = child
  end

  return out
end

local function removeLegacyBlips()
  for shopId, blip in pairs(MZClothingShops.legacyBlips) do
    if blip and DoesBlipExist(blip) then
      RemoveBlip(blip)
    end
    MZClothingShops.legacyBlips[shopId] = nil
  end
end

local function createLegacyBlip(shopId, shop)
  if MZClothingShops.legacyBlips[shopId] and DoesBlipExist(MZClothingShops.legacyBlips[shopId]) then
    return
  end

  local blipConfig = mergeTable(Config.DefaultBlip, shop.blip)
  if blipConfig.enabled ~= true then
    return
  end

  local coords = getShopCoords(shop)
  if not coords then
    return
  end

  local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
  SetBlipSprite(blip, tonumber(blipConfig.sprite) or 73)
  SetBlipColour(blip, tonumber(blipConfig.color) or 3)
  SetBlipScale(blip, (tonumber(blipConfig.scale) or 0.75) + 0.0)
  SetBlipAsShortRange(blip, blipConfig.shortRange ~= false)

  BeginTextCommandSetBlipName('STRING')
  AddTextComponentSubstringPlayerName(tostring(blipConfig.label or shop.label or 'Loja de Roupas'))
  EndTextCommandSetBlipName(blip)

  MZClothingShops.legacyBlips[shopId] = blip
end

local function refreshLegacyBlips()
  if canUseMzInteract() or Config.FallbackToLegacyMarkers ~= true then
    removeLegacyBlips()
    return
  end

  for shopId, shop in pairs(Config.ClothingShops or {}) do
    createLegacyBlip(shopId, shop)
  end
end

local function drawText3D(coords, text)
  SetDrawOrigin(coords.x, coords.y, coords.z, 0)
  SetTextScale(0.0, 0.32)
  SetTextFont(4)
  SetTextProportional(1)
  SetTextColour(255, 255, 255, 230)
  SetTextCentre(true)
  BeginTextCommandDisplayText('STRING')
  AddTextComponentSubstringPlayerName(text)
  EndTextCommandDisplayText(0.0, 0.0)
  ClearDrawOrigin()
end

local function drawLegacyMarker(shop)
  local coords = getShopCoords(shop)
  if not coords then
    return
  end

  local interact = shop.interact or {}
  local marker = mergeTable(Config.DefaultMarker, interact.marker)
  if marker.enabled ~= true then
    return
  end

  local color = marker.color or {}
  local size = marker.size or vec3(0.75, 0.75, 0.75)
  local rotation = marker.rotation or vec3(0.0, 0.0, 0.0)
  local textureDict = nil
  local textureName = nil

  if marker.type == 9 and marker.textureDict and marker.textureName then
    if not HasStreamedTextureDictLoaded(marker.textureDict) then
      RequestStreamedTextureDict(marker.textureDict, true)
    else
      textureDict = marker.textureDict
      textureName = marker.textureName
    end
  end

  DrawMarker(
    tonumber(marker.type) or 2,
    coords.x,
    coords.y,
    coords.z,
    0.0,
    0.0,
    0.0,
    rotation.x or 0.0,
    rotation.y or 0.0,
    rotation.z or 0.0,
    size.x or 0.75,
    size.y or 0.75,
    size.z or 0.75,
    tonumber(color.r) or 255,
    tonumber(color.g) or 255,
    tonumber(color.b) or 255,
    tonumber(color.a) or 230,
    marker.bobUpAndDown == true,
    marker.faceCamera == true,
    2,
    marker.rotate == true,
    textureDict,
    textureName,
    false
  )
end

local function registerShopPoint(shopId, shop)
  if not canUseMzInteract() then
    return
  end

  local coords = getShopCoords(shop)
  if not coords then
    debugPrint(('shop %s without coords'):format(tostring(shopId)))
    return
  end

  local interact = shop.interact or {}
  if interact.enabled == false then
    return
  end

  local pointId = ('mz_clothing:%s'):format(tostring(shopId))
  local marker = mergeTable(Config.DefaultMarker, interact.marker)
  local blip = mergeTable(Config.DefaultBlip, shop.blip)
  local text = mergeTable(Config.DefaultText, interact.text)

  exports['mz_interact']:AddPoint({
    id = pointId,
    coords = coords,
    drawDistance = interact.drawDistance or Config.DefaultDrawDistance,
    interactDistance = interact.interactDistance or Config.DefaultInteractDistance,
    marker = marker,
    blip = blip,
    text = text,
    event = {
      type = 'client',
      name = 'mz_clothing:client:openShop',
      args = { shopId }
    }
  })

  MZClothingShops.registeredPoints[pointId] = true
end

function MZClothingShops.unregisterInteractPoints()
  if GetResourceState('mz_interact') ~= 'started' then
    MZClothingShops.registeredPoints = {}
    return
  end

  for pointId in pairs(MZClothingShops.registeredPoints) do
    exports['mz_interact']:RemovePoint(pointId)
  end

  MZClothingShops.registeredPoints = {}
end

function MZClothingShops.registerInteractPoints()
  if not canUseMzInteract() then
    debugPrint('mz_interact unavailable; using legacy fallback')
    MZClothingShops.unregisterInteractPoints()
    refreshLegacyBlips()
    return
  end

  MZClothingShops.unregisterInteractPoints()
  removeLegacyBlips()

  for shopId, shop in pairs(Config.ClothingShops or {}) do
    registerShopPoint(shopId, shop)
  end
end

function MZClothingShops.setInteractPointsActive(active)
  if GetResourceState('mz_interact') ~= 'started' then
    return
  end

  for pointId in pairs(MZClothingShops.registeredPoints) do
    exports['mz_interact']:SetPointActive(pointId, active == true)
  end
end

function MZClothingShops.startLegacyLoop()
  CreateThread(function()
    refreshLegacyBlips()

    while true do
      local sleep = tonumber(Config.DefaultLoopSleep) or 1000

      if Config.FallbackToLegacyMarkers == true and not canUseMzInteract() and (not MZClothing or MZClothing.open ~= true) then
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        for shopId, shop in pairs(Config.ClothingShops or {}) do
          local shopCoords = getShopCoords(shop)
          if shopCoords then
            local interact = shop.interact or {}
            local drawDistance = tonumber(interact.drawDistance or Config.DefaultDrawDistance) or 25.0
            local interactDistance = tonumber(interact.interactDistance or Config.DefaultInteractDistance) or 2.0
            local distance = #(coords - shopCoords)

            if distance <= drawDistance then
              sleep = tonumber(Config.NearLoopSleep) or 0
              drawLegacyMarker(shop)

              if distance <= interactDistance + 1.0 then
                local text = mergeTable(Config.DefaultText, interact.text)
                if text.enabled ~= false then
                  drawText3D(
                    vec3(shopCoords.x, shopCoords.y, shopCoords.z + (tonumber(text.offsetZ) or 0.35)),
                    tostring(text.label or '[E] Comprar roupas')
                  )
                end
              end

              if distance <= interactDistance and IsControlJustReleased(0, tonumber(Config.DefaultKey) or 38) then
                local now = GetGameTimer()
                if now - MZClothingShops.lastInteractAt >= (tonumber(Config.InteractCooldownMs) or 800) then
                  MZClothingShops.lastInteractAt = now
                  TriggerEvent('mz_clothing:client:openShop', shopId)
                end
              end
            end
          end
        end
      end

      Wait(sleep)
    end
  end)

  CreateThread(function()
    while true do
      refreshLegacyBlips()
      Wait(2500)
    end
  end)
end

AddEventHandler('onClientResourceStart', function(resourceName)
  if resourceName == 'mz_interact' or resourceName == GetCurrentResourceName() then
    Wait(750)
    MZClothingShops.registerInteractPoints()
  end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
  if resourceName == 'mz_interact' then
    Wait(500)
    refreshLegacyBlips()
  elseif resourceName == GetCurrentResourceName() then
    MZClothingShops.unregisterInteractPoints()
    removeLegacyBlips()
  end
end)
