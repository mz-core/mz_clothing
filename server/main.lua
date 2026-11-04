MZClothingService = {}

local ShopSessions = {}
local PurchaseLocks = {}
local FREEMODE_MODELS = {
  [joaat('mp_m_freemode_01')] = 'mp_m_freemode_01',
  [joaat('mp_f_freemode_01')] = 'mp_f_freemode_01'
}

local function getPlayer(source)
  local ok, player = pcall(function()
    return exports['mz_core']:GetPlayerSnapshot(source)
  end)
  return ok and player or nil
end

local function actionAllowed(source, action)
  local ok, allowed, result = pcall(function()
    return exports['mz_core']:CanPlayerPerformAction(source, action)
  end)
  return ok and allowed == true and type(result) == 'table' and result.allowed == true
end

local function distanceBetween(left, right)
  if not left or not right then return nil end
  local x = (tonumber(left.x) or 0) - (tonumber(right.x) or 0)
  local y = (tonumber(left.y) or 0) - (tonumber(right.y) or 0)
  local z = (tonumber(left.z) or 0) - (tonumber(right.z) or 0)
  return math.sqrt(x * x + y * y + z * z)
end

local function getShop(source, shopId)
  local shop = type(Config.ClothingShops) == 'table' and Config.ClothingShops[shopId] or nil
  if type(shop) ~= 'table' or not shop.coords then return nil, 'invalid_shop' end
  local ped = GetPlayerPed(source)
  if not ped or ped == 0 or not DoesEntityExist(ped) then return nil, 'player_ped_unavailable' end
  local allowedDistance = math.max(3.0, tonumber(shop.interact and shop.interact.interactDistance) or 2.0) + 2.0
  if (distanceBetween(GetEntityCoords(ped), shop.coords) or math.huge) > allowedDistance then
    return nil, 'too_far_from_shop'
  end
  return shop, ped
end

local function getModelFamily(source)
  local ped = GetPlayerPed(source)
  return ped and FREEMODE_MODELS[GetEntityModel(ped)] or nil
end

local function categoryBySlot(slot)
  slot = tostring(slot or '')
  for _, category in ipairs(Config.ClothingCategories or {}) do
    if tostring(category.slot) == slot then return category end
  end
  return nil
end

local function shopOffersCategory(shop, slot)
  if type(shop and shop.catalog) ~= 'table' then return true end
  if shop.catalog[slot] == true then return true end
  for _, offeredSlot in ipairs(shop.catalog) do
    if tostring(offeredSlot) == slot then return true end
  end
  return false
end

local function publicCategories(shop)
  local result = {}
  for _, category in ipairs(Config.ClothingCategories or {}) do
    if shopOffersCategory(shop, tostring(category.slot)) then
      result[#result + 1] = {
        slot = tostring(category.slot),
        label = tostring(category.label or category.slot),
        group = tostring(category.group or 'accessories'),
        kind = tostring(category.kind),
        native_id = tonumber(category.native_id),
        price = math.max(0, math.floor(tonumber(category.price) or 0)),
        camera = tostring(category.camera or 'full')
      }
    end
  end
  return result
end

local function integer(value, minimum, maximum)
  value = tonumber(value)
  if not value or value % 1 ~= 0 or value < minimum or value > maximum then return nil end
  return math.floor(value)
end

local function normalizeVisualVariant(raw)
  if type(raw) ~= 'table' then return nil end
  local slot = tostring(raw.slot or '')
  local category = categoryBySlot(slot)
  local model = tostring(raw.model or '')
  local collection = tostring(raw.collection or '')
  local drawable = integer(raw.drawable, 0, 8191)
  local texture = integer(raw.texture or 0, 0, 255)
  local palette = integer(raw.palette or 0, 0, 3)
  if not category or not drawable or not texture or not palette then return nil end
  if model ~= 'mp_m_freemode_01' and model ~= 'mp_f_freemode_01' then return nil end
  if #collection > 96 or (collection ~= '' and not collection:match('^[%w_%-]+$')) then return nil end
  return {
    slot = slot,
    model = model,
    collection = collection,
    drawable = drawable,
    texture = texture,
    palette = palette
  }, category
end

local function materializeVariant(variant, category)
  return {
    kind = tostring(category.kind),
    native_id = tonumber(category.native_id),
    collection = tostring(variant.collection or ''),
    drawable = tonumber(variant.drawable),
    texture = tonumber(variant.texture),
    palette = tonumber(variant.palette)
  }
end

local function variantFingerprint(variant)
  return table.concat({
    tostring(variant.slot), tostring(variant.model), tostring(variant.collection),
    tostring(variant.drawable), tostring(variant.texture), tostring(variant.palette)
  }, ':')
end

local function sessionValid(source, shopId)
  local session = ShopSessions[source]
  if not session or session.shopId ~= shopId or session.expiresAt < os.time() then
    ShopSessions[source] = nil
    return nil
  end
  if not getShop(source, shopId) then return nil end
  return session
end

local function normalizeOperationId(value)
  value = tostring(value or '')
  if #value < 16 or #value > 64 or not value:match('^[%w_-]+$') then return nil end
  return value
end

local function newPurchaseId(source, session)
  session.sequence = (tonumber(session.sequence) or 0) + 1
  return ('clothing_%d_%d_%d_%06d'):format(
    tonumber(source) or 0, os.time(), session.sequence, math.random(0, 999999)
  )
end

local function normalizeOutfitName(value)
  value = tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
  if #value < 1 or #value > 32 or value:find('[%c]') then return nil end
  return value
end

local function rowVisualVariant(row, modelFamily)
  local metadata = type(row.metadata) == 'table' and row.metadata or {}
  local clothing = type(metadata.clothing) == 'table' and metadata.clothing or nil
  if not clothing then return nil end

  local variant, category = normalizeVisualVariant(clothing)
  if variant and variant.model == modelFamily then return variant, category end

  local legacy = type(clothing.variants) == 'table' and clothing.variants[modelFamily] or nil
  category = categoryBySlot(clothing.slot)
  if type(legacy) ~= 'table' or not category then return nil end
  variant = {
    slot = tostring(clothing.slot), model = modelFamily,
    collection = tostring(legacy.collection or ''),
    drawable = integer(legacy.drawable, 0, 8191),
    texture = integer(legacy.texture or 0, 0, 255),
    palette = integer(legacy.palette or 0, 0, 3)
  }
  if not variant.drawable or not variant.texture or not variant.palette then return nil end
  return variant, category
end

local function equipmentProjection(source)
  local modelFamily = getModelFamily(source)
  if not modelFamily then return nil, 'unsupported_ped_model' end
  local ok, rowsOrErr = exports['mz_inventory']:GetPlayerEquipmentState(source)
  if not ok then return nil, rowsOrErr end

  local items = {}
  for _, row in ipairs(rowsOrErr or {}) do
    local variant, category = rowVisualVariant(row, modelFamily)
    if variant and category then
      items[#items + 1] = {
        instance_uid = row.instance_uid,
        slot = variant.slot,
        label = tostring((type(row.metadata) == 'table' and row.metadata.display_label)
          or category.label or variant.slot),
        variant = materializeVariant(variant, category)
      }
    end
  end
  return { model = modelFamily, items = items }
end

function MZClothingService.reconcile(source)
  local projection, err = equipmentProjection(source)
  if not projection then return { ok = false, error = err } end
  TriggerClientEvent('mz_clothing:client:applyEquipment', source, projection)
  return { ok = true, projection = projection }
end

local function beginSecuritySession(source, payload)
  if not actionAllowed(source, 'shop.use') then return { ok = false, error = 'player_state_blocked' } end
  payload = type(payload) == 'table' and payload or {}
  if GetResourceState('mz_banguard') == 'started' then
    local called, valid = pcall(function()
      return exports['mz_banguard']:ValidateEventContract(source, 'lifecycle.clothing.open', payload)
    end)
    if not called or valid ~= true then return { ok = false, error = 'invalid_security_contract' } end
  end

  local shopId = tostring(payload.shopId or '')
  local shop, pedOrErr = getShop(source, shopId)
  if not shop then return { ok = false, error = pedOrErr } end
  local player = getPlayer(source)
  local modelFamily = getModelFamily(source)
  if not player then return { ok = false, error = 'player_not_loaded' } end
  if not modelFamily then return { ok = false, error = 'unsupported_ped_model' } end

  local lifecycleId = payload.securityLifecycleId
  if type(lifecycleId) == 'string' and GetResourceState('mz_banguard') == 'started' then
    local checked, active = pcall(function()
      return exports['mz_banguard']:CheckSecurityLifecycle(source, lifecycleId, 'cosmetic_session')
    end)
    if not checked or active ~= true then lifecycleId = nil end
  end
  if GetResourceState('mz_banguard') == 'started' and not lifecycleId then
    local issued = pcall(function()
      lifecycleId = exports['mz_banguard']:BeginSecurityLifecycle(source, 'cosmetic_session', 180000, {
        model = GetEntityModel(pedOrErr), bucket = GetPlayerRoutingBucket(source), reason = 'clothing_shop'
      })
    end)
    if not issued or type(lifecycleId) ~= 'string' then
      return { ok = false, error = 'security_session_failed' }
    end
  end

  ShopSessions[source] = {
    shopId = shopId,
    model = modelFamily,
    securityLifecycleId = lifecycleId,
    selections = {},
    sequence = 0,
    expiresAt = os.time() + (tonumber(Config.PurchaseOperationTtlSeconds) or 180)
  }
  return {
    ok = true,
    securityLifecycleId = lifecycleId,
    shop = { id = shopId, label = shop.label or 'Loja de Roupas' },
    categories = publicCategories(shop),
    model = modelFamily
  }
end

local function finishSecuritySession(source, reason)
  local session = ShopSessions[source]
  ShopSessions[source] = nil
  if not session or type(session.securityLifecycleId) ~= 'string'
      or GetResourceState('mz_banguard') ~= 'started' then return end
  pcall(function()
    exports['mz_banguard']:EndSecurityLifecycle(
      source, session.securityLifecycleId, tostring(reason or 'clothing_closed')
    )
  end)
end

function MZClothingService.registerPreviewVariant(source, payload)
  payload = type(payload) == 'table' and payload or {}
  local shopId = tostring(payload.shopId or '')
  local session = sessionValid(source, shopId)
  if not session then return { ok = false, error = 'shop_session_expired' } end
  local variant, category = normalizeVisualVariant(payload.variant)
  if not variant or not category then return { ok = false, error = 'invalid_variant' } end
  if variant.model ~= session.model or variant.model ~= getModelFamily(source) then
    return { ok = false, error = 'invalid_model' }
  end
  local shop = Config.ClothingShops[shopId]
  if not shopOffersCategory(shop, variant.slot) then return { ok = false, error = 'invalid_category' } end

  local purchaseId = newPurchaseId(source, session)
  session.selections[purchaseId] = {
    id = purchaseId,
    variant = variant,
    category = category,
    fingerprint = variantFingerprint(variant)
  }
  return {
    ok = true,
    purchase_id = purchaseId,
    price = math.max(0, math.floor(tonumber(category.price) or 0))
  }
end

local function purchaseInternal(source, player, shopId, selection)
  local operationId = selection.id
  local variant = selection.variant
  local category = selection.category
  local existing = MZClothingDatabase.beginPurchase(
    player.citizenid, operationId, shopId, selection.id, variant
  )
  if not existing then return { ok = false, error = 'database_error' } end
  if tostring(existing.shop_id) ~= shopId
      or tostring(existing.garment_id) ~= selection.id
      or variantFingerprint(existing.variant or {}) ~= selection.fingerprint then
    return { ok = false, error = 'idempotency_conflict' }
  end
  if existing.status == 'delivered' then
    return { ok = true, replayed = true, instance_uid = existing.instance_uid, equipped = false }
  end
  if existing.status == 'refunded' then
    return { ok = false, error = 'purchase_refunded', replayed = true }
  end

  local foundOk, found = exports['mz_inventory']:FindClothingPurchaseItem(source, operationId)
  if not foundOk then return { ok = false, error = found } end
  local instanceUid = found and tostring(found.instance_uid or '') or ''
  local price = Config.UseMoney == true and math.max(0, math.floor(tonumber(category.price) or 0)) or 0

  if price > 0 and not found then
    local refund = exports['mz_economy']:GetOperationResult(source, operationId .. '_refund', 'add_money')
    if type(refund) == 'table' and refund.ok == true then
      MZClothingDatabase.finishPurchase(player.citizenid, operationId, 'refunded', nil, 'recovered_refund')
      return { ok = false, error = 'purchase_refunded', replayed = true }
    end
    if type(refund) ~= 'table' or (refund.error ~= 'operation_not_found' and refund.error ~= nil) then
      return { ok = false, error = 'refund_state_unavailable' }
    end
  end

  if instanceUid == '' then
    if price > 0 then
      local paid, payErr = exports['mz_economy']:RemoveMoney(source, Config.MoneyType or 'wallet', price, {
        idempotency_key = operationId,
        reason = 'clothing_purchase',
        sourceType = 'clothing_shop',
        sourceRef = shopId,
        external_ref = ('clothing:%s'):format(operationId),
        meta = { slot = variant.slot, model = variant.model }
      })
      if not paid then
        MZClothingDatabase.finishPurchase(player.citizenid, operationId, 'failed', nil, tostring(payErr))
        return { ok = false, error = payErr or 'payment_failed' }
      end
    end

    local added, addResult = exports['mz_inventory']:AddPlayerItem(source, 'clothing_garment', 1, {
      display_label = tostring(category.label or variant.slot),
      clothing = {
        slot = variant.slot,
        model = variant.model,
        collection = variant.collection,
        drawable = variant.drawable,
        texture = variant.texture,
        palette = variant.palette
      },
      purchase = { operation_id = operationId, shop_id = shopId }
    })
    if not added then
      local refunded, refundErr = true, nil
      if price > 0 then
        refunded, refundErr = exports['mz_economy']:AddMoney(source, Config.MoneyType or 'wallet', price, {
          idempotency_key = operationId .. '_refund',
          reason = 'clothing_purchase_refund',
          sourceType = 'clothing_shop',
          sourceRef = shopId,
          external_ref = ('clothing-refund:%s'):format(operationId),
          meta = { slot = variant.slot, inventory_error = tostring(addResult) }
        })
      end
      local status = refunded and 'refunded' or 'refund_failed'
      local errorCode = refunded and tostring(addResult) or ('refund_failed:%s'):format(tostring(refundErr))
      MZClothingDatabase.finishPurchase(player.citizenid, operationId, status, nil, errorCode)
      if not refunded then
        print(('[mz_clothing][purchase][REFUND_FAILED] citizenid=%s operation=%s error=%s'):format(
          tostring(player.citizenid), operationId, tostring(refundErr)
        ))
        return { ok = false, error = 'refund_failed' }
      end
      return { ok = false, error = addResult or 'inventory_add_failed' }
    end

    instanceUid = tostring(addResult and addResult.slots and addResult.slots[1]
      and addResult.slots[1].instance_uid or '')
    if instanceUid == '' then
      local recoveredOk, recovered = exports['mz_inventory']:FindClothingPurchaseItem(source, operationId)
      instanceUid = recoveredOk and recovered and tostring(recovered.instance_uid or '') or ''
    end
    if instanceUid == '' then return { ok = false, error = 'inventory_delivery_state_unknown' } end
    MZClothingDatabase.finishPurchase(player.citizenid, operationId, 'item_created', instanceUid, nil)
  end

  MZClothingDatabase.finishPurchase(player.citizenid, operationId, 'delivered', instanceUid, nil)
  return { ok = true, instance_uid = instanceUid, equipped = false }
end

function MZClothingService.purchase(source, payload)
  payload = type(payload) == 'table' and payload or {}
  local shopId = tostring(payload.shopId or '')
  local operationId = normalizeOperationId(payload.purchaseId)
  local player = getPlayer(source)
  if not MZClothingDatabase.isReady() then return { ok = false, error = 'database_not_ready' } end
  if not player or not player.citizenid then return { ok = false, error = 'player_not_loaded' } end
  if not actionAllowed(source, 'shop.use') then return { ok = false, error = 'player_state_blocked' } end
  if not operationId then return { ok = false, error = 'invalid_purchase_id' } end
  local session = sessionValid(source, shopId)
  if not session then return { ok = false, error = 'shop_session_expired' } end
  local selection = session.selections[operationId]
  if not selection then return { ok = false, error = 'invalid_variant' } end

  local lockKey = ('%s:%s'):format(player.citizenid, operationId)
  if PurchaseLocks[lockKey] then return { ok = false, error = 'operation_busy' } end
  PurchaseLocks[lockKey] = true
  local ok, result = xpcall(function()
    return purchaseInternal(source, player, shopId, selection)
  end, debug.traceback)
  PurchaseLocks[lockKey] = nil
  if not ok then
    print(('[mz_clothing][purchase][ERROR] %s'):format(tostring(result)))
    return { ok = false, error = 'internal_error' }
  end
  return result
end

function MZClothingService.saveOutfit(source, name)
  local player = getPlayer(source)
  name = normalizeOutfitName(name)
  if not MZClothingDatabase.isReady() then return { ok = false, error = 'database_not_ready' } end
  if not player or not player.citizenid then return { ok = false, error = 'player_not_loaded' } end
  if not name then return { ok = false, error = 'invalid_outfit_name' } end
  local ok, rowsOrErr = exports['mz_inventory']:GetPlayerEquipmentState(source)
  if not ok then return { ok = false, error = rowsOrErr } end
  local slots = {}
  for _, row in ipairs(rowsOrErr or {}) do
    local clothing = type(row.metadata) == 'table' and row.metadata.clothing or nil
    if type(clothing) == 'table' and tostring(clothing.slot or '') ~= ''
        and tostring(row.instance_uid or '') ~= '' then
      slots[tostring(clothing.slot)] = tostring(row.instance_uid)
    end
  end
  local row = MZClothingDatabase.upsertOutfit(player.citizenid, name, slots)
  return { ok = row ~= nil, outfit = row }
end

function MZClothingService.listOutfits(source)
  local player = getPlayer(source)
  if not MZClothingDatabase.isReady() then return { ok = false, error = 'database_not_ready' } end
  if not player or not player.citizenid then return { ok = false, error = 'player_not_loaded' } end
  return { ok = true, outfits = MZClothingDatabase.listOutfits(player.citizenid) }
end

function MZClothingService.applyOutfit(source, name)
  local player = getPlayer(source)
  name = normalizeOutfitName(name)
  if not MZClothingDatabase.isReady() then return { ok = false, error = 'database_not_ready' } end
  if not player or not player.citizenid then return { ok = false, error = 'player_not_loaded' } end
  if not name then return { ok = false, error = 'invalid_outfit_name' } end
  local row = MZClothingDatabase.getOutfit(player.citizenid, name)
  if not row then return { ok = false, error = 'outfit_not_found' } end
  local ok, resultOrErr = exports['mz_inventory']:ApplyPlayerEquipmentLoadout(source, row.slots)
  if not ok then return { ok = false, error = resultOrErr } end
  MZClothingService.reconcile(source)
  return { ok = true, outfit = row, result = resultOrErr }
end

function MZClothingService.deleteOutfit(source, name)
  local player = getPlayer(source)
  name = normalizeOutfitName(name)
  if not MZClothingDatabase.isReady() then return { ok = false, error = 'database_not_ready' } end
  if not player or not player.citizenid then return { ok = false, error = 'player_not_loaded' } end
  if not name then return { ok = false, error = 'invalid_outfit_name' } end
  return { ok = MZClothingDatabase.deleteOutfit(player.citizenid, name) > 0 }
end

lib.callback.register('mz_clothing:server:beginSecuritySession', beginSecuritySession)
lib.callback.register('mz_clothing:server:registerPreviewVariant', function(source, payload)
  return MZClothingService.registerPreviewVariant(source, payload)
end)
lib.callback.register('mz_clothing:server:purchase', function(source, payload)
  return MZClothingService.purchase(source, payload)
end)
lib.callback.register('mz_clothing:server:listOutfits', function(source)
  return MZClothingService.listOutfits(source)
end)
lib.callback.register('mz_clothing:server:saveOutfit', function(source, payload)
  return MZClothingService.saveOutfit(source, payload and payload.name)
end)
lib.callback.register('mz_clothing:server:applyOutfit', function(source, payload)
  return MZClothingService.applyOutfit(source, payload and payload.name)
end)
lib.callback.register('mz_clothing:server:deleteOutfit', function(source, payload)
  return MZClothingService.deleteOutfit(source, payload and payload.name)
end)

RegisterNetEvent('mz_clothing:server:requestReconcile', function()
  MZClothingService.reconcile(source)
end)

RegisterNetEvent('mz_clothing:server:endSecuritySession', function(reason)
  finishSecuritySession(source, reason)
end)

AddEventHandler('playerDropped', function()
  ShopSessions[source] = nil
end)

exports('GetPlayerClothingProjection', function(source)
  return equipmentProjection(source)
end)

exports('ApplyPlayerOutfit', function(source, name)
  return MZClothingService.applyOutfit(source, name)
end)
