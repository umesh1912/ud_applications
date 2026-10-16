"use strict";
(() => {
  // data_filler/src/data.ts
  function parseDelimited(text) {
    var _a;
    const firstLine = (_a = text.split(/\r?\n/, 1)[0]) != null ? _a : "";
    const delim = firstLine.includes("	") ? "	" : firstLine.split(";").length > firstLine.split(",").length ? ";" : ",";
    const records = [];
    let field = "";
    let record = [];
    let quoted = false;
    for (let i = 0; i < text.length; i++) {
      const ch = text[i];
      if (quoted) {
        if (ch === '"' && text[i + 1] === '"') {
          field += '"';
          i++;
        } else if (ch === '"') quoted = false;
        else field += ch;
      } else if (ch === '"' && field === "") quoted = true;
      else if (ch === delim) {
        record.push(field);
        field = "";
      } else if (ch === "\n" || ch === "\r") {
        if (ch === "\r" && text[i + 1] === "\n") i++;
        record.push(field);
        records.push(record);
        record = [];
        field = "";
      } else field += ch;
    }
    if (field !== "" || record.length) {
      record.push(field);
      records.push(record);
    }
    const nonEmpty = records.filter((r) => r.some((c) => c.trim() !== ""));
    if (!nonEmpty.length) return { columns: [], rows: [] };
    const columns = uniqueHeaders(nonEmpty[0].map((h) => h.trim()));
    const rows = nonEmpty.slice(1).map((r) => {
      const row = {};
      columns.forEach((c, i) => {
        var _a2;
        return row[c] = ((_a2 = r[i]) != null ? _a2 : "").trim();
      });
      return row;
    });
    return { columns, rows };
  }
  function uniqueHeaders(headers) {
    const seen = /* @__PURE__ */ new Map();
    return headers.map((h, i) => {
      var _a;
      const base = h || `column ${i + 1}`;
      const n = ((_a = seen.get(base)) != null ? _a : 0) + 1;
      seen.set(base, n);
      return n === 1 ? base : `${base} ${n}`;
    });
  }
  function parseJson(text) {
    let data = JSON.parse(text);
    if (!Array.isArray(data) && data && typeof data === "object") {
      const arr = Object.values(data).find(Array.isArray);
      data = arr != null ? arr : [data];
    }
    if (!Array.isArray(data)) throw new Error("JSON must be a list of objects.");
    const rows = data.map((d) => d && typeof d === "object" ? d : { value: d });
    const columns = [];
    const addKeys = (obj, prefix) => {
      for (const [k, v] of Object.entries(obj)) {
        const key = prefix + k;
        if (v && typeof v === "object" && !Array.isArray(v)) addKeys(v, `${key}.`);
        else if (!columns.includes(key)) columns.push(key);
      }
    };
    rows.slice(0, 50).forEach((r) => addKeys(r, ""));
    return { columns, rows };
  }
  function parseTable(text) {
    const t = text.trim();
    if (!t) return { columns: [], rows: [] };
    if (t.startsWith("[") || t.startsWith("{")) return parseJson(t);
    return parseDelimited(t);
  }
  var normKey = (s) => s.toLowerCase().replace(/[\s_\-]/g, "");
  function lookup(row, field) {
    const want = normKey(field);
    for (const [k, v] of Object.entries(row)) if (normKey(k) === want) return v;
    if (field.includes(".")) {
      let cur = row;
      for (const part of field.split(".")) {
        if (!cur || typeof cur !== "object") return void 0;
        const entry = Object.entries(cur).find(([k]) => normKey(k) === normKey(part));
        cur = entry ? entry[1] : void 0;
      }
      return cur;
    }
    return void 0;
  }
  function isTruthy(v) {
    if (v === null || v === void 0 || v === false) return false;
    const s = String(v).trim().toLowerCase();
    return !["", "0", "false", "no", "n", "off", "hide", "hidden", "null"].includes(s);
  }
  var isImageUrl = (v) => typeof v === "string" && /^https?:\/\/\S+$/i.test(v.trim());
  var isHexColor = (v) => typeof v === "string" && /^#([0-9a-f]{3}|[0-9a-f]{6})$/i.test(v.trim());
  function parseLayerName(name) {
    const n = name.trim();
    if (!n.startsWith("#") || n.length < 2) return null;
    let field = n.slice(1).split("|")[0].trim();
    const toggle = field.endsWith("?");
    if (toggle) field = field.slice(0, -1).trim();
    return field ? { field, toggle } : null;
  }
  var FIRST = ["Aarav", "Diya", "Kabir", "Ananya", "Rohan", "Isha", "Vivaan", "Meera", "Arjun", "Sara", "Liam", "Emma", "Noah", "Olivia", "Mateo", "Yuki", "Amara", "Lucas", "Zara", "Omar"];
  var LAST = ["Shah", "Patel", "Mehta", "Iyer", "Kapoor", "Desai", "Rao", "Singh", "Joshi", "Nair", "Smith", "Garcia", "Kim", "M\xFCller", "Rossi", "Tanaka", "Okafor", "Silva", "Haddad", "Novak"];
  var CITY = ["Ahmedabad", "Mumbai", "Bengaluru", "Pune", "Delhi", "Surat", "Jaipur", "London", "Berlin", "Toronto", "Dubai", "Singapore"];
  var COMPANY = ["Northwind", "Bluepeak", "Sunrise Labs", "Kite & Co", "Indigo Works", "Saffron Tech", "Lumen", "Orbit Studio"];
  var STATUS = ["Active", "Pending", "Paid", "Overdue", "Shipped", "Draft"];
  var ROLE = ["Designer", "Engineer", "Product Manager", "Founder", "Marketing Lead", "Data Analyst"];
  var WORDS = "quick simple bright modern secure fast friendly smart clean fresh easy local daily".split(" ");
  var PRODUCT = ["Wireless Earbuds", "Cotton Kurta", "Smart Watch", "Leather Wallet", "Desk Lamp", "Running Shoes", "Masala Chai Set", "Backpack"];
  function rng(seed) {
    let s = seed >>> 0 || 1;
    return () => {
      s ^= s << 13;
      s ^= s >>> 17;
      s ^= s << 5;
      return (s >>> 0) / 4294967296;
    };
  }
  function sampleRows(count, seed = 7) {
    var _a;
    const r = rng(seed);
    const pick = (a) => a[Math.floor(r() * a.length)];
    const rows = [];
    for (let i = 0; i < count; i++) {
      const first = pick(FIRST);
      const last = pick(LAST);
      const day = new Date(Date.UTC(2026, Math.floor(r() * 12), 1 + Math.floor(r() * 28)));
      rows.push({
        name: `${first} ${last}`,
        first,
        last,
        email: `${first}.${last}`.toLowerCase().normalize("NFD").replace(/[^a-z.]/g, "") + "@example.com",
        phone: `+91 9${Math.floor(r() * 1e9).toString().padStart(9, "0").replace(/(\d{4})(\d{5})/, "$1 $2")}`,
        city: pick(CITY),
        company: pick(COMPANY),
        role: pick(ROLE),
        product: pick(PRODUCT),
        price: `\u20B9${(Math.round(r() * 4900) + 99).toLocaleString("en-IN")}`,
        amount: (Math.round(r() * 99900) / 100 + 1).toFixed(2),
        rating: (3 + r() * 2).toFixed(1),
        date: day.toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric", timeZone: "UTC" }),
        status: pick(STATUS),
        title: `${pick(WORDS)[0].toUpperCase()}${pick(WORDS).slice(1)} ${pick(WORDS)} ${pick(["update", "launch", "guide", "offer", "release"])}`,
        verified: r() > 0.4 ? "yes" : "no",
        avatar: `https://i.pravatar.cc/240?img=${1 + Math.floor(r() * 70)}`
      });
    }
    return { columns: Object.keys((_a = rows[0]) != null ? _a : {}), rows };
  }
  function rowOrder(total, needed, start, shuffle, seed = Date.now()) {
    if (!total) return [];
    const idx = Array.from({ length: total }, (_, i) => i);
    if (shuffle) {
      const r = rng(seed);
      for (let i = idx.length - 1; i > 0; i--) {
        const j = Math.floor(r() * (i + 1));
        [idx[i], idx[j]] = [idx[j], idx[i]];
      }
    }
    const s = (start % total + total) % total;
    return Array.from({ length: needed }, (_, i) => idx[(s + i) % total]);
  }

  // shared/color.ts
  function fromHex(hex) {
    let h = hex.trim().replace(/^#/, "");
    if (h.length === 3 || h.length === 4) h = h.split("").map((ch) => ch + ch).join("");
    if (!/^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(h)) return null;
    const n = (i) => parseInt(h.slice(i, i + 2), 16) / 255;
    return { r: n(0), g: n(2), b: n(4), a: h.length === 8 ? n(6) : 1 };
  }

  // data_filler/src/code.ts
  var MAX_REPEAT = 500;
  var STORAGE_KEY = "last-data";
  var table = { columns: [], rows: [] };
  figma.showUI(__html__, { width: 440, height: 640, themeColors: true });
  var post = (msg) => figma.ui.postMessage(msg);
  function fieldNodes(root) {
    const out = [];
    if (parseLayerName(root.name)) out.push(root);
    if ("findAll" in root) out.push(...root.findAll((n) => parseLayerName(n.name) !== null));
    return out;
  }
  function instancesIn(root) {
    const out = root.type === "INSTANCE" ? [root] : [];
    if ("findAll" in root) out.push(...root.findAll((n) => n.type === "INSTANCE"));
    return out;
  }
  var propBase = (key) => key.split("#")[0].trim();
  function selectionFields() {
    const fields = /* @__PURE__ */ new Set();
    for (const root of figma.currentPage.selection) {
      for (const n of fieldNodes(root)) fields.add(parseLayerName(n.name).field);
      for (const inst of instancesIn(root)) {
        try {
          for (const key of Object.keys(inst.componentProperties)) {
            if (inst.componentProperties[key].type !== "INSTANCE_SWAP") fields.add(propBase(key));
          }
        } catch (e) {
        }
      }
    }
    return [...fields];
  }
  function selectionInfo() {
    return { type: "selection", count: figma.currentPage.selection.length, fields: selectionFields() };
  }
  function orderedSelection() {
    const sel = [...figma.currentPage.selection];
    const parent = sel[0] && sel[0].parent;
    if (parent && sel.every((n) => n.parent === parent) && "children" in parent) {
      const kids = parent.children;
      if ("layoutMode" in parent && parent.layoutMode !== "NONE") return sel.sort((a, b) => kids.indexOf(a) - kids.indexOf(b));
    }
    return sel.sort((a, b) => Math.abs(a.y - b.y) > 4 ? a.y - b.y : a.x - b.x);
  }
  var imageCache = /* @__PURE__ */ new Map();
  function image(url) {
    let p = imageCache.get(url);
    if (!p) {
      p = figma.createImageAsync(url);
      imageCache.set(url, p);
      p.catch(() => imageCache.delete(url));
    }
    return p;
  }
  async function setText(node, value, s) {
    if (node.hasMissingFont) {
      s.errors.push(`"${node.name}": font is missing in this file`);
      return false;
    }
    const len = node.characters.length;
    const fonts = len ? node.getRangeAllFontNames(0, len) : [node.fontName];
    await Promise.all(fonts.map((f) => figma.loadFontAsync(f)));
    node.characters = value;
    return true;
  }
  async function fillNode(node, toggle, value, s) {
    if (toggle) {
      node.visible = isTruthy(value);
      return true;
    }
    if (value && typeof value === "object" && !Array.isArray(value)) return false;
    const text = value === null || value === void 0 ? "" : Array.isArray(value) ? value.join(", ") : String(value);
    if (node.type === "TEXT") return setText(node, text, s);
    if (isImageUrl(text) && "fills" in node) {
      try {
        const img = await image(text.trim());
        node.fills = [{ type: "IMAGE", scaleMode: "FILL", imageHash: img.hash }];
        return true;
      } catch (e) {
        s.errors.push(`Image for "${node.name}" could not be loaded (${text.slice(0, 60)})`);
        return false;
      }
    }
    if (isHexColor(text) && "fills" in node) {
      const c = fromHex(text);
      node.fills = [{ type: "SOLID", color: { r: c.r, g: c.g, b: c.b } }];
      return true;
    }
    if ("findOne" in node || "findAll" in node) {
      const t = node.findAll((n) => n.type === "TEXT")[0];
      if (t) return setText(t, text, s);
    }
    return false;
  }
  function fillProps(inst, row, s) {
    let props;
    try {
      props = inst.componentProperties;
    } catch (e) {
      return;
    }
    for (const [key, prop] of Object.entries(props)) {
      if (prop.type === "INSTANCE_SWAP") continue;
      const value = lookup(row, propBase(key));
      if (value === void 0) continue;
      const next = prop.type === "BOOLEAN" ? isTruthy(value) : String(value);
      try {
        inst.setProperties({ [key]: next });
        s.fields++;
      } catch (e) {
        s.errors.push(`"${inst.name}": ${propBase(key)} has no option "${next}"`);
      }
    }
  }
  async function fillItem(root, row, s) {
    for (const inst of instancesIn(root)) fillProps(inst, row, s);
    for (const node of fieldNodes(root)) {
      const parsed = parseLayerName(node.name);
      const value = lookup(row, parsed.field);
      if (value === void 0) {
        if (!s.missing.includes(parsed.field)) s.missing.push(parsed.field);
        continue;
      }
      try {
        if (await fillNode(node, parsed.toggle, value, s)) s.fields++;
      } catch (e) {
        s.errors.push(`"${node.name}": ${e instanceof Error ? e.message : String(e)}`);
      }
    }
  }
  function repeatItem(item, total, gap) {
    const items = [item];
    const parent = item.parent;
    const auto = !!parent && "layoutMode" in parent && parent.layoutMode !== "NONE";
    for (let i = 1; i < total; i++) {
      const copy = item.clone();
      if (auto) {
        const p = parent;
        p.insertChild(p.children.indexOf(items[i - 1]) + 1, copy);
      } else {
        copy.x = item.x;
        copy.y = item.y + i * (item.height + gap);
      }
      items.push(copy);
    }
    return items;
  }
  async function apply(o) {
    if (!table.rows.length) throw new Error("Add some data first.");
    let items = orderedSelection();
    if (!items.length) throw new Error("Select the layers to fill.");
    const s = { items: 0, fields: 0, created: 0, missing: [], errors: [] };
    if (o.repeat && items.length === 1) {
      const count = Math.min(table.rows.length - Math.max(0, o.start), MAX_REPEAT);
      items = repeatItem(items[0], Math.max(1, count), o.gap);
      s.created = items.length - 1;
    }
    const order = rowOrder(table.rows.length, items.length, o.start, o.shuffle);
    for (let i = 0; i < items.length; i++) {
      await fillItem(items[i], table.rows[order[i]], s);
      s.items++;
    }
    if (s.created) figma.currentPage.selection = items;
    post({ type: "applied", summary: s });
    figma.notify(`Filled ${s.items} item${s.items === 1 ? "" : "s"} \xB7 ${s.fields} fields${s.errors.length ? ` \xB7 ${s.errors.length} problems` : ""}`);
  }
  function sendTable(source) {
    const fields = selectionFields();
    post({
      type: "table",
      source,
      columns: table.columns,
      preview: table.rows.slice(0, 6),
      total: table.rows.length,
      matched: fields.filter((f) => table.columns.some((c) => normKey(c) === normKey(f) || c.toLowerCase().startsWith(f.toLowerCase() + "."))),
      fields
    });
  }
  figma.ui.onmessage = async (msg) => {
    try {
      switch (msg.type) {
        case "ready": {
          post(selectionInfo());
          const saved = await figma.clientStorage.getAsync(STORAGE_KEY);
          if (saved) {
            table = parseTable(saved);
            post({ type: "restore", text: saved });
            sendTable("saved");
          }
          break;
        }
        case "data":
          table = parseTable(msg.text);
          await figma.clientStorage.setAsync(STORAGE_KEY, String(msg.text).slice(0, 5e5));
          sendTable(msg.source || "pasted");
          break;
        case "sample": {
          table = sampleRows(Math.max(1, Math.min(200, msg.count || 20)), msg.seed);
          const text = JSON.stringify(table.rows, null, 2);
          await figma.clientStorage.setAsync(STORAGE_KEY, text);
          post({ type: "restore", text });
          sendTable("sample");
          break;
        }
        case "apply":
          await apply(msg.options);
          post(selectionInfo());
          break;
      }
    } catch (e) {
      post({ type: "error", message: e instanceof Error ? e.message : String(e) });
    }
  };
  figma.on("selectionchange", () => {
    post(selectionInfo());
    if (table.columns.length) sendTable("selection");
  });
})();
