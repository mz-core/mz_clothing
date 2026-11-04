Config = Config or {}

-- A loja vende variantes reais do ped; esta tabela define apenas os slots,
-- precos e o endereco nativo que o servidor aceita.
Config.ClothingCategories = {
  { slot = 'hat', label = 'Chapeu', group = 'head', kind = 'prop', native_id = 0, price = 180, camera = 'face' },
  { slot = 'glasses', label = 'Oculos', group = 'head', kind = 'prop', native_id = 1, price = 220, camera = 'face' },
  { slot = 'ears', label = 'Brincos', group = 'head', kind = 'prop', native_id = 2, price = 160, camera = 'face' },
  { slot = 'mask', label = 'Mascara', group = 'head', kind = 'component', native_id = 1, price = 260, camera = 'face' },
  { slot = 'neck', label = 'Acessorio', group = 'accessories', kind = 'component', native_id = 7, price = 240, camera = 'full' },
  { slot = 'undershirt', label = 'Camisa', group = 'torso', kind = 'component', native_id = 8, price = 300, camera = 'full' },
  { slot = 'torso', label = 'Jaqueta', group = 'torso', kind = 'component', native_id = 11, price = 650, camera = 'full' },
  { slot = 'arms_gloves', label = 'Bracos', group = 'arms', kind = 'component', native_id = 3, price = 220, camera = 'full' },
  { slot = 'backpack', label = 'Mochila', group = 'accessories', kind = 'component', native_id = 5, price = 520, camera = 'full' },
  { slot = 'legs', label = 'Calca', group = 'legs', kind = 'component', native_id = 4, price = 420, camera = 'legs' },
  { slot = 'shoes', label = 'Calcado', group = 'shoes', kind = 'component', native_id = 6, price = 380, camera = 'legs' },
  { slot = 'watch', label = 'Relogio', group = 'accessories', kind = 'prop', native_id = 6, price = 280, camera = 'full' },
  { slot = 'bracelet', label = 'Pulseira', group = 'accessories', kind = 'prop', native_id = 7, price = 240, camera = 'full' }
}
