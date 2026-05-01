Config = Config or {}

Config.ClothingShops = {
  clothing_1 = {
    label = 'Loja de Roupas',
    coords = vec3(72.3, -1399.1, 29.4),
    heading = 180.0,

    blip = {
      enabled = true,
      sprite = 73,
      color = 3,
      scale = 0.75,
      label = 'Loja de Roupas'
    },

    interact = {
      enabled = true,
      drawDistance = 25.0,
      interactDistance = 2.0,

      marker = {
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
      },

      text = {
        enabled = true,
        label = '[E] Comprar roupas',
        offsetZ = 0.35
      }
    }
  }
}
