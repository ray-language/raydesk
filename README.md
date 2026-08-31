# RayDesk

Un gestor de tareas de **escritorio** escrito en [raylang](https://raylang.dev)
(probado con **1.4.0**). Ventana nativa (webview del sistema) + backend HTTP
local sobre el framework `web` + persistencia en disco. Pensado como banco de
pruebas de las características del lenguaje.

## Arquitectura

```
┌─────────────────────────┐     HTTP (127.0.0.1:PUERTO)      ┌───────────────────────┐
│  Ventana nativa          │  ───────────────────────────▶   │  Backend raylang      │
│  std/ui + webview        │   GET  /api/tasks                │  web (Express-style)  │
│  (assets/index.html,     │   POST /api/tasks   {title}      │   sobre net/webserver │
│   app.css, app.js)       │   POST /api/toggle  {id}         │                       │
│                          │   POST /api/delete  {id}         │  handlers stateless   │
│  fetch() ◀───── JSON ────│   POST /api/clear-done           │  GET /*rest → embed   │
└─────────────────────────┘   GET  /*rest  (assets)          └──────────┬────────────┘
                                                                         │
                                          std/fs + std/json (model)      ▼
                                                          ~/.raydesk-tasks.json
```

- **UI**: `std/ui.open()` abre una ventana nativa que carga el servidor local;
  el hilo principal atiende sus eventos y cierra el proceso al cerrar la ventana.
- **Servidor**: `web.listen(build, "127.0.0.1", port)` corre en una fibra
  (`spawn`). El puerto se obtiene libre con `std/net` (bind 0) y se reutiliza
  para la URL de la ventana.
- **Handlers stateless**: el archivo JSON es la única fuente de verdad
  (load → mutar → save por request). Así no hay estado mutable compartido entre
  las fibras de conexión del framework.
- **Assets**: servidos con `std/embed` desde una ruta catch-all `"/*rest"`; en
  `ray build --native` se hornean en el binario (una `.app` arranca con `cwd=/`).

## Módulos

```
src/
├── model.ray   # Todo + JSON + operaciones puras (add/toggle/remove/clear) + @test
├── store.ray   # persistencia en disco (std/fs)
└── main.ray    # app web (rutas), assets embebidos, ventana std/ui + event loop
```

## Ejecutar

```sh
ray add web             # (ya en ray.toml) descarga web + net del registro
ray run                 # abre la ventana (dev: assets en vivo desde disco)
ray dev                 # igual, con recarga al guardar cambios
ray test                # corre los @test del proyecto (3 tests en model)
ray build --native --release
ray bundle --name RayDesk --id org.rayala.raydesk   # empaqueta la .app / .desktop
```

> Verificado con el MCP de raylang usando el parámetro `path` (contexto de
> proyecto: resuelve módulos y dependencias). El servidor `web` se probó headless
> con `curl` (rutas, assets con su `Content-Type`, API con persistencia, 404).
> La ventana real se abre en tu máquina con `ray run`.

## Características de raylang ejercitadas

paquete `web` (Tier-2) · `std/ui` · `std/net` · `std/embed` · `std/fs` ·
`std/json` · `std/uuid` (`uuid_v7`) · `std/time` · módulos + `pub` ·
concurrencia (`spawn`) · `struct`/`enum` · pattern matching ·
`Result`/`Option` + `?` · closures (`map`/`filter`) · `@test`.

## Notas de desarrollo

- [`ROADMAP.md`](ROADMAP.md) — características que se echaron de menos (con lo ya
  resuelto en 1.4.0).
- [`BUGS.md`](BUGS.md) — posibles bugs con repro (`std/kv` get/set ausente).
