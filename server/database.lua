MZClothingDatabase = {}

local function prepare()
  MySQL.query.await([[
    CREATE TABLE IF NOT EXISTS mz_clothing_outfits (
      id INT AUTO_INCREMENT PRIMARY KEY,
      citizenid VARCHAR(32) NOT NULL,
      name VARCHAR(32) NOT NULL DEFAULT 'current',
      appearance_json LONGTEXT NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      UNIQUE KEY uq_mz_clothing_outfits_citizenid_name (citizenid, name),
      KEY idx_mz_clothing_outfits_citizenid (citizenid)
    )
  ]])

  if Config.Debug == true then
    print('[mz_clothing] database prepared')
  end
end

function MZClothingDatabase.upsertOutfit(citizenid, name, appearance)
  local encoded = json.encode(appearance or {})

  MySQL.insert.await([[
    INSERT INTO mz_clothing_outfits (citizenid, name, appearance_json)
    VALUES (?, ?, ?)
    ON DUPLICATE KEY UPDATE
      appearance_json = VALUES(appearance_json)
  ]], {
    citizenid,
    name,
    encoded
  })

  return MZClothingDatabase.getOutfit(citizenid, name)
end

function MZClothingDatabase.getOutfit(citizenid, name)
  return MySQL.single.await([[
    SELECT *
    FROM mz_clothing_outfits
    WHERE citizenid = ? AND name = ?
    LIMIT 1
  ]], {
    citizenid,
    name or 'current'
  })
end

function MZClothingDatabase.listOutfits(citizenid)
  return MySQL.query.await([[
    SELECT id, citizenid, name, appearance_json, created_at, updated_at
    FROM mz_clothing_outfits
    WHERE citizenid = ?
    ORDER BY updated_at DESC
  ]], {
    citizenid
  }) or {}
end

function MZClothingDatabase.deleteOutfit(citizenid, name)
  return MySQL.update.await([[
    DELETE FROM mz_clothing_outfits
    WHERE citizenid = ? AND name = ?
  ]], {
    citizenid,
    name
  })
end

CreateThread(function()
  local ok, err = pcall(prepare)
  if not ok then
    print(('[mz_clothing] database prepare failed: %s'):format(tostring(err)))
  end
end)
