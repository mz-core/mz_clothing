(() => {
  const resourceName =
    typeof GetParentResourceName === "function"
      ? GetParentResourceName()
      : "mz_clothing";

  const app = document.getElementById("app");
  const items = document.getElementById("items");
  const cameraModes = document.getElementById("camera-modes");
  const shopTitle = document.getElementById("shop-title");
  const price = document.getElementById("price");
  const confirmModal = document.getElementById("confirm-modal");
  const modalError = document.getElementById("modal-error");
  const modalConfirm = document.getElementById("modal-confirm");
  const modalCancel = document.getElementById("modal-cancel");

  const state = {
    open: false,
    busy: false,
    tab: "components",
    cameraMode: "full",
    appearance: null,
    limits: { components: {}, props: {} },
    definitions: { components: [], props: [] },
    cameraModes: [],
  };

  function clone(value) {
    return JSON.parse(JSON.stringify(value));
  }

  async function post(name, data = {}) {
    const response = await fetch(`https://${resourceName}/${name}`, {
      method: "POST",
      headers: { "Content-Type": "application/json; charset=UTF-8" },
      body: JSON.stringify(data),
    });
    return response.json();
  }

  function getPart(type, id) {
    const bucket = state.appearance?.[type] || {};
    const key = String(id);
    bucket[key] = bucket[key] || { drawable: type === "props" ? -1 : 0, texture: 0 };
    state.appearance[type] = state.appearance[type] || {};
    state.appearance[type][key] = bucket[key];
    return bucket[key];
  }

  function getLimit(type, id) {
    return state.limits?.[type]?.[String(id)] || { drawableMax: 0, textureMax: 0 };
  }

  function clamp(value, min, max) {
    const numeric = Number(value);
    if (!Number.isFinite(numeric)) return min;
    return Math.max(min, Math.min(max, Math.trunc(numeric)));
  }

  async function preview() {
    if (!state.appearance || state.busy) return;
    const result = await post("preview", { appearance: state.appearance });
    if (result?.ok && result.limits) {
      state.limits = result.limits;
      renderItems();
    }
  }

  function setBusy(value) {
    state.busy = Boolean(value);
    document.querySelectorAll("button").forEach((button) => {
      button.disabled = state.busy;
    });
  }

  function showModalError(message) {
    modalError.textContent = message || "Nao foi possivel salvar a roupa.";
    modalError.classList.add("visible");
  }

  function clearModalError() {
    modalError.textContent = "";
    modalError.classList.remove("visible");
  }

  function openConfirmModal() {
    clearModalError();
    confirmModal.classList.remove("hidden");
  }

  function closeConfirmModal() {
    confirmModal.classList.add("hidden");
    clearModalError();
  }

  function updatePart(type, id, field, delta) {
    const part = getPart(type, id);
    const limit = getLimit(type, id);
    const min = type === "props" && field === "drawable" ? -1 : 0;
    const max = field === "drawable" ? limit.drawableMax : limit.textureMax;
    part[field] = clamp((part[field] ?? min) + delta, min, max);

    if (field === "drawable") {
      part.texture = 0;
    }

    renderItems();
    preview().catch(() => {});
  }

  function renderItems() {
    const defs = state.definitions[state.tab] || [];
    items.innerHTML = "";

    defs.forEach((def) => {
      const type = state.tab;
      const part = getPart(type, def.id);
      const limit = getLimit(type, def.id);
      const element = document.createElement("article");
      element.className = "item";
      element.innerHTML = `
        <div class="item-title">${def.label}</div>
        <div class="row">
          <span>Modelo</span>
          <button class="step-button" data-field="drawable" data-delta="-1" type="button">-</button>
          <div class="value">${part.drawable} / ${limit.drawableMax}</div>
          <button class="step-button" data-field="drawable" data-delta="1" type="button">+</button>
        </div>
        <div class="row">
          <span>Textura</span>
          <button class="step-button" data-field="texture" data-delta="-1" type="button">-</button>
          <div class="value">${part.texture} / ${limit.textureMax}</div>
          <button class="step-button" data-field="texture" data-delta="1" type="button">+</button>
        </div>
      `;

      element.querySelectorAll(".step-button").forEach((button) => {
        button.addEventListener("click", () => {
          updatePart(type, def.id, button.dataset.field, Number(button.dataset.delta));
        });
      });

      items.appendChild(element);
    });
  }

  function renderCameraModes() {
    cameraModes.innerHTML = "";
    const modes = state.cameraModes.length
      ? state.cameraModes
      : [
          { id: "full", label: "Corpo todo" },
          { id: "face", label: "Rosto" },
          { id: "legs", label: "Pernas/Pes" },
        ];

    modes.forEach((mode) => {
      const button = document.createElement("button");
      button.className = `mode-button${mode.id === state.cameraMode ? " active" : ""}`;
      button.type = "button";
      button.textContent = mode.label;
      button.addEventListener("click", () => {
        state.cameraMode = mode.id;
        renderCameraModes();
        post("setCameraMode", { mode: mode.id });
      });
      cameraModes.appendChild(button);
    });
  }

  function open(payload) {
    state.open = true;
    state.cameraMode = "full";
    state.appearance = clone(payload.appearance);
    state.limits = payload.limits || state.limits;
    state.definitions = payload.definitions || state.definitions;
    state.cameraModes = payload.cameraModes || [];
    shopTitle.textContent = payload.shop?.label || "Loja de Roupas";
    price.textContent = payload.useMoney ? `$${payload.price || 0}` : "Gratis";
    document.body.classList.add("is-open");
    renderCameraModes();
    renderItems();
  }

  function close() {
    state.open = false;
    closeConfirmModal();
    document.body.classList.remove("is-open");
  }

  document.querySelectorAll(".tab").forEach((button) => {
    button.addEventListener("click", () => {
      state.tab = button.dataset.tab;
      document.querySelectorAll(".tab").forEach((tab) => {
        tab.classList.toggle("active", tab === button);
      });
      renderItems();
    });
  });

  document.getElementById("close-button").addEventListener("click", () => post("close"));
  document.getElementById("cancel-button").addEventListener("click", () => post("close"));

  document.getElementById("reset-button").addEventListener("click", async () => {
    const result = await post("reset");
    if (result?.ok) {
      state.appearance = result.appearance;
      state.limits = result.limits || state.limits;
      renderItems();
    }
  });

  document.getElementById("save-button").addEventListener("click", async () => {
    if (state.busy) {
      return;
    }

    openConfirmModal();
  });

  modalCancel.addEventListener("click", () => {
    if (!state.busy) {
      closeConfirmModal();
    }
  });

  modalConfirm.addEventListener("click", async () => {
    if (state.busy) {
      return;
    }

    clearModalError();
    setBusy(true);
    const result = await post("save", { appearance: state.appearance });
    setBusy(false);

    if (!result?.ok) {
      showModalError(result?.error || "save_failed");
      return;
    }

    closeConfirmModal();
  });

  document.getElementById("rotate-left").addEventListener("click", () => {
    post("rotateLeft");
  });

  document.getElementById("rotate-right").addEventListener("click", () => {
    post("rotateRight");
  });

  document.getElementById("zoom-in").addEventListener("click", () => {
    post("zoomIn");
  });

  document.getElementById("zoom-out").addEventListener("click", () => {
    post("zoomOut");
  });

  document.getElementById("reset-camera").addEventListener("click", () => {
    state.cameraMode = "full";
    renderCameraModes();
    post("resetCamera");
  });

  window.addEventListener("message", (event) => {
    const data = event.data || {};
    if (data.action === "open") {
      open(data.payload || {});
    } else if (data.action === "close") {
      close();
    } else if (data.action === "busy") {
      setBusy(data.busy);
    } else if (data.action === "update") {
      const payload = data.payload || {};
      if (payload.appearance) state.appearance = payload.appearance;
      if (payload.limits) state.limits = payload.limits;
      renderItems();
    }
  });

  window.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && state.open) {
      post("close");
    }
  });
})();
