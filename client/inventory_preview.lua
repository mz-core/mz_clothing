MZClothingInventoryPreview = {
  active = false,
  ready = false,
  ped = nil,
  pendingPed = nil,
  previousPed = nil,
  generation = 0,
  rebuildRevision = 0,
  hudColour = nil
}

local FRONTEND_MENU = 'FE_MENU_VERSION_EMPTY_NO_BACKGROUND'
local PAUSE_BACKGROUND_COLOUR = 117
local MODEL_LOAD_TIMEOUT_MS = 5000

local function entityExists(entity)
  return entity and entity ~= 0 and DoesEntityExist(entity)
end

local function previewDebug(stage, details)
  if Config.Debug ~= true then return end
  print(('[InventoryPreview] %s%s'):format(
    tostring(stage),
    details and (' | ' .. tostring(details)) or ''
  ))
end

local function deletePreviewPed()
  local ped = MZClothingInventoryPreview.ped
  local pendingPed = MZClothingInventoryPreview.pendingPed
  local previousPed = MZClothingInventoryPreview.previousPed
  if entityExists(ped) then
    DeleteEntity(ped)
  end
  if pendingPed ~= ped and entityExists(pendingPed) then
    DeleteEntity(pendingPed)
  end
  if previousPed ~= ped and previousPed ~= pendingPed and entityExists(previousPed) then
    DeleteEntity(previousPed)
  end
  MZClothingInventoryPreview.ped = nil
  MZClothingInventoryPreview.pendingPed = nil
  MZClothingInventoryPreview.previousPed = nil
end

local function restoreHudColour()
  local colour = MZClothingInventoryPreview.hudColour
  MZClothingInventoryPreview.hudColour = nil
  if not colour then return end

  ReplaceHudColourWithRgba(
    PAUSE_BACKGROUND_COLOUR,
    colour.r,
    colour.g,
    colour.b,
    colour.a
  )
end

local function makePreviewPedSafe(ped)
  SetEntityInvincible(ped, true)
  SetEntityCanBeDamaged(ped, false)
  SetEntityCollision(ped, false, false)
  FreezeEntityPosition(ped, true)
  SetEntityVisible(ped, false, false)
  SetBlockingOfNonTemporaryEvents(ped, true)
  SetPedCanRagdoll(ped, false)
  SetPedCanEvasiveDive(ped, false)
  SetPedCanBeTargetted(ped, false)
end

local function loadPreviewModel(model)
  RequestModel(model)
  local deadline = GetGameTimer() + MODEL_LOAD_TIMEOUT_MS
  while not HasModelLoaded(model) do
    if GetGameTimer() >= deadline then return false end
    Wait(0)
  end
  return true
end

local function createPreviewPed(sourcePed, generation)
  local model = GetEntityModel(sourcePed)
  previewDebug(('model=%s'):format(tostring(model)))
  if not loadPreviewModel(model) then
    SetModelAsNoLongerNeeded(model)
    return nil, 'preview_model_load_timeout'
  end
  if not MZClothingInventoryPreview.active or generation ~= MZClothingInventoryPreview.generation then
    SetModelAsNoLongerNeeded(model)
    return nil, 'preview_generation_changed'
  end

  local coords = GetEntityCoords(sourcePed)
  local previewPed = CreatePed(4, model, coords.x, coords.y, coords.z, GetEntityHeading(sourcePed), false, false)
  SetModelAsNoLongerNeeded(model)
  previewDebug(('ped created=%s'):format(tostring(previewPed)))
  local previewExists = entityExists(previewPed)
  previewDebug(('ped exists=%s'):format(tostring(previewExists)))
  previewDebug(('FRONTEND PREVIEW PED handle=%s'):format(tostring(previewPed)))
  if not previewExists then return nil, 'preview_ped_creation_failed' end
  if type(NetworkGetEntityIsNetworked) == 'function' and NetworkGetEntityIsNetworked(previewPed) then
    DeleteEntity(previewPed)
    return nil, 'preview_ped_must_be_local'
  end

  local prepared, prepareError = pcall(function()
    ClonePedToTarget(sourcePed, previewPed)
    previewDebug('cloned to target')
    makePreviewPedSafe(previewPed)
  end)
  if not prepared then
    DeleteEntity(previewPed)
    return nil, 'preview_prepare_failed:' .. tostring(prepareError)
  end

  return previewPed
end

local function givePreviewPed(previewPed)
  local attached, attachError = pcall(function()
    GivePedToPauseMenu(previewPed, tonumber(Config.InventoryFrontendPedSlot) or 1)
    previewDebug('given to pause menu')
    SetPauseMenuPedLighting(true)
    SetPauseMenuPedSleepState(true)
  end)
  if not attached then
    return nil, 'preview_attach_failed:' .. tostring(attachError)
  end
  if not entityExists(previewPed) then
    return nil, 'preview_ped_missing_after_give'
  end

  return previewPed
end

local function createAndAttachPreviewPed(sourcePed, generation)
  local previewPed, createError = createPreviewPed(sourcePed, generation)
  if not previewPed then return nil, createError end
  local attachedPed, attachError = givePreviewPed(previewPed)
  if not attachedPed then
    if entityExists(previewPed) then DeleteEntity(previewPed) end
    return nil, attachError
  end
  MZClothingInventoryPreview.ped = attachedPed
  return attachedPed
end

local function rebuildPreviewPed(reason, generation)
  if not MZClothingInventoryPreview.active
    or not MZClothingInventoryPreview.ready
    or generation ~= MZClothingInventoryPreview.generation then
    return false, 'preview_not_ready'
  end

  local oldPed = MZClothingInventoryPreview.ped
  previewDebug(('swap begin reason=%s'):format(tostring(reason)))
  previewDebug(('old=%s exists=%s'):format(tostring(oldPed), tostring(entityExists(oldPed))))

  local sourcePed = PlayerPedId()
  if not entityExists(sourcePed) then return false, 'player_ped_unavailable' end

  local newPed, createError = createPreviewPed(sourcePed, generation)
  if not newPed then
    previewDebug('swap aborted reason=create_failed', createError)
    return false, createError
  end
  MZClothingInventoryPreview.pendingPed = newPed
  previewDebug(('new=%s exists=%s'):format(tostring(newPed), tostring(entityExists(newPed))))
  previewDebug(('give new=%s'):format(tostring(newPed)))

  local attachedPed, attachError = givePreviewPed(newPed)
  if not attachedPed then
    MZClothingInventoryPreview.pendingPed = nil
    if entityExists(newPed) then DeleteEntity(newPed) end
    previewDebug('swap aborted reason=give_failed', attachError)
    return false, attachError
  end

  MZClothingInventoryPreview.previousPed = oldPed
  MZClothingInventoryPreview.ped = newPed
  MZClothingInventoryPreview.pendingPed = nil
  Wait(0)
  if not MZClothingInventoryPreview.active
    or generation ~= MZClothingInventoryPreview.generation then
    MZClothingInventoryPreview.pendingPed = nil
    if entityExists(newPed) then DeleteEntity(newPed) end
    return false, 'preview_not_ready'
  end
  if not entityExists(newPed) then
    MZClothingInventoryPreview.previousPed = nil
    if entityExists(oldPed) then
      MZClothingInventoryPreview.ped = oldPed
      givePreviewPed(oldPed)
    else
      MZClothingInventoryPreview.ped = nil
    end
    previewDebug('swap aborted reason=give_failed', 'preview_missing_after_give')
    return false, 'preview_missing_after_give'
  end

  MZClothingInventoryPreview.previousPed = nil
  previewDebug(('active=%s'):format(tostring(newPed)))
  if oldPed ~= newPed and entityExists(oldPed) then
    previewDebug(('delete old=%s'):format(tostring(oldPed)))
    DeleteEntity(oldPed)
  end
  previewDebug('swap complete')
  return true
end

function MZClothingInventoryPreview.close(reason)
  local ownedFrontend = MZClothingInventoryPreview.active
    or MZClothingInventoryPreview.ped ~= nil
    or MZClothingInventoryPreview.pendingPed ~= nil
    or MZClothingInventoryPreview.previousPed ~= nil
    or MZClothingInventoryPreview.hudColour ~= nil

  previewDebug(('cleanup reason=%s'):format(tostring(reason or 'explicit_close')))

  MZClothingInventoryPreview.active = false
  MZClothingInventoryPreview.ready = false
  MZClothingInventoryPreview.generation = MZClothingInventoryPreview.generation + 1
  MZClothingInventoryPreview.rebuildRevision = MZClothingInventoryPreview.rebuildRevision + 1
  if not ownedFrontend then return end

  ClearPedInPauseMenu()
  SetPauseMenuPedSleepState(false)
  SetPauseMenuPedLighting(false)
  SetFrontendActive(false)
  deletePreviewPed()
  restoreHudColour()
end

function MZClothingInventoryPreview.open()
  MZClothingInventoryPreview.close('open_reset')
  local enabled = Config.InventoryFrontendPedPreview == true
  previewDebug('preview enabled', tostring(enabled))
  if not enabled then return false end

  MZClothingInventoryPreview.active = true
  MZClothingInventoryPreview.ready = false
  MZClothingInventoryPreview.generation = MZClothingInventoryPreview.generation + 1
  local generation = MZClothingInventoryPreview.generation

  local ok, r, g, b, a = pcall(GetHudColour, PAUSE_BACKGROUND_COLOUR)
  if ok and type(r) == 'number' and type(g) == 'number' and type(b) == 'number' and type(a) == 'number' then
    MZClothingInventoryPreview.hudColour = { r = r, g = g, b = b, a = a }
  else
    MZClothingInventoryPreview.hudColour = { r = 0, g = 0, b = 0, a = 186 }
  end

  SetFrontendActive(true)
  previewDebug('frontend active')
  ReplaceHudColourWithRgba(PAUSE_BACKGROUND_COLOUR, 0, 0, 0, 0)
  ActivateFrontendMenu(GetHashKey(FRONTEND_MENU), false, -1)
  previewDebug('menu activated')

  CreateThread(function()
    Wait(100)
    if not MZClothingInventoryPreview.active or generation ~= MZClothingInventoryPreview.generation then
      previewDebug('open cancelled', 'generation_changed_before_create')
      return
    end

    local success, errorMessage = pcall(function()
      SetMouseCursorVisibleInMenus(false)
      previewDebug('native menu cursor hidden')

      local sourcePed = PlayerPedId()
      previewDebug(('REAL PED handle=%s'):format(tostring(sourcePed)))
      if not entityExists(sourcePed) then error('player_ped_unavailable') end

      local previewPed, createError = createAndAttachPreviewPed(sourcePed, generation)
      if not previewPed then error(createError) end
      MZClothingInventoryPreview.ready = true

      Wait(100)
      if not entityExists(previewPed) then error('preview_ped_destroyed_after_open') end
      previewDebug('survived 100ms=true')
      previewDebug(('opened ped=%s'):format(tostring(previewPed)))

      while MZClothingInventoryPreview.active and generation == MZClothingInventoryPreview.generation do
        SetMouseCursorVisibleInMenus(false)
        Wait(0)
      end
    end)

    if not success and generation == MZClothingInventoryPreview.generation then
      local reason = tostring(errorMessage)
      print(('[InventoryPreview] open failed reason=%s'):format(reason))
      MZClothingInventoryPreview.close('open_failed:' .. reason)
    end
  end)

  return true
end

function MZClothingInventoryPreview.refresh(reason)
  reason = tostring(reason or '')
  if reason ~= 'equip' and reason ~= 'unequip' then
    previewDebug(('rebuild skipped reason=%s'):format(reason))
    return false
  end
  if not MZClothingInventoryPreview.active then return false end

  MZClothingInventoryPreview.rebuildRevision = MZClothingInventoryPreview.rebuildRevision + 1
  local revision = MZClothingInventoryPreview.rebuildRevision
  local generation = MZClothingInventoryPreview.generation

  CreateThread(function()
    Wait(50)
    if revision ~= MZClothingInventoryPreview.rebuildRevision
      or not MZClothingInventoryPreview.active
      or generation ~= MZClothingInventoryPreview.generation then
      return
    end

    -- The authoritative projection is already on PlayerPed; the debounce also
    -- supplies the minimum next-frame boundary before cloning the replacement.
    local success, rebuilt, rebuildError = pcall(rebuildPreviewPed, reason, generation)
    if not success then
      print(('[InventoryPreview] rebuild failed reason=%s'):format(tostring(rebuilt)))
      return
    end
    if rebuilt ~= true and rebuildError ~= 'preview_not_ready' then
      print(('[InventoryPreview] rebuild failed reason=%s'):format(tostring(rebuildError)))
    end
  end)

  return true
end
