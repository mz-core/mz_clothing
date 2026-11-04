MZClothingAppearance = {}

local componentDefs = {
  { id = 11, key = 'top', label = 'Jaqueta / Top' },
  { id = 8, key = 'undershirt', label = 'Camisa interna' },
  { id = 3, key = 'arms', label = 'Bracos' },
  { id = 4, key = 'pants', label = 'Calca' },
  { id = 6, key = 'shoes', label = 'Sapatos' },
  { id = 1, key = 'mask', label = 'Mascara' },
  { id = 9, key = 'vest', label = 'Colete' },
  { id = 10, key = 'decals', label = 'Decals' },
  { id = 7, key = 'accessories', label = 'Acessorios' },
  { id = 5, key = 'bag', label = 'Bolsa / Mochila' }
}

local propDefs = {
  { id = 0, key = 'hat', label = 'Chapeu' },
  { id = 1, key = 'glasses', label = 'Oculos' },
  { id = 2, key = 'ears', label = 'Brincos' },
  { id = 6, key = 'watch', label = 'Relogio' },
  { id = 7, key = 'bracelet', label = 'Pulseira' }
}

local function getModelName(ped)
  local model = GetEntityModel(ped)
  if model == joaat('mp_f_freemode_01') then
    return 'mp_f_freemode_01'
  end

  return 'mp_m_freemode_01'
end

function MZClothingAppearance.getModelName()
  return getModelName(PlayerPedId())
end

local function integerOr(value, fallback)
  local numeric = tonumber(value)
  if numeric == nil then
    return fallback
  end

  return math.floor(numeric)
end

local componentDefaults = {
  [1] = 0, [3] = 15, [4] = 21, [5] = 0, [6] = 34,
  [7] = 0, [8] = 15, [9] = 0, [10] = 0, [11] = 15
}

local function applyVariant(ped, variant)
  if type(variant) ~= 'table' then return false end
  local nativeId = integerOr(variant.native_id, -1)
  local drawable = integerOr(variant.drawable, -1)
  local texture = math.max(0, integerOr(variant.texture, 0))
  if variant.kind == 'prop' then
    if nativeId < 0 or nativeId > 7 then return false end
    if drawable < 0 then ClearPedProp(ped, nativeId) return true end
    if type(variant.collection) == 'string' then
      SetPedCollectionPropIndex(ped, nativeId, variant.collection, drawable, texture, true)
      return true
    end
    if drawable >= (GetNumberOfPedPropDrawableVariations(ped, nativeId) or 0) then return false end
    SetPedPropIndex(ped, nativeId, drawable, texture, true)
    return true
  end
  if variant.kind ~= 'component' or nativeId < 0 or nativeId > 11 or drawable < 0 then return false end
  if type(variant.collection) == 'string' then
    SetPedCollectionComponentVariation(
      ped, nativeId, variant.collection, drawable, texture, integerOr(variant.palette, 0)
    )
    return true
  end
  if drawable >= (GetNumberOfPedDrawableVariations(ped, nativeId) or 0) then return false end
  SetPedComponentVariation(ped, nativeId, drawable, texture, integerOr(variant.palette, 0))
  return true
end

local function drawableCount(ped, category, collection)
  if type(GetPedCollectionsCount) == 'function' then
    if category.kind == 'prop' then
      return math.max(0, GetNumberOfPedCollectionPropDrawableVariations(
        ped, category.native_id, collection
      ) or 0)
    end
    return math.max(0, GetNumberOfPedCollectionDrawableVariations(
      ped, category.native_id, collection
    ) or 0)
  end
  if category.kind == 'prop' then
    return math.max(0, GetNumberOfPedPropDrawableVariations(ped, category.native_id) or 0)
  end
  return math.max(0, GetNumberOfPedDrawableVariations(ped, category.native_id) or 0)
end

local function textureCount(ped, category, collection, drawable)
  if type(GetPedCollectionsCount) == 'function' then
    if category.kind == 'prop' then
      return math.max(1, GetNumberOfPedCollectionPropTextureVariations(
        ped, category.native_id, collection, drawable
      ) or 0)
    end
    return math.max(1, GetNumberOfPedCollectionTextureVariations(
      ped, category.native_id, collection, drawable
    ) or 0)
  end
  if category.kind == 'prop' then
    return math.max(1, GetNumberOfPedPropTextureVariations(ped, category.native_id, drawable) or 0)
  end
  return math.max(1, GetNumberOfPedTextureVariations(ped, category.native_id, drawable) or 0)
end

function MZClothingAppearance.enumerate(categories)
  local ped = PlayerPedId()
  local result = {}
  local collectionNames = { '' }
  if type(GetPedCollectionsCount) == 'function' then
    collectionNames = {}
    for index = 0, (GetPedCollectionsCount(ped) or 0) - 1 do
      collectionNames[#collectionNames + 1] = tostring(GetPedCollectionName(ped, index) or '')
    end
  end

  for _, category in ipairs(type(categories) == 'table' and categories or {}) do
    local entry = {
      slot = tostring(category.slot),
      label = tostring(category.label or category.slot),
      group = tostring(category.group or 'accessories'),
      kind = tostring(category.kind),
      native_id = integerOr(category.native_id, -1),
      price = math.max(0, integerOr(category.price, 0)),
      camera = tostring(category.camera or 'full'),
      collections = {},
      model_count = 0
    }
    if (entry.kind == 'component' or entry.kind == 'prop') and entry.native_id >= 0 then
      for _, collection in ipairs(collectionNames) do
        local count = drawableCount(ped, entry, collection)
        if count > 0 then
          entry.collections[#entry.collections + 1] = { name = collection, count = count }
          entry.model_count = entry.model_count + count
        end
      end
    end
    if entry.model_count > 0 then result[#result + 1] = entry end
  end
  return result
end

function MZClothingAppearance.select(category, current, modelDelta, textureDelta)
  if type(category) ~= 'table' or type(category.collections) ~= 'table'
      or #category.collections == 0 then return nil, 'category_empty' end
  local ped = PlayerPedId()
  local total = math.max(1, integerOr(category.model_count, 1))
  local absolute = integerOr(current and current.model_index, 1) - 1
  absolute = (absolute + integerOr(modelDelta, 0)) % total

  local remaining = absolute
  local collection = category.collections[1]
  local drawable = 0
  for _, candidate in ipairs(category.collections) do
    if remaining < candidate.count then
      collection = candidate
      drawable = remaining
      break
    end
    remaining = remaining - candidate.count
  end

  local textures = textureCount(ped, category, collection.name, drawable)
  local texture = integerOr(current and current.texture, 0)
  if integerOr(modelDelta, 0) ~= 0 then texture = 0 end
  texture = (texture + integerOr(textureDelta, 0)) % textures
  local variant = {
    slot = category.slot,
    model = getModelName(ped),
    collection = tostring(collection.name or ''),
    drawable = drawable,
    texture = texture,
    palette = 0
  }
  local applied = applyVariant(ped, {
    kind = category.kind,
    native_id = category.native_id,
    collection = variant.collection,
    drawable = variant.drawable,
    texture = variant.texture,
    palette = variant.palette
  })
  if not applied then return nil, 'invalid_variant' end
  return {
    variant = variant,
    model_index = absolute + 1,
    model_count = total,
    texture = texture,
    texture_count = textures
  }
end

function MZClothingAppearance.capture()
  local ped = PlayerPedId()
  local appearance = {
    version = 1,
    model = getModelName(ped),
    components = {},
    props = {}
  }

  for _, def in ipairs(componentDefs) do
    appearance.components[tostring(def.id)] = {
      drawable = GetPedDrawableVariation(ped, def.id),
      texture = GetPedTextureVariation(ped, def.id)
    }
  end

  for _, def in ipairs(propDefs) do
    local drawable = GetPedPropIndex(ped, def.id)
    local texture = 0

    if drawable >= 0 then
      texture = math.max(GetPedPropTextureIndex(ped, def.id) or 0, 0)
    end

    appearance.props[tostring(def.id)] = {
      drawable = drawable,
      texture = texture
    }
  end

  return appearance
end

function MZClothingAppearance.apply(appearance)
  if type(appearance) ~= 'table' then
    return false
  end

  if type(appearance.appearance_json) == 'table' then
    appearance = appearance.appearance_json
  end

  local ped = PlayerPedId()
  local components = type(appearance.components) == 'table' and appearance.components or {}
  local props = type(appearance.props) == 'table' and appearance.props or {}

  for _, def in ipairs(componentDefs) do
    local item = components[tostring(def.id)]
    if type(item) == 'table' then
      SetPedComponentVariation(
        ped,
        def.id,
        integerOr(item.drawable, 0),
        integerOr(item.texture, 0),
        2
      )
    end
  end

  for _, def in ipairs(propDefs) do
    local item = props[tostring(def.id)]
    if type(item) == 'table' then
      local drawable = integerOr(item.drawable, -1)
      if drawable < 0 then
        ClearPedProp(ped, def.id)
      else
        SetPedPropIndex(ped, def.id, drawable, integerOr(item.texture, 0), true)
      end
    end
  end

  return true
end

function MZClothingAppearance.applyVariant(variant)
  return applyVariant(PlayerPedId(), variant)
end

function MZClothingAppearance.applyProjection(projection)
  if type(projection) ~= 'table' then return false end
  local ped = PlayerPedId()
  local female = GetEntityModel(ped) == joaat('mp_f_freemode_01')
  for componentId, drawable in pairs(componentDefaults) do
    if componentId == 4 and female then drawable = 15 end
    if componentId == 6 and female then drawable = 35 end
    SetPedComponentVariation(ped, componentId, drawable, 0, 2)
  end
  for _, propId in ipairs({ 0, 1, 2, 6, 7 }) do ClearPedProp(ped, propId) end
  for _, item in ipairs(projection.items or {}) do applyVariant(ped, item.variant) end
  return true
end
