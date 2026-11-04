MZClothingCamera = {
  handle = nil,
  mode = nil,
  zoomOffset = 0.0,
  baseHeading = nil,
  orbitAngle = 0.0,
  targetPed = nil
}

local function getConfig()
  return Config.Camera or {}
end

local fallbackModes = {
  full = {
    label = 'Corpo todo',
    offset = vec3(0.0, 3.2, 0.72),
    point = vec3(0.0, 0.0, 0.78),
    fov = 42.0
  },
  face = {
    label = 'Rosto',
    offset = vec3(0.0, 1.0, 0.72),
    point = vec3(0.0, 0.0, 0.68),
    fov = 35.0
  },
  legs = {
    label = 'Pernas/Pes',
    offset = vec3(0.0, 1.8, -0.45),
    point = vec3(0.0, 0.0, -0.55),
    fov = 38.0
  }
}

local function getModes()
  return getConfig().modes or fallbackModes
end

local function getMode(mode)
  local modes = getModes()
  local modeName = tostring(mode or MZClothingCamera.mode or getConfig().defaultMode or 'full')

  if not modes[modeName] then
    modeName = 'full'
  end

  return modeName, modes[modeName] or fallbackModes.full
end

local function clampZoom(value)
  local cfg = getConfig()
  local minZoom = tonumber(cfg.minZoomOffset) or -0.75
  local maxZoom = tonumber(cfg.maxZoomOffset) or 0.75
  local zoom = tonumber(value) or 0.0

  if zoom < minZoom then zoom = minZoom end
  if zoom > maxZoom then zoom = maxZoom end

  return zoom
end

local function getOffsetFromHeading(coords, heading, offset)
  local radians = math.rad(heading)
  local sinHeading = math.sin(radians)
  local cosHeading = math.cos(radians)
  local x = tonumber(offset.x) or 0.0
  local y = tonumber(offset.y) or 0.0
  local z = tonumber(offset.z) or 0.0

  return vec3(
    coords.x + (x * cosHeading) - (y * sinHeading),
    coords.y + (x * sinHeading) + (y * cosHeading),
    coords.z + z
  )
end

local function entityExists(entity)
  return entity and entity ~= 0 and DoesEntityExist(entity)
end

local function startCamera(targetPed)
  if not entityExists(targetPed) then return false end

  MZClothingCamera.targetPed = targetPed
  MZClothingCamera.mode = getConfig().defaultMode or 'full'
  MZClothingCamera.zoomOffset = 0.0
  MZClothingCamera.baseHeading = GetEntityHeading(targetPed)
  MZClothingCamera.orbitAngle = 0.0
  MZClothingCamera.handle = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
  if not MZClothingCamera.handle or MZClothingCamera.handle == 0 then
    MZClothingCamera.handle = nil
    return false
  end
  return true
end

local function pointCameraAtPed()
  if not MZClothingCamera.handle then
    return
  end

  local ped = MZClothingCamera.targetPed
  if not entityExists(ped) then return end
  local _, mode = getMode()
  local offset = mode.offset or fallbackModes.full.offset
  local point = mode.point or fallbackModes.full.point
  local coords = GetEntityCoords(ped)
  local heading = (MZClothingCamera.baseHeading or GetEntityHeading(ped))
    + (tonumber(MZClothingCamera.orbitAngle) or 0.0)
  local zoomedY = (tonumber(offset.y) or 2.6) + MZClothingCamera.zoomOffset
  local camCoords = getOffsetFromHeading(coords, heading, vec3(tonumber(offset.x) or 0.0, zoomedY, tonumber(offset.z) or 0.35))
  local lookAt = getOffsetFromHeading(coords, heading, point)

  SetCamCoord(MZClothingCamera.handle, camCoords.x, camCoords.y, camCoords.z)
  PointCamAtCoord(MZClothingCamera.handle, lookAt.x, lookAt.y, lookAt.z)
  SetCamFov(MZClothingCamera.handle, tonumber(mode.fov) or 45.0)
end

function MZClothingCamera.start()
  MZClothingCamera.stop()
  if not startCamera(PlayerPedId()) then return false end
  pointCameraAtPed()
  RenderScriptCams(true, true, 350, true, true)
  return true
end

function MZClothingCamera.stop()
  if MZClothingCamera.handle then
    RenderScriptCams(false, true, 250, true, true)
    DestroyCam(MZClothingCamera.handle, false)
    MZClothingCamera.handle = nil
  end

  MZClothingCamera.mode = nil
  MZClothingCamera.zoomOffset = 0.0
  MZClothingCamera.baseHeading = nil
  MZClothingCamera.orbitAngle = 0.0
  MZClothingCamera.targetPed = nil
end

function MZClothingCamera.rotate(amount)
  if not MZClothingCamera.handle then return end
  amount = math.max(-18.0, math.min(18.0, tonumber(amount) or 0.0))
  MZClothingCamera.orbitAngle = (MZClothingCamera.orbitAngle + amount) % 360.0
  pointCameraAtPed()
end

function MZClothingCamera.zoomIn()
  if not MZClothingCamera.handle then return end
  local step = tonumber(getConfig().zoomStep) or 0.25
  MZClothingCamera.zoomOffset = clampZoom(MZClothingCamera.zoomOffset - step)
  pointCameraAtPed()
end

function MZClothingCamera.zoomOut()
  if not MZClothingCamera.handle then return end
  local step = tonumber(getConfig().zoomStep) or 0.25
  MZClothingCamera.zoomOffset = clampZoom(MZClothingCamera.zoomOffset + step)
  pointCameraAtPed()
end

function MZClothingCamera.reset()
  MZClothingCamera.mode = getConfig().defaultMode or 'full'
  MZClothingCamera.zoomOffset = 0.0
  MZClothingCamera.orbitAngle = 0.0
  pointCameraAtPed()
end

function MZClothingCamera.setMode(mode)
  local modeName = getMode(mode)
  MZClothingCamera.mode = modeName
  MZClothingCamera.zoomOffset = 0.0
  pointCameraAtPed()
end

function MZClothingCamera.getUiModes()
  local modes = getModes()
  local order = { 'full', 'face', 'legs' }
  local out = {}

  for _, modeName in ipairs(order) do
    local mode = modes[modeName]
    if mode then
      out[#out + 1] = {
        id = modeName,
        label = mode.label or modeName
      }
    end
  end

  return out
end
