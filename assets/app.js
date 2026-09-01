"use strict";

// RayDesk frontend. Talks to the raylang backend over a tiny JSON API served
// from the same 127.0.0.1 origin. No framework — styles are Tailwind utilities
// (the class strings here are literal so Tailwind's purge picks them up).

const listEl = document.getElementById("list");
const emptyEl = document.getElementById("empty");
const formEl = document.getElementById("new-task");
const titleEl = document.getElementById("title");
const statTotal = document.getElementById("stat-total");
const statDone = document.getElementById("stat-done");
const clearBtn = document.getElementById("clear-done");

const ITEM_CLASS =
    "flex items-center gap-3 rounded-xl border border-slate-200 bg-white px-3.5 py-3 shadow-sm dark:border-neutral-800 dark:bg-neutral-900";
const CHECKBOX_CLASS = "h-5 w-5 shrink-0 cursor-pointer rounded accent-blue-600";
const TEXT_CLASS = "flex-1 text-sm break-words";
const TEXT_DONE_CLASS = "flex-1 text-sm break-words line-through text-slate-400 dark:text-neutral-500";
const REMOVE_CLASS =
    "shrink-0 rounded-md px-1.5 py-0.5 text-lg leading-none text-slate-400 transition-colors hover:text-red-500";

async function api(path, method = "GET", body = null) {
    const opts = { method };
    if (body !== null) {
        opts.headers = { "Content-Type": "application/json" };
        opts.body = JSON.stringify(body);
    }
    const res = await fetch(path, opts);
    if (!res.ok) throw new Error(`${method} ${path} -> ${res.status}`);
    return res.json();
}

function render(tasks) {
    listEl.textContent = "";
    tasks.sort((a, b) => a.created_ms - b.created_ms);

    for (const t of tasks) {
        const li = document.createElement("li");
        li.className = ITEM_CLASS;

        const cb = document.createElement("input");
        cb.type = "checkbox";
        cb.className = CHECKBOX_CLASS;
        cb.checked = t.done;
        cb.addEventListener("change", () => toggle(t.id));

        const text = document.createElement("span");
        text.className = t.done ? TEXT_DONE_CLASS : TEXT_CLASS;
        text.textContent = t.title;

        const rm = document.createElement("button");
        rm.className = REMOVE_CLASS;
        rm.type = "button";
        rm.textContent = "×";
        rm.title = "Eliminar";
        rm.addEventListener("click", () => remove(t.id));

        li.append(cb, text, rm);
        listEl.appendChild(li);
    }

    const done = tasks.filter((t) => t.done).length;
    statTotal.textContent = `${tasks.length} ${tasks.length === 1 ? "tarea" : "tareas"}`;
    statDone.textContent = `${done} ${done === 1 ? "completada" : "completadas"}`;
    emptyEl.hidden = tasks.length !== 0;
}

async function refresh() {
    render(await api("/api/list", "POST", {}));
}

async function add(title) {
    render(await api("/api/add", "POST", { title }));
}

async function toggle(id) {
    render(await api("/api/toggle", "POST", { id }));
}

async function remove(id) {
    render(await api("/api/delete", "POST", { id }));
}

formEl.addEventListener("submit", (e) => {
    e.preventDefault();
    const title = titleEl.value.trim();
    if (!title) return;
    titleEl.value = "";
    add(title).catch(reportError);
});

clearBtn.addEventListener("click", () => {
    api("/api/clear-done", "POST", {}).then(render).catch(reportError);
});

function reportError(err) {
    console.error(err);
}

// About modal — opened from the native "Acerca de RayDesk" menu via ui.eval_js.
const aboutOverlay = document.getElementById("about-overlay");
const aboutClose = document.getElementById("about-close");

window.rayShowAbout = function () {
    aboutOverlay.classList.replace("hidden", "flex");
};

function hideAbout() {
    aboutOverlay.classList.replace("flex", "hidden");
}

aboutClose.addEventListener("click", hideAbout);
aboutOverlay.addEventListener("click", (e) => {
    if (e.target === aboutOverlay) hideAbout();
});
document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") hideAbout();
});

refresh().catch(reportError);
