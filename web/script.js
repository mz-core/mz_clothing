(() => {
  const resource = typeof GetParentResourceName === "function" ? GetParentResourceName() : "mz_clothing";
  const app = document.getElementById("app");
  const categoriesEl = document.getElementById("categories");
  const outfitsEl = document.getElementById("outfits");
  const statusEl = document.getElementById("status");
  const currency = new Intl.NumberFormat("pt-BR", { style: "currency", currency: "USD", currencyDisplay: "narrowSymbol", maximumFractionDigits: 0 });
  const state = { open: false, busy: false, categories: [], outfits: [], cameraModes: [], selection: null };

  async function post(name, data = {}) {
    const response = await fetch(`https://${resource}/${name}`, {
      method: "POST",
      headers: { "Content-Type": "application/json; charset=UTF-8" },
      body: JSON.stringify(data),
    });
    return response.json();
  }

  function setBusy(value) {
    state.busy = Boolean(value);
    app.classList.toggle("busy", state.busy);
    app.querySelectorAll("button, input").forEach((node) => { node.disabled = state.busy; });
  }

  function status(message, error = false) {
    statusEl.textContent = message || "";
    statusEl.classList.toggle("error", error);
  }

  function money(value) {
    return currency.format(Number(value || 0));
  }

  function categoryLabel(group) {
    return ({ head: "Cabeca", torso: "Torso", arms: "Bracos", legs: "Pernas", shoes: "Calcados", accessories: "Acessorios" })[group] || "Roupa";
  }

  function renderSelection() {
    const selected = state.selection;
    if (!selected) return;
    document.getElementById("selection-group").textContent = categoryLabel(
      state.categories.find((item) => item.slot === selected.slot)?.group,
    );
    document.getElementById("selection-label").textContent = selected.label;
    document.getElementById("selection-tech").textContent = `${selected.label} · Modelo ${selected.drawable} · Textura ${selected.texture}`;
    document.getElementById("model-value").textContent = `${selected.model_index} / ${selected.model_count}`;
    document.getElementById("texture-value").textContent = `${selected.texture + 1} / ${selected.texture_count}`;
    document.getElementById("selection-price").textContent = money(selected.price);
    categoriesEl.querySelectorAll("button").forEach((button) => {
      const active = button.dataset.slot === selected.slot;
      button.classList.toggle("active", active);
      button.setAttribute("aria-current", active ? "true" : "false");
    });
  }

  async function selectVariant(slot, modelDelta = 0, textureDelta = 0) {
    if (state.busy) return;
    setBusy(true);
    const result = await post("selectVariant", { slot, modelDelta, textureDelta });
    setBusy(false);
    if (!result?.ok) {
      status(result?.error || "Variante indisponivel", true);
      return;
    }
    state.selection = result;
    renderSelection();
    status("");
  }

  function renderCategories() {
    categoriesEl.innerHTML = "";
    state.categories.forEach((category) => {
      const button = document.createElement("button");
      button.type = "button";
      button.dataset.slot = category.slot;
      button.innerHTML = `<span>${category.label}</span><small>${category.model_count} modelos</small>`;
      button.addEventListener("click", () => selectVariant(category.slot));
      categoriesEl.appendChild(button);
    });
  }

  async function purchase() {
    if (state.busy || !state.selection) return;
    setBusy(true);
    const result = await post("purchase", { displayPrice: state.selection.price });
    setBusy(false);
    status(result?.ok ? "Compra concluida. A roupa esta na sua bag." : result?.error || "Compra recusada", !result?.ok);
  }

  async function loadOutfits() {
    const result = await post("listOutfits");
    state.outfits = result?.ok ? result.outfits || [] : [];
    outfitsEl.innerHTML = "";
    state.outfits.forEach((outfit) => {
      const row = document.createElement("article");
      row.className = "outfit";
      const name = document.createElement("strong");
      name.textContent = outfit.name;
      const actions = document.createElement("div");
      const apply = document.createElement("button");
      apply.className = "ghost"; apply.type = "button"; apply.textContent = "Vestir";
      apply.addEventListener("click", async () => {
        const response = await post("applyOutfit", { name: outfit.name });
        status(response?.ok ? "Outfit equipado." : response?.error || "Falha ao equipar", !response?.ok);
      });
      const remove = document.createElement("button");
      remove.className = "danger"; remove.type = "button"; remove.textContent = "Excluir";
      let deleteArmed = false;
      remove.addEventListener("click", async () => {
        if (!deleteArmed) {
          deleteArmed = true;
          remove.textContent = "Confirmar exclusao";
          status("Clique novamente para excluir este outfit.");
          return;
        }
        const response = await post("deleteOutfit", { name: outfit.name });
        if (response?.ok) loadOutfits(); else status(response?.error || "Falha ao excluir", true);
      });
      actions.append(apply, remove); row.append(name, actions); outfitsEl.appendChild(row);
    });
    if (!state.outfits.length) outfitsEl.innerHTML = '<p class="empty">Nenhum outfit salvo.</p>';
  }

  function renderCameraModes() {
    const root = document.getElementById("camera-modes");
    root.innerHTML = "";
    state.cameraModes.forEach((mode) => {
      const button = document.createElement("button");
      button.type = "button"; button.className = "ghost"; button.textContent = mode.label;
      button.addEventListener("click", () => post("setCameraMode", { mode: mode.id }));
      root.appendChild(button);
    });
  }

  function open(payload) {
    state.open = true;
    state.categories = payload.categories || [];
    state.cameraModes = payload.cameraModes || [];
    state.selection = payload.selection || null;
    document.getElementById("shop-title").textContent = payload.shop?.label || "Loja de roupas";
    app.setAttribute("aria-hidden", "false");
    document.body.classList.add("is-open");
    renderCategories(); renderCameraModes(); renderSelection(); status("");
  }

  document.querySelectorAll(".tab").forEach((button) => button.addEventListener("click", () => {
    document.querySelectorAll(".tab").forEach((tab) => tab.classList.toggle("active", tab === button));
    document.getElementById("catalog-view").classList.toggle("hidden", button.dataset.tab !== "catalog");
    document.getElementById("outfits-view").classList.toggle("hidden", button.dataset.tab !== "outfits");
    if (button.dataset.tab === "outfits") loadOutfits();
  }));
  document.getElementById("outfit-form").addEventListener("submit", async (event) => {
    event.preventDefault();
    const name = document.getElementById("outfit-name").value.trim();
    const result = await post("saveOutfit", { name });
    status(result?.ok ? "Outfit salvo." : result?.error || "Falha ao salvar", !result?.ok);
    if (result?.ok) { document.getElementById("outfit-name").value = ""; loadOutfits(); }
  });
  document.getElementById("model-prev").addEventListener("click", () => selectVariant(state.selection?.slot, -1, 0));
  document.getElementById("model-next").addEventListener("click", () => selectVariant(state.selection?.slot, 1, 0));
  document.getElementById("texture-prev").addEventListener("click", () => selectVariant(state.selection?.slot, 0, -1));
  document.getElementById("texture-next").addEventListener("click", () => selectVariant(state.selection?.slot, 0, 1));
  document.getElementById("buy").addEventListener("click", purchase);
  document.getElementById("rotate-left").addEventListener("click", () => post("rotateLeft"));
  document.getElementById("rotate-right").addEventListener("click", () => post("rotateRight"));
  document.getElementById("zoom-in").addEventListener("click", () => post("zoomIn"));
  document.getElementById("zoom-out").addEventListener("click", () => post("zoomOut"));
  window.addEventListener("message", ({ data = {} }) => {
    if (data.action === "open") open(data.payload || {});
    if (data.action === "close") {
      state.open = false; state.selection = null;
      document.body.classList.remove("is-open"); app.setAttribute("aria-hidden", "true");
    }
    if (data.action === "busy") setBusy(data.busy);
  });
  window.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && state.open) post("close");
  });
})();
