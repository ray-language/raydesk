# RayDesk

Un gestor de tareas de **escritorio** escrito en [raylang](https://raylang.dev)
(probado con **1.4.0**). Ventana nativa (webview del sistema) + backend HTTP
local sobre el framework `web` + persistencia con `std/kv`. Pensado como banco
de pruebas de las características del lenguaje.

## Arquitectura

```
┌─────────────────────────┐     HTTP (127.0.0.1:PUERTO)      ┌───────────────────────┐
│  Ventana nativa          │  ───────────────────────────▶   │  Backend raylang      │
│  std/ui + webview        │   POST /api/list                 │  web (Express-style)  │
│  (assets/index.html,     │   POST /api/add     {title}      │   sobre net/webserver │
│   app.css, app.js)       │   POST /api/toggle  {id}         │                       │
│                          │   POST /api/delete  {id}         │  handlers stateless   │
│  fetch() ◀───── JSON ────│   POST /api/clear-done           │  GET / , /app.* →     │
└─────────────────────────┘   GET  / , /app.*  (assets)      │  web.static_embedded  │
                                                              └──────────┬────────────┘
                                        std/kv (store, 1 clave/tarea)     ▼
                                               ~/Documents/RayDesk/tasks.kv
```

- **UI**: `std/ui.open()` abre una ventana nativa que carga el servidor local;
  el hilo principal atiende sus eventos y cierra el proceso al cerrar la ventana.
- **Servidor**: se bindea con `net.tcp_listen("127.0.0.1", 0)`, se lee el puerto
  con `net.local_port` (sin carrera) y se sirve con **`web.listen_on(build,
  listener)`** en una fibra (`spawn`); la ventana abre en ese puerto.
- **Assets**: **`web.static_embedded(app, "/", "assets")`** sirve el bundle
  embebido (con ETag/304/Range y bloqueo de `..`); en `ray build --native` se
  hornea en el binario (una `.app` arranca con `cwd=/`).
- **Verbos**: los mounts de estáticos sirven GET/HEAD antes que las rutas, así que
  la API va como **POST** (incluida la lectura `/api/list`).
- **Menús** (`std/ui`): "Acerca de RayDesk" va en el **menú de app** (macOS: el
  primero, en negrita) vía `ui.app_menu`, que además lo retitula a "RayDesk"
  incluso bajo `ray run`. Más menús custom "Archivo" (Nueva tarea ⌘N, Exportar
  tareas… ⌘E, Recargar ⌘R) y "Tarea" (Limpiar completadas ⌘K) con `ui.menu`. El
  click llega como evento `"menu"` con `tag`; las acciones manejan el frontend vía
  `ui.eval_js` (reusan los handlers de la página, así la UI queda sincronizada),
  "Exportar" abre el diálogo nativo `ui.save_file`, y "Acerca de RayDesk" abre un
  modal informativo (versión, creador). Los menús estándar App/Edit (⌘Q,
  portapapeles, undo) se instalan solos.
- **Persistencia**: `std/kv` con **una clave por tarea** (la clave es el `id`, un
  `uuid_v7` ordenable por tiempo, así `keys()` viene en orden de creación) y
  **guardado atómico** (temp + rename). Es la única fuente de verdad; los handlers
  son stateless (abren el store, operan, guardan por request), así que no hay estado
  mutable compartido entre las fibras de conexión. Se guarda en
  `~/Documents/RayDesk/tasks.kv` (en iOS la raíz del contenedor no es escribible;
  `Documents/` sí y persiste). `std/fs` se usa solo para crear ese directorio
  (`fs.mkdir`, mkdir -p).

## Módulos

```
src/
├── model.ray   # Todo + JSON (una tarea <-> objeto; lista para la API) + @test
├── store.ray   # repositorio sobre std/kv (list/add/toggle/remove/clear_done)
└── main.ray    # app web (rutas + static_embedded), ventana std/ui + event loop
```

## Ejecutar

```sh
ray add web@^0.2.0      # (ya en ray.toml) descarga web + net del registro
ray run                 # abre la ventana (dev: assets en vivo desde disco)
ray dev                 # igual, con recarga al guardar cambios
ray test                # corre los @test del proyecto (4 tests en model)
ray build --native --release
ray bundle --name RayDesk --id org.rayala.raydesk   # empaqueta la .app / .desktop
```

> Verificado con el MCP de raylang usando el parámetro `path` (contexto de
> proyecto: resuelve módulos y dependencias). El servidor se probó headless con
> `curl`: `GET /` (text/html + ETag), `GET /app.js` (text/javascript + ETag),
> `POST /api/list|add|toggle|clear-done` y — reiniciando el servidor entre medias —
> se confirmó que las tareas **persisten** en el store `kv` (altas, toggle y
> clear-done sobreviven), con UTF-8, y `..` → 404. La ventana real se abre en tu
> máquina con `ray run`.

## Características de raylang ejercitadas

paquete `web` 0.2.0 (Tier-2: `listen_on`, `static_embedded`) · `std/ui`
(ventana, `app_menu`, `menu`, `eval_js`, `save_file`, eventos) · `std/net` ·
`std/kv` (store con guardado atómico) · `std/fs` (`mkdir`, export) ·
`std/json` · `std/uuid` (`uuid_v7`) · `std/time` · módulos + `pub` ·
concurrencia (`spawn`) · `struct`/`enum` (uso cross-módulo) · pattern matching ·
`Result`/`Option` + `?` · closures (`map`) · `@test`.

## Notas de desarrollo

- [`ROADMAP.md`](ROADMAP.md) — lo que se echó de menos y su estado (varias cosas
  ya resueltas: `listen_on`, `static_embedded`, `ray_doc` de módulos, docs).
- [`BUGS.md`](BUGS.md) — posibles bugs con repro (todos resueltos a día de hoy).
