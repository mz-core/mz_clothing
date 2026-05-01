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

local function integerOr(value, fallback)
  local numeric = tonumber(value)
  if numeric == nil then
    return fallback
  end

  return math.floor(numeric)
end

local function clone(value)
  if type(value) ~= 'table' then
    return value
  end

  local out = {}
  for key, child in pairs(value) do
    out[key] = clone(child)
  end
  return out
end

function MZClothingAppearance.getDefinitions()
  return {
    components = clone(componentDefs),
    props = clone(propDefs)
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

function MZClothingAppearance.getLimits(appearance)
  local ped = PlayerPedId()
  local limits = {
    components = {},
    props = {}
  }

  appearance = appearance or MZClothingAppearance.capture()

  for _, def in ipairs(componentDefs) do
    local current = appearance.components and appearance.components[tostring(def.id)] or {}
    local drawable = integerOr(current.drawable, GetPedDrawableVariation(ped, def.id))
    local drawableMax = math.max((GetNumberOfPedDrawableVariations(ped, def.id) or 1) - 1, 0)
    local textureMax = math.max((GetNumberOfPedTextureVariations(ped, def.id, drawable) or 1) - 1, 0)

    limits.components[tostring(def.id)] = {
      drawableMax = drawableMax,
      textureMax = textureMax
    }
  end

  for _, def in ipairs(propDefs) do
    local current = appearance.props and appearance.props[tostring(def.id)] or {}
    local drawable = integerOr(current.drawable, GetPedPropIndex(ped, def.id))
    local drawableMax = math.max((GetNumberOfPedPropDrawableVariations(ped, def.id) or 1) - 1, -1)
    local textureMax = 0

    if drawable >= 0 then
      textureMax = math.max((GetNumberOfPedPropTextureVariations(ped, def.id, drawable) or 1) - 1, 0)
    end

    limits.props[tostring(def.id)] = {
      drawableMax = drawableMax,
      textureMax = textureMax
    }
  end

  return limits
end

function MZClothingAppearance.clone(value)
  return clone(value)
end
