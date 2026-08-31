# RayDesk

Un gestor de tareas de **escritorio** escrito en [raylang](https://raylang.dev).
Ventana nativa (webview del sistema) + servidor HTTP local + persistencia en
disco. Pensado como banco de pruebas de las características del lenguaje.

![arquitectura](#arquitectura)

## Arquitectura

```
┌─────────────────────────┐     HTTP (127.0.0.1:PUERTO)      ┌──────────────────┐
│  Ventana nativa          │  ───────────────────────────▶   │  Backend raylang │
│  std/ui + webview        │   GET  /api/tasks                │  std/net server  │
│  (assets/index.html,     │   POST /api/tasks   {title}      │  handle_api()    │
│   app.css, app.js)       │   POST /api/toggle  {id}         │                  │
│                          │   POST /api/delete  {id}         │  estado en la    │
│  fetch() ◀───── JSON ────│   POST /api/clear-done           │  fibra servidora │
└─────────────────────────┘                                  └────────┬─────────┘
                                                                       │
                                            std/fs + std/json          ▼
                                                          ~/.raydesk-tasks.json
```

- **UI**: `std/ui.open()` abre una ventana nativa que carga el servidor local.
- **Servidor**: una fibra (`spawn`) corre el bucle `accept`; el hilo principal
  atiende los eventos de la ventana y cierra el proceso al cerrarla.
- **Estado**: la lista de tareas vive en la fibra del servidor (sin locks) y se
  persiste como JSON tras cada mutación.
- **Assets**: servidos con `std/embed`; en `ray build --native` se hornean en el
  binario (una `.app` arranca con `cwd=/`, por eso van embebidos).

Todo el backend está en un único `src/main.ray` a propósito: así se puede
type-checkear y testear entero a través del MCP de raylang (`ray mcp`).

## Ejecutar

```sh
ray run                 # abre la ventana (dev: assets en vivo desde disco)
ray dev                 # igual, con recarga al guardar cambios
ray test                # corre los @test de la lógica (6 tests)
ray build --native --release
ray bundle --name RayDesk --id org.rayala.raydesk   # empaqueta la .app / .desktop
```

> Nota: el MCP de raylang corre en un sandbox sin pantalla, así que la ventana
> real se abre en tu máquina con `ray run`. La lógica de servidor y de datos sí
> está verificada de punta a punta vía `ray_run`/`ray_test` (incluido un test de
> integración cliente/servidor sobre socket, con contenido UTF-8).

## Características de raylang ejercitadas

`std/ui` · `std/net` · `std/fs` · `std/json` · `std/embed` · `std/uuid` ·
`std/time` · concurrencia (`spawn`, estado por fibra) · `struct`/`enum` ·
pattern matching · `Result`/`Option` + `?` · closures (`map`/`filter`) ·
tuplas · `@test`.

## Notas de desarrollo

- [`ROADMAP.md`](ROADMAP.md) — características que se echaron de menos.
- [`BUGS.md`](BUGS.md) — posibles bugs detectados (con repro).

## Estructura

```
raydesk/
├── ray.toml            # paquete + [native] embed = ["assets"]
├── src/main.ray        # backend completo (modelo, servidor, API, main, tests)
├── assets/
│   ├── index.html
│   ├── app.css
│   └── app.js
├── README.md
├── ROADMAP.md
└── BUGS.md
```
