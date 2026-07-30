MZClothingService = {}

local function debugPrint(message)
  if Config.Debug == true then
    print(('[mz_clothing][debug] %s'):format(tostring(message)))
  end
end

local allowedModels = {
  mp_m_freemode_01 = true,
  mp_f_freemode_01 = true
}

local componentIds = {
  ['1'] = true, -- mask
  ['3'] = true, -- arms
  ['4'] = true, -- pants
  ['5'] = true, -- bag
  ['6'] = true, -- shoes
  ['7'] = true, -- accessories
  ['8'] = true, -- undershirt
  ['9'] = true, -- vest
  ['10'] = true, -- decals
  ['11'] = true -- top
}

local propIds = {
  ['0'] = true, -- hat
  ['1'] = true, -- glasses
  ['2'] = true, -- ears
  ['6'] = true, -- watch
  ['7'] = true -- bracelet
}

local function getPlayer(source)
  local ok, player = pcall(function()
    return exports['mz_core']:GetPlayer(source)
  end)

  if not ok then
    return nil
  end

  return player
end

local function decodeJson(value)
  if type(value) == 'table' then
    return value
  end

  if type(value) ~= 'string' or value == '' then
    return nil
  end

  local ok, decoded = pcall(json.decode, value)
  if not ok then
    return nil
  end

  return decoded
end

local function getPayloadSize(value)
  if type(value) == 'string' then
    return #value
  end

  local ok, encoded = pcall(json.encode, value or {})
  if not ok then
    return 0
  end

  return #encoded
end

local function fail(error, detail)
  return nil, {
    ok = false,
    error = error,
    detail = detail
  }
end

local function inspectTable(value, depth, path)
  if type(value) ~= 'table' then
    local valueType = type(value)
    if valueType == 'function' or valueType == 'userdata' or valueType == 'thread' then
      return false, path
    end
    return true
  end

  if depth > 5 then
    return false, path
  end

  local count = 0
  for key, child in pairs(value) do
    count = count + 1
    if count > 128 then
      return false, path
    end

    local keyType = type(key)
    if (keyType ~= 'string' and keyType ~= 'number') or (keyType == 'string' and key:sub(1, 2) == '__') then
      return false, path
    end

    local ok, err = inspectTable(child, depth + 1, ('%s.%s'):format(path, tostring(key)))
    if not ok then
      return false, err
    end
  end

  return true
end

local function rejectUnknownKeys(value, allowed, path)
  if type(value) ~= 'table' then
    return false, path
  end

  for key in pairs(value) do
    if allowed[key] == nil then
      return false, ('%s.%s'):format(path, tostring(key))
    end
  end

  return true
end

local function integerInRange(value, min, max, path)
  local numeric = tonumber(value)
  if numeric == nil or math.floor(numeric) ~= numeric or numeric < min or numeric > max then
    return fail('out_of_range', path)
  end

  return math.floor(numeric)
end

local function normalizeDrawableMap(raw, allowedIds, drawableMin, path)
  raw = raw or {}
  if type(raw) ~= 'table' then
    return fail('invalid_map', path)
  end

  local ok, err = rejectUnknownKeys(raw, allowedIds, path)
  if not ok then
    return fail('unknown_field', err)
  end

  local valueFields = {
    drawable = true,
    texture = true
  }

  local out = {}
  for id in pairs(allowedIds) do
    local item = raw[id] or {}
    if type(item) ~= 'table' then
      return fail('invalid_drawable', ('%s.%s'):format(path, id))
    end

    local itemOk, itemErr = rejectUnknownKeys(item, valueFields, ('%s.%s'):format(path, id))
    if not itemOk then
      return fail('unknown_field', itemErr)
    end

    local drawable, drawableErr = integerInRange(item.drawable or drawableMin, drawableMin, 1000, ('%s.%s.drawable'):format(path, id))
    if drawable == nil then return nil, drawableErr end

    local textureValue = item.texture or 0
    if drawable < 0 then
      textureValue = 0
    end

    local texture, textureErr = integerInRange(textureValue, 0, 100, ('%s.%s.texture'):format(path, id))
    if texture == nil then return nil, textureErr end

    out[id] = {
      drawable = drawable,
      texture = texture
    }
  end

  return out
end

function MZClothingService.normalizeAppearance(payload)
  local maxPayloadBytes = tonumber(Config.MaxPayloadBytes) or 65536
  if getPayloadSize(payload) > maxPayloadBytes then
    return fail('payload_too_large', 'appearance_json')
  end

  local safeOk, safeErr = inspectTable(payload, 1, 'appearance')
  if not safeOk then
    return fail('unsafe_payload', safeErr)
  end

  local wrapperPayload = type(payload) == 'table' and (payload.appearance_json ~= nil or payload.appearance ~= nil)
  if wrapperPayload then
    local wrapperOk, wrapperErr = rejectUnknownKeys(payload, {
      shopId = true,
      appearance_json = true,
      appearance = true
    }, 'payload')
    if not wrapperOk then
      return fail('unknown_field', wrapperErr)
    end
  end

  local raw = wrapperPayload and (payload.appearance_json or payload.appearance) or payload
  raw = decodeJson(raw)
  if type(raw) ~= 'table' then
    return fail('invalid_appearance', 'appearance_json')
  end

  local rawSafeOk, rawSafeErr = inspectTable(raw, 1, 'appearance_json')
  if not rawSafeOk then
    return fail('unsafe_payload', rawSafeErr)
  end

  local topOk, topErr = rejectUnknownKeys(raw, {
    version = true,
    model = true,
    components = true,
    props = true
  }, 'appearance_json')
  if not topOk then
    return fail('unknown_field', topErr)
  end

  if tonumber(raw.version) ~= 1 then
    return fail('invalid_version', 'appearance_json.version')
  end

  local model = tostring(raw.model or '')
  if allowedModels[model] ~= true then
    return fail('invalid_model', model)
  end

  local components, componentErr = normalizeDrawableMap(raw.components, componentIds, 0, 'components')
  if not components then return nil, componentErr end

  local props, propErr = normalizeDrawableMap(raw.props, propIds, -1, 'props')
  if not props then return nil, propErr end

  return {
    version = 1,
    model = model,
    components = components,
    props = props
  }
end

local function rowToOutfit(row)
  if not row then
    return nil
  end

  local appearance = decodeJson(row.appearance_json)
  if type(appearance) ~= 'table' then
    return nil
  end

  return {
    id = row.id,
    citizenid = row.citizenid,
    name = row.name,
    appearance = appearance,
    created_at = row.created_at,
    updated_at = row.updated_at
  }
end

local function chargeIfNeeded(source, shopId)
  if Config.UseMoney ~= true then
    return true
  end

  local price = math.floor(tonumber(Config.ClothingPrice) or 0)
  if price <= 0 then
    return true
  end

  local account = Config.MoneyType or 'wallet'
  local ok, result, err = pcall(function()
    return exports['mz_core']:RemoveMoney(source, account, price, {
      reason = 'clothing_purchase',
      category = 'cosmetic_expense',
      source_resource = 'mz_clothing',
      source_type = 'resource_payment',
      counts_as_income = false,
      counts_as_expense = true,
      external_ref = nil,
      data = {
        action = 'save_current',
        shop_id = tostring(shopId or ''),
        payment_method = account
      }
    })
  end)

  if not ok or result ~= true then
    return false, err or result or 'payment_failed'
  end

  return true
end

local function syncCreatorAppearance(source, appearance)
  if GetResourceState('mz_creator') ~= 'started' then
    return true
  end

  local ok, result = pcall(function()
    return exports['mz_creator']:MergeClothingAppearance(source, appearance)
  end)

  if not ok then
    print(('[mz_clothing][creator_sync_error] source=%s error=%s'):format(tostring(source), tostring(result)))
    return false, 'creator_sync_failed'
  end

  if type(result) ~= 'table' or result.ok ~= true then
    print(('[mz_clothing][creator_sync_error] source=%s result=%s'):format(tostring(source), json.encode(result or {})))
    return false, result and result.error or 'creator_sync_failed'
  end

  return true
end

function MZClothingService.getCurrent(source)
  local player = getPlayer(source)
  if not player or not player.citizenid then
    return {
      ok = false,
      error = 'player_not_loaded'
    }
  end

  local row = MZClothingDatabase.getOutfit(player.citizenid, 'current')
  local outfit = rowToOutfit(row)

  return {
    ok = true,
    outfit = outfit,
    appearance = outfit and outfit.appearance or nil
  }
end

function MZClothingService.saveCurrent(source, payload)
  local player = getPlayer(source)
  if not player or not player.citizenid then
    return {
      ok = false,
      error = 'player_not_loaded'
    }
  end

  debugPrint(('server save requested source=%s citizenid=%s'):format(tostring(source), tostring(player.citizenid)))

  local shopId = tostring(type(payload) == 'table' and payload.shopId or '')
  if shopId ~= '' and not (Config.ClothingShops or {})[shopId] then
    return {
      ok = false,
      error = 'invalid_shop'
    }
  end

  local appearance, validationErr = MZClothingService.normalizeAppearance(payload)
  if not appearance then
    local err = validationErr or {
      ok = false,
      error = 'invalid_appearance'
    }
    debugPrint(('server save failed validation=%s detail=%s'):format(tostring(err.error), tostring(err.detail)))
    return err
  end

  local paid, paymentErr = chargeIfNeeded(source, shopId)
  if not paid then
    debugPrint(('server save failed payment=%s'):format(tostring(paymentErr)))
    return {
      ok = false,
      error = paymentErr or 'payment_failed'
    }
  end

  local saveOk, rowOrErr = pcall(function()
    return MZClothingDatabase.upsertOutfit(player.citizenid, 'current', appearance)
  end)

  if not saveOk then
    print(('[mz_clothing][save_error] citizenid=%s error=%s'):format(tostring(player.citizenid), tostring(rowOrErr)))
    return {
      ok = false,
      error = 'database_error',
      detail = tostring(rowOrErr)
    }
  end

  debugPrint(('server save success citizenid=%s'):format(tostring(player.citizenid)))

  syncCreatorAppearance(source, appearance)

  return {
    ok = true,
    citizenid = player.citizenid,
    outfit = rowToOutfit(rowOrErr),
    appearance = appearance
  }
end

function MZClothingService.listOutfits(source)
  local player = getPlayer(source)
  if not player or not player.citizenid then
    return {
      ok = false,
      error = 'player_not_loaded'
    }
  end

  local outfits = {}
  for _, row in ipairs(MZClothingDatabase.listOutfits(player.citizenid)) do
    local outfit = rowToOutfit(row)
    if outfit then
      outfits[#outfits + 1] = outfit
    end
  end

  return {
    ok = true,
    outfits = outfits
  }
end

lib.callback.register('mz_clothing:server:getCurrent', function(source)
  return MZClothingService.getCurrent(source)
end)

lib.callback.register('mz_clothing:server:saveCurrent', function(source, payload)
  return MZClothingService.saveCurrent(source, payload)
end)

lib.callback.register('mz_clothing:server:listOutfits', function(source)
  return MZClothingService.listOutfits(source)
end)

RegisterNetEvent('mz_clothing:server:requestApplySaved', function()
  local src = source
  local result = MZClothingService.getCurrent(src)
  if result.ok == true and type(result.appearance) == 'table' then
    TriggerClientEvent('mz_clothing:client:applyClothing', src, result.appearance)
  end
end)

exports('GetCurrentOutfit', function(citizenid)
  local row = MZClothingDatabase.getOutfit(citizenid, 'current')
  return rowToOutfit(row)
end)
