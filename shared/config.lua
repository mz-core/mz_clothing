Config = Config or {}

Config.Debug = false

Config.UseMzInteract = true
Config.FallbackToLegacyMarkers = true

Config.DefaultKey = 38 -- E
Config.DefaultDrawDistance = 25.0
Config.DefaultInteractDistance = 2.0
Config.DefaultLoopSleep = 1000
Config.NearLoopSleep = 0
Config.InteractCooldownMs = 800

Config.ClothingPrice = 500
Config.UseMoney = false
Config.MoneyType = 'wallet'

Config.MaxPayloadBytes = 65536

Config.DefaultMarker = {
  enabled = true,
  type = 9,
  textureDict = 'mod_icon',
  textureName = 'arsenal_icon',
  rotation = vec3(90.0, 0.0, 0.0),
  size = vec3(0.75, 0.75, 0.75),
  color = { r = 255, g = 255, b = 255, a = 230 },
  rotate = true,
  bobUpAndDown = true,
  faceCamera = true
}

Config.DefaultBlip = {
  enabled = true,
  sprite = 73,
  color = 3,
  scale = 0.75,
  label = 'Loja de Roupas'
}

Config.DefaultText = {
  enabled = true,
  label = '[E] Comprar roupas',
  offsetZ = 0.35
}

Config.Camera = {
  defaultMode = 'full',
  zoomStep = 0.25,
  minZoomOffset = -0.75,
  maxZoomOffset = 0.75,
  rotateStep = 18.0,
  modes = {
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
}

Config.DebugCommand = 'clothing_test'
