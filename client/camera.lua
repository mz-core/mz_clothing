MZClothingCamera = {
  handle = nil,
  mode = nil,
  zoomOffset = 0.0,
  baseHeading = nil
}

local function getConfig()
  return Config.Camera or {}
end

local fallbackModes = {
  full = {
    label = 'Corpo todo',
    offset = vec3(0.0, 2.6, 0.35),
    point = vec3(0.0, 0.0, 0.25),
    fov = 45.0
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

local function pointCameraAtPed()
  if not MZClothingCamera.handle then
    return
  end

  local ped = PlayerPedId()
  local _, mode = getMode()
  local offset = mode.offset or fallbackModes.full.offset
  local point = mode.point or fallbackModes.full.point
  local coords = GetEntityCoords(ped)
  local heading = MZClothingCamera.baseHeading or GetEntityHeading(ped)
  local zoomedY = (tonumber(offset.y) or 2.6) + MZClothingCamera.zoomOffset
  local camCoords = getOffsetFromHeading(coords, heading, vec3(tonumber(offset.x) or 0.0, zoomedY, tonumber(offset.z) or 0.35))
  local lookAt = getOffsetFromHeading(coords, heading, point)

  SetCamCoord(MZClothingCamera.handle, camCoords.x, camCoords.y, camCoords.z)
  PointCamAtCoord(MZClothingCamera.handle, lookAt.x, lookAt.y, lookAt.z)
  SetCamFov(MZClothingCamera.handle, tonumber(mode.fov) or 45.0)
end

function MZClothingCamera.start()
  MZClothingCamera.stop()

  MZClothingCamera.mode = getConfig().defaultMode or 'full'
  MZClothingCamera.zoomOffset = 0.0
  MZClothingCamera.baseHeading = GetEntityHeading(PlayerPedId())
  MZClothingCamera.handle = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
  pointCameraAtPed()
  RenderScriptCams(true, true, 350, true, true)
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
end

function MZClothingCamera.rotate(amount)
  local ped = PlayerPedId()
  SetEntityHeading(ped, (GetEntityHeading(ped) + (tonumber(amount) or 0.0)) % 360.0)
  pointCameraAtPed()
end

function MZClothingCamera.zoomIn()
  local step = tonumber(getConfig().zoomStep) or 0.25
  MZClothingCamera.zoomOffset = clampZoom(MZClothingCamera.zoomOffset - step)
  pointCameraAtPed()
end

function MZClothingCamera.zoomOut()
  local step = tonumber(getConfig().zoomStep) or 0.25
  MZClothingCamera.zoomOffset = clampZoom(MZClothingCamera.zoomOffset + step)
  pointCameraAtPed()
end

function MZClothingCamera.reset()
  MZClothingCamera.mode = getConfig().defaultMode or 'full'
  MZClothingCamera.zoomOffset = 0.0
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
