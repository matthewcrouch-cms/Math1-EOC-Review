// Shared helpers for the student site, review hub and teacher dashboard.
(function () {
  const C = window.EOC_CONFIG;
  const E = (window.EOC = {});

  E.esc = s => String(s ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  E.fmt = n => (Math.round(Number(n) * 100) / 100).toString();
  E.r1 = n => Math.round(Number(n) * 10) / 10;
  const TZ = "America/New_York";
  E.fmtDate = iso => iso ? new Date(iso).toLocaleDateString("en-US", { weekday: "short", month: "numeric", day: "numeric", timeZone: TZ }) : "";
  E.fmtTime = iso => iso ? new Date(iso).toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit", timeZone: TZ }) : "";
  E.fmtDT = iso => iso ? new Date(iso).toLocaleString("en-US", { weekday: "short", month: "numeric", day: "numeric", hour: "numeric", minute: "2-digit", timeZone: TZ }) : "";
  E.store = {
    _m: {},
    get(k) { try { return localStorage.getItem(k); } catch (e) { return this._m[k] || null; } },
    set(k, v) { try { localStorage.setItem(k, v); } catch (e) { this._m[k] = v; } },
    del(k) { try { localStorage.removeItem(k); } catch (e) { delete this._m[k]; } },
  };

  E.rpc = async function (fn, args = {}) {
    let r;
    try {
      r = await fetch(`${C.SUPABASE_URL}/rest/v1/rpc/${fn}`, {
        method: "POST", headers: { apikey: C.SUPABASE_KEY, "Content-Type": "application/json" }, body: JSON.stringify(args) });
    } catch (e) { throw new Error("Can't reach the server. Check your internet connection."); }
    const data = await r.json().catch(() => null);
    const msg = (data && (data.message || data.error)) || (!r.ok ? "Something went wrong (" + r.status + ")." : null);
    if (!r.ok || (data && data.error)) { const err = new Error(msg); err.expired = /SESSION_EXPIRED/.test(msg || ""); throw err; }
    return data;
  };

  // ---------------- math input parser ----------------
  // Supports + − * / ^, parentheses, implicit multiplication (3x, 2(x+1), (x+1)(x−1)), √ / sqrt(), π / pi.
  function tokenize(s) {
    s = String(s).replace(/[−–—]/g, "-").replace(/[×·∙]/g, "*").replace(/÷/g, "/").replace(/π/g, "pi").replace(/²/g, "^2").replace(/³/g, "^3")
      .replace(/\s+/g, "");
    const t = []; let i = 0;
    while (i < s.length) {
      const c = s[i];
      let m;
      if ((m = /^(\d+\.?\d*|\.\d+)/.exec(s.slice(i)))) { t.push({ k: "n", v: parseFloat(m[1]) }); i += m[1].length; continue; }
      if (s.startsWith("sqrt", i)) { t.push({ k: "f", v: "sqrt" }); i += 4; continue; }
      if (s.startsWith("pi", i)) { t.push({ k: "n", v: Math.PI }); i += 2; continue; }
      if (c === "√") { t.push({ k: "f", v: "sqrt" }); i++; continue; }
      if (/[a-zA-Z]/.test(c)) { t.push({ k: "v", v: c }); i++; continue; }
      if ("+-*/^()".includes(c)) { t.push({ k: c }); i++; continue; }
      if (c === "[" || c === "{") { t.push({ k: "(" }); i++; continue; }
      if (c === "]" || c === "}") { t.push({ k: ")" }); i++; continue; }
      throw new Error("bad char " + c);
    }
    return t;
  }
  E.compile = function (src, vars) {
    const t = tokenize(src); let p = 0;
    const peek = () => t[p], eat = k => { if (!t[p] || t[p].k !== k) throw new Error("expected " + k); return t[p++]; };
    const startsAtom = x => x && (x.k === "n" || x.k === "v" || x.k === "f" || x.k === "(");
    function expr() { let a = term(); while (peek() && (peek().k === "+" || peek().k === "-")) { const o = t[p++].k, b = term(), A = a; a = o === "+" ? e => A(e) + b(e) : e => A(e) - b(e); } return a; }
    function term() {
      let a = unary();
      for (;;) {
        const x = peek();
        if (x && (x.k === "*" || x.k === "/")) { p++; const b = unary(), A = a; a = x.k === "*" ? e => A(e) * b(e) : e => A(e) / b(e); }
        else if (startsAtom(x)) { const b = power(), A = a; a = e => A(e) * b(e); }
        else return a;
      }
    }
    function unary() { if (peek() && peek().k === "-") { p++; const a = unary(); return e => -a(e); } if (peek() && peek().k === "+") { p++; return unary(); } return power(); }
    function power() { const a = atom(); if (peek() && peek().k === "^") { p++; const b = unary(); return e => Math.pow(a(e), b(e)); } return a; }
    function atom() {
      const x = t[p++];
      if (!x) throw new Error("end");
      if (x.k === "n") return () => x.v;
      if (x.k === "v") { if (!vars.includes(x.v)) throw new Error("var " + x.v); return e => e[x.v]; }
      if (x.k === "f") { const a = x2(); return e => Math.sqrt(a(e)); }
      if (x.k === "(") { const a = expr(); eat(")"); return a; }
      throw new Error("unexpected " + x.k);
    }
    function x2() { return peek() && peek().k === "(" ? atom() : power(); }
    const f = expr();
    if (p !== t.length) throw new Error("extra");
    return f;
  };
  // A number the student typed: 61.59, $1,575, -30/13, 6√10, 4/3 …
  E.toNumber = function (raw) {
    let s = String(raw ?? "").trim().replace(/[$,]/g, "").replace(/\s*(%|[a-zA-Z]{2,}.*)$/, m => /^(sqrt|pi)/.test(m.trim()) ? m : "");
    s = s.replace(/^[a-zA-Z]\s*(\(\s*\w+\s*\))?\s*[=≈]/, "");
    if (!s) return null;
    try { const v = E.compile(s, [])({}); return isFinite(v) ? v : null; } catch (e) { return null; }
  };
  E.evalExpr = function (raw, vars, pts) {
    let s = String(raw ?? "").trim();
    s = s.replace(/^[a-zA-Z]\s*(\(\s*\w+\s*\))?\s*=/, ""); // allow typing "y = ..."
    if (!s) return null;
    try {
      const f = E.compile(s, vars);
      const v = pts.map(pt => f(Object.fromEntries(vars.map((k, i) => [k, pt[i]]))));
      return v.every(x => isFinite(x)) ? v : null;
    } catch (e) { return null; }
  };
  E.pretty = s => E.esc(s).replace(/\^\s*(\(([^()]*)\)|-?[0-9.]+|[a-zA-Z])/g, (m, g, inner) => `<sup>${inner ?? g}</sup>`)
    .replace(/sqrt/g, "√").replace(/\*/g, "·").replace(/-/g, "−");

  // ---------------- question inputs ----------------
  // ctx: { pending: {}, pick: {}, locked: bool, fb: feedback }
  E.valOf = function (p, pending, path) {
    const src = pending[p.id] !== undefined ? pending[p.id] : p.last_answer;
    if (src == null) return "";
    if (path == null) return src;
    let v = src; for (const k of path) v = v == null ? undefined : v[k];
    return v ?? "";
  };

  E.renderInput = function (p, pending, pick, locked, keyMode) {
    const dis = locked ? "disabled" : "";
    const esc = E.esc;
    const sp = p.spec || {};
    if (p.kind === "num") {
      const v = E.valOf(p, pending, ["raw"]);
      return `<div class="inrow">${sp.prefix ? `<span>${sp.prefix}</span>` : ""}
        <input class="num" data-f="num" autocomplete="off" placeholder="${esc(sp.placeholder || "")}" value="${esc(v)}" ${dis}>
        ${sp.suffix ? `<span>${sp.suffix}</span>` : ""}</div>${locked ? "" : `<div class="tip">Fractions like 4/3 and roots like 6√10 (or 6sqrt(10)) are OK.</div>`}`;
    }
    if (p.kind === "nums") {
      const raw = E.valOf(p, pending, ["raw"]) || [];
      return Array.from({ length: sp.n }, (_, i) => `<div class="inrow"><span class="m">${(sp.labels && sp.labels[i]) || esc(sp.prefix || "")}</span>
        <input class="num" data-f="nums" data-i="${i}" autocomplete="off" value="${esc(raw[i] ?? "")}" ${dis}></div>`).join("") +
        (locked ? "" : `<div class="tip">Enter one solution in each box, in any order.</div>`);
    }
    if (p.kind === "expr") {
      const v = E.valOf(p, pending, ["raw"]);
      return `<div class="inrow">${sp.prefix ? `<span>${sp.prefix}</span>` : ""}
        <input class="num wide" data-f="expr" autocomplete="off" autocapitalize="off" spellcheck="false" placeholder="${esc(sp.placeholder || "type your answer")}" value="${esc(v)}" ${dis}></div>
        <div class="preview" data-preview>${v ? "Looks like: " + E.pretty(v) : ""}</div>
        ${locked ? "" : `<div class="tip">Type <b>^</b> for exponents (x^2 means x²). ${sp.tip || ""}</div>`}`;
    }
    if (p.kind === "coord") {
      const cur = E.valOf(p, pending) || [];
      return Array.from({ length: sp.n }, (_, i) => `<div class="coord">(
        <input class="num" data-f="cx" data-i="${i}" autocomplete="off" placeholder="x" value="${esc((cur[i] || [])[0] ?? "")}" ${dis}> ,
        <input class="num" data-f="cy" data-i="${i}" autocomplete="off" placeholder="y" value="${esc((cur[i] || [])[1] ?? "")}" ${dis}> )</div>`).join("");
    }
    if (p.kind === "mc" || p.kind === "multi") {
      const multi = p.kind === "multi";
      const cur = E.valOf(p, pending);
      const sel = multi ? (Array.isArray(cur) ? cur : []) : [cur];
      const short = sp.choices.every(c => c.html.replace(/<[^>]+>/g, "").length < 26);
      const lay = sp.layout === "pics" ? "pics" : short ? "wrap" : "";
      const keys = keyMode || [];
      return `${multi ? `<div class="sub" style="margin:0 0 8px;font-size:.9rem">${sp.count ? `Select <b>${sp.count}</b> answers.` : "Select all that apply."}</div>` : ""}
        <div class="choices ${lay}">${sp.choices.map(c => `
        <button class="choice ${multi ? "sq" : ""} ${sel.includes(c.id) ? "sel" : ""} ${keys.includes(c.id) ? "key" : ""}" data-f="choice" data-id="${c.id}" ${dis}>
          <span class="box2">${sel.includes(c.id) ? "✓" : ""}</span><span class="let">${c.id.toUpperCase()}.</span><span>${c.html}</span></button>`).join("")}</div>`;
    }
    if (p.kind === "fill") {
      const cur = E.valOf(p, pending) || {};
      const tById = Object.fromEntries(sp.tiles.map(t => [t.id, t]));
      const used = new Set(Object.values(cur));
      const line = sp.template.replace(/\[\[(\w+)\]\]/g, (m, slot) => {
        const t = cur[slot] ? tById[cur[slot]] : null;
        return `<button class="slot ${t ? "full" : ""} ${pick && !locked ? "ready" : ""}" data-f="slot" data-id="${slot}" ${dis}>${t ? t.html : `<span class="empty">${pick ? "Tap to place" : "drop here"}</span>`}</button>`;
      });
      const bank = sp.tiles.filter(t => sp.reuse || !used.has(t.id));
      return `<div class="fillline">${line}</div>${locked ? "" : `<div class="tilebank"><div class="tip" style="margin:0 0 6px">Drag a tile into a box, or tap a tile and then tap a box. Tap a filled box to empty it.${sp.reuse ? " Tiles can be used more than once." : ""}</div>
        <div class="tiles">${bank.map(t => `<div class="tile ${pick === t.id ? "picked" : ""}" draggable="true" data-f="tile" data-id="${t.id}" role="button" tabindex="0">${t.html}</div>`).join("")}</div></div>`}`;
    }
    return "";
  };

  E.collect = function (p, el, pending) {
    const sp = p.spec || {};
    if (p.kind === "num") { const raw = el.querySelector("[data-f=num]").value; return { raw, v: E.toNumber(raw) }; }
    if (p.kind === "nums") { const raw = [...el.querySelectorAll("[data-f=nums]")].map(i => i.value); return { raw, v: raw.map(E.toNumber) }; }
    if (p.kind === "expr") { const raw = el.querySelector("[data-f=expr]").value; return { raw, v: E.evalExpr(raw, sp.vars, sp.pts) }; }
    if (p.kind === "coord") return Array.from({ length: sp.n }, (_, i) =>
      [E.toNumber(el.querySelector(`[data-f=cx][data-i="${i}"]`).value), E.toNumber(el.querySelector(`[data-f=cy][data-i="${i}"]`).value)]);
    const v = pending[p.id] !== undefined ? pending[p.id] : p.last_answer;
    return v ?? (p.kind === "multi" ? [] : p.kind === "fill" ? {} : "");
  };
  // What gets typed but not submitted yet (keeps raw text for coord boxes)
  E.collectDraft = function (p, el, pending) {
    if (p.kind === "coord") return Array.from({ length: p.spec.n }, (_, i) =>
      [el.querySelector(`[data-f=cx][data-i="${i}"]`).value, el.querySelector(`[data-f=cy][data-i="${i}"]`).value]);
    return E.collect(p, el, pending);
  };

  // ---------------- Desmos pop-up ----------------
  E.setupCalc = function () {
    const calc = document.getElementById("calc");
    if (!calc) return { open() {}, hide() {} };
    const api = {
      open() {
        if (!calc.querySelector("iframe")) {
          const f = document.createElement("iframe");
          f.src = "https://www.desmos.com/calculator"; f.title = "Desmos graphing calculator"; f.allow = "clipboard-write";
          calc.insertBefore(f, calc.querySelector(".grip"));
        }
        calc.classList.add("open");
      },
      hide() { calc.classList.remove("open"); },
      reset() { calc.classList.remove("open"); const f = calc.querySelector("iframe"); if (f) f.remove(); },
    };
    document.getElementById("calcclose").onclick = api.hide;
    const bar = document.getElementById("calcbar");
    let sx, sy, ox, oy;
    bar.addEventListener("pointerdown", e => {
      if (e.target.closest("a,button")) return;
      const r = calc.getBoundingClientRect();
      sx = e.clientX; sy = e.clientY; ox = r.left; oy = r.top;
      Object.assign(calc.style, { left: ox + "px", top: oy + "px", right: "auto", bottom: "auto" });
      calc.classList.add("dragging"); bar.setPointerCapture(e.pointerId);
    });
    bar.addEventListener("pointermove", e => {
      if (!calc.classList.contains("dragging")) return;
      calc.style.left = Math.min(Math.max(0, ox + e.clientX - sx), window.innerWidth - 80) + "px";
      calc.style.top = Math.min(Math.max(0, oy + e.clientY - sy), window.innerHeight - 40) + "px";
    });
    const stop = () => calc.classList.remove("dragging");
    bar.addEventListener("pointerup", stop); bar.addEventListener("pointercancel", stop);
    return api;
  };

  // ---------------- Review drawer ----------------
  E.topicName = id => (window.EOC_REVIEW && window.EOC_REVIEW.topics[id] ? window.EOC_REVIEW.topics[id].name : id);
  E.renderTopic = function (id) {
    const t = window.EOC_REVIEW.topics[id];
    if (!t) return `<p>Topic not found.</p>`;
    return `<div class="rv">${t.body}</div>`;
  };
  E.setupDrawer = function () {
    let d = document.getElementById("drawer");
    if (!d) {
      d = document.createElement("aside"); d.id = "drawer"; d.setAttribute("aria-label", "Review");
      d.innerHTML = `<div class="dh"><b id="dtitle">Review</b><button id="dclose">Close ×</button></div><div class="db" id="dbody"></div>`;
      document.body.appendChild(d);
      d.querySelector("#dclose").onclick = () => d.classList.remove("open");
      document.addEventListener("keydown", e => { if (e.key === "Escape") d.classList.remove("open"); });
    }
    return {
      open(id) {
        const t = window.EOC_REVIEW.topics[id];
        d.querySelector("#dtitle").textContent = "📘 " + (t ? t.name : "Review");
        d.querySelector("#dbody").innerHTML = E.renderTopic(id);
        d.querySelector("#dbody").scrollTop = 0;
        d.classList.add("open");
      },
      close() { d.classList.remove("open"); },
    };
  };
})();
