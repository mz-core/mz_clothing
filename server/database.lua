MZClothingDatabase = {}

local ready = false

local function decode(value, fallback)
  if type(value) == 'table' then return value end
  local ok, decoded = pcall(json.decode, value or '')
  return ok and decoded or fallback
end

function MZClothingDatabase.isReady()
  return ready == true
end

local function prepare()
  MySQL.query.await([[
    CREATE TABLE IF NOT EXISTS mz_clothing_outfits (
      id INT AUTO_INCREMENT PRIMARY KEY,
      citizenid VARCHAR(32) NOT NULL,
      name VARCHAR(32) NOT NULL,
      slots_json LONGTEXT NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      UNIQUE KEY uq_mz_clothing_outfits_citizenid_name (citizenid, name),
      KEY idx_mz_clothing_outfits_citizenid (citizenid)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  ]])

  MySQL.query.await([[
    CREATE TABLE IF NOT EXISTS mz_clothing_purchase_operations (
      id BIGINT AUTO_INCREMENT PRIMARY KEY,
      citizenid VARCHAR(32) NOT NULL,
      operation_id VARCHAR(64) NOT NULL,
      shop_id VARCHAR(64) NOT NULL,
      garment_id VARCHAR(64) NOT NULL,
      variant_json LONGTEXT NULL,
      equip_requested TINYINT(1) NOT NULL DEFAULT 0,
      status VARCHAR(24) NOT NULL DEFAULT 'pending',
      instance_uid VARCHAR(64) NULL,
      error_code VARCHAR(64) NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      UNIQUE KEY uq_mz_clothing_purchase_operation (citizenid, operation_id),
      KEY idx_mz_clothing_purchase_instance (instance_uid)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  ]])

  local variantColumn = MySQL.single.await([[
    SELECT COUNT(*) AS total
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'mz_clothing_purchase_operations'
      AND COLUMN_NAME = 'variant_json'
  ]])
  if tonumber(variantColumn and variantColumn.total) == 0 then
    MySQL.query.await('ALTER TABLE mz_clothing_purchase_operations ADD COLUMN variant_json LONGTEXT NULL AFTER garment_id')
  end

  local legacy = MySQL.single.await([[
    SELECT COUNT(*) AS total
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'mz_clothing_outfits'
      AND COLUMN_NAME = 'appearance_json'
  ]])
  if tonumber(legacy and legacy.total) > 0 then
    error('legacy_clothing_schema_reset_required')
  end
  ready = true
end

function MZClothingDatabase.upsertOutfit(citizenid, name, slots)
  MySQL.insert.await([[
    INSERT INTO mz_clothing_outfits (citizenid, name, slots_json)
    VALUES (?, ?, ?)
    ON DUPLICATE KEY UPDATE slots_json = VALUES(slots_json), updated_at = CURRENT_TIMESTAMP
  ]], { citizenid, name, json.encode(slots or {}) })
  return MZClothingDatabase.getOutfit(citizenid, name)
end

function MZClothingDatabase.getOutfit(citizenid, name)
  local row = MySQL.single.await([[
    SELECT id, citizenid, name, slots_json, created_at, updated_at
    FROM mz_clothing_outfits WHERE citizenid = ? AND name = ? LIMIT 1
  ]], { citizenid, name })
  if row then row.slots = decode(row.slots_json, {}) end
  return row
end

function MZClothingDatabase.listOutfits(citizenid)
  local rows = MySQL.query.await([[
    SELECT id, citizenid, name, slots_json, created_at, updated_at
    FROM mz_clothing_outfits WHERE citizenid = ? ORDER BY updated_at DESC
  ]], { citizenid }) or {}
  for _, row in ipairs(rows) do row.slots = decode(row.slots_json, {}) end
  return rows
end

function MZClothingDatabase.deleteOutfit(citizenid, name)
  return MySQL.update.await(
    'DELETE FROM mz_clothing_outfits WHERE citizenid = ? AND name = ?',
    { citizenid, name }
  )
end

function MZClothingDatabase.getPurchase(citizenid, operationId)
  local row = MySQL.single.await([[
    SELECT * FROM mz_clothing_purchase_operations
    WHERE citizenid = ? AND operation_id = ? LIMIT 1
  ]], { citizenid, operationId })
  if row then row.variant = decode(row.variant_json, nil) end
  return row
end

function MZClothingDatabase.beginPurchase(citizenid, operationId, shopId, variantId, variant)
  MySQL.insert.await([[
    INSERT INTO mz_clothing_purchase_operations
      (citizenid, operation_id, shop_id, garment_id, variant_json, equip_requested, status)
    VALUES (?, ?, ?, ?, ?, 0, 'pending')
    ON DUPLICATE KEY UPDATE operation_id = operation_id
  ]], { citizenid, operationId, shopId, variantId, json.encode(variant or {}) })
  return MZClothingDatabase.getPurchase(citizenid, operationId)
end

function MZClothingDatabase.finishPurchase(citizenid, operationId, status, instanceUid, errorCode)
  status = tostring(status or ''):sub(1, 24)
  instanceUid = instanceUid and tostring(instanceUid):sub(1, 64) or nil
  errorCode = errorCode and tostring(errorCode):sub(1, 64) or nil
  MySQL.update.await([[
    UPDATE mz_clothing_purchase_operations
    SET status = ?, instance_uid = ?, error_code = ?, updated_at = CURRENT_TIMESTAMP
    WHERE citizenid = ? AND operation_id = ?
  ]], { status, instanceUid, errorCode, citizenid, operationId })
end

CreateThread(function()
  local ok, err = pcall(prepare)
  if not ok then
    ready = false
    print(('[mz_clothing][schema][ERROR] %s; reset the disposable staging clothing tables manually'):format(tostring(err)))
  end
end)
