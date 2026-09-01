# RayDesk

Un gestor de tareas de **escritorio, iOS y Android** escrito en
[raylang](https://raylang.dev) (probado con **1.4.0**). Ventana/webview del
sistema + puente IPC de `std/ui` + persistencia con `std/kv`. El **mismo programa
raylang** (`src/`) corre en macOS, Linux, iOS y Android. Pensado como banco de
pruebas de las características del lenguaje.

## Arquitectura

```
┌─────────────────────────┐   window.ray.send(json)  ──────▶ ┌───────────────────────┐
│  Ventana nativa          │        (IPC, std/ui)             │  Backend raylang      │
│  std/ui + webview        │                                  │  event loop (1 fibra) │
│  (assets/index.html,     │ ◀── eval_js(rayRender(tasks)) ── │  handle_message()     │
│   app.css, app.js)       │                                  │  → std/kv (abierto 1x)│
│                          │   GET / , /app.*  (assets) ────▶ │  web (solo estáticos) │
└─────────────────────────┘                                  └──────────┬────────────┘
                                        std/kv (store, 1 clave/tarea)     ▼
                                               ~/Documents/RayDesk/tasks.kv
```

- **UI**: `std/ui.open()` abre una ventana nativa que carga la página; la **fibra
  principal** corre el event loop (`ui.next_event`) y cierra el proceso al cerrar
  la ventana.
- **Datos (IPC, `std/ui`)**: la página llama **`window.ray.request(cmd)`** (p. ej.
  `{"cmd":"add","title":…}`) y recibe una **Promise** que resuelve con la lista
  actualizada (JSON). En raylang llega como evento `"message"`; `handle_message`
  lo decodifica con **`ui.as_request`**, muta el store `kv` y resuelve la Promise
  con **`ui.reply(window, id, json)`**. Sin API HTTP. (Fallback: `window.ray.send`
  fire-and-forget + push por `eval_js(window.rayRender…)`, para shells antiguos y
  las actualizaciones iniciadas por menús.)
- **Assets**: **`web.static_embedded(app, "/", "assets")`** sirve la página
  (bundle-safe, con ETag/304/Range); el servidor `web` corre en otra fibra
  (`spawn` + `web.listen_on`) y **solo** sirve estáticos. El puerto se obtiene sin
  carrera con `net.tcp_listen(…, 0)` + `net.local_port`.
- **Look**: UI moderna con **Tailwind CSS** (build purgado: `assets/app.css` solo
  contiene las clases realmente usadas en `index.html`/`app.js`, ~12 KB
  minificado). Botones azules con estados hover/active/focus-ring, tarjetas
  redondeadas con sombra, modo oscuro por `prefers-color-scheme` (variantes
  `dark:`). Regenerar tras tocar clases: `tailwind/build.sh` (o `ray dev` para el
  raylang; el CSS se rehace con el script). Fuentes en `tailwind/` (config +
  input); la salida `assets/app.css` va embebida.
- **Menús** (`std/ui`): "Acerca de RayDesk" va en el **menú de app** (macOS: el
  primero, en negrita) vía `ui.app_menu`, que además lo retitula a "RayDesk"
  incluso bajo `ray run`. Más menús custom "Archivo" (Nueva tarea ⌘N, Exportar
  tareas… ⌘E, Recargar ⌘R) y "Tarea" (Limpiar completadas ⌘K) con `ui.menu`. El
  click llega como evento `"menu"` con `tag`; las acciones manejan el frontend vía
  `ui.eval_js` (reusan los handlers de la página, así la UI queda sincronizada),
  "Exportar" abre el diálogo nativo `ui.save_file`, y "Acerca de RayDesk"
  (`tag: "role:about"`) abre el **panel About nativo** de macOS relleno con
  `ui.set_about` (nombre, versión, descripción, ©); en Linux cae en un modal
  informativo en la webview. Los menús estándar App/Edit (⌘Q, portapapeles, undo)
  se instalan solos.
- **Persistencia**: `std/kv` con **una clave por tarea** (la clave es el `id`, un
  `uuid_v7` ordenable por tiempo, así `keys()` viene en orden de creación) y
  **guardado atómico** (temp + rename). El store se **abre una sola vez** y lo
  posee la fibra del event loop (el único que lo toca), así que no se reabre por
  mensaje ni hay carrera con la fibra del servidor. Se guarda en
  `~/Documents/RayDesk/tasks.kv` (en iOS la raíz del contenedor no es escribible;
  `Documents/` sí y persiste). `std/fs` se usa solo para crear ese directorio
  (`fs.mkdir`). Para acceso concurrente entre fibras `std/kv` ofrece la forma
  actor (`open_shared`) y ops atómicas (`incr`, `set_if`), aquí no necesarias.

## Módulos

```
src/
├── model.ray   # Todo + JSON (una tarea <-> objeto; lista para la API)
├── store.ray   # repositorio std/kv (list/add/toggle/remove/clear_done) + apply(cmd)
└── main.ray    # web static + IPC (window.ray → std/kv) + std/ui event loop
tests/
├── model_test.ray  # (de)serialización y field_of
└── store_test.ray  # CRUD del store + dispatch de comandos (store.apply)
assets/
├── index.html  # utilidades Tailwind
├── app.js      # frontend: IPC (window.ray.request/send + rayRender) + Tailwind
└── app.css     # GENERADO por Tailwind (purgado) — no editar a mano
tailwind/
├── tailwind.config.js  # content: index.html + app.js
├── input.css           # @tailwind base/components/utilities
└── build.sh            # regenera assets/app.css
raydesk-ios/            # shell iOS (Xcode) generado por `ray bundle --ios`
├── Shell/              # AppDelegate + SceneDelegate (UIScene) en Objective-C
├── App.xcconfig        # build settings + firma (DEVELOPMENT_TEAM)
├── raydesk.xcodeproj/
├── libs/ · libs-sim/   # staticlib del programa (regenerable, gitignored)
└── rebuild.sh          # ray bundle --ios + re-aplica la firma
raydesk-android/        # shell Android (Gradle) generado por `ray bundle --android`
├── app/src/main/       # MainActivity + RayBridge (Java), Manifest, res/
│   └── jniLibs/<abi>/  # libray_app.so (cdylib del programa; regenerable, gitignored)
├── app/build.gradle · settings.gradle · gradle.properties
└── README.md           # compilar/instalar el APK
```

## Ejecutar

```sh
ray add web@^0.2.0      # (ya en ray.toml) descarga web + net del registro
ray run                 # abre la ventana (dev: assets en vivo desde disco)
ray dev                 # igual, con recarga al guardar cambios
ray test                # corre los @test de tests/ (13: model + store)
ray build --native --release
ray bundle --name RayDesk --id org.rayala.raydesk   # empaqueta la .app / .desktop
```

> Verificado con el MCP de raylang usando el parámetro `path` (contexto de
> proyecto: resuelve módulos y dependencias) y con corridas headless: los assets
> se sirven bien (`web` + `RAY_UI_BACKEND=headless`), y el **camino IPC** se probó
> inyectando un mensaje con `RAY_UI_MSG='{"cmd":"add","title":"…"}'` — la tarea
> llega a `handle_message`, se guarda en el store `kv` (verificado abriéndolo) y
> **persiste** entre lanzamientos, con UTF-8. La ventana real se abre con `ray run`.

## iOS

El **mismo `src/`** corre en iOS: `ray bundle --ios` compila el programa raylang a
un **staticlib** y genera un shell Xcode en `raydesk-ios/`. Dentro de la app, el
programa arranca su webserver embebido en `127.0.0.1` y `ui.open(title, url)` carga
esa URL en un `WKWebView` — el mismo frontend (`assets/`) y la misma API que en
escritorio. Los eventos de ciclo de vida llegan por `ui.next_event()` como
`kind="lifecycle"`, `tag="background"`/`"foreground"`.

- **Persistencia**: en iOS la raíz del contenedor de la app no es escribible, por
  eso el store `kv` vive en `~/Documents/RayDesk/tasks.kv` (escribible y persiste
  entre lanzamientos). Ver `src/store.ray`.
- **UI**: `raydesk-ios/Shell` usa el ciclo de vida **UIScene** (`SceneDelegate`
  aloja el `WKWebView` y conecta los handlers de `std/ui`).

### Compilar y ejecutar

```sh
# Regenera el staticlib + proyecto Xcode y re-aplica la firma en cada build
raydesk-ios/rebuild.sh
# (equivale a `ray bundle --ios`, que además borra la firma — ver ROADMAP #9)

# Simulador (sin firma):
xcodebuild -project raydesk-ios/raydesk.xcodeproj -target raydesk \
  -sdk iphonesimulator -configuration Debug build CODE_SIGNING_ALLOWED=NO
# luego: xcrun simctl boot <device> && install && launch

# Dispositivo: abre raydesk-ios/raydesk.xcodeproj en Xcode y compila.
```

- **Firma**: el `DEVELOPMENT_TEAM` se fija en `raydesk-ios/App.xcconfig`. Como
  `ray bundle --ios` regenera ese archivo, usa **`raydesk-ios/rebuild.sh`** (o
  `RAY_IOS_TEAM=XXXXXXXXXX raydesk-ios/rebuild.sh`) para re-aplicarlo tras cada
  build. Detalle en [`ROADMAP.md`](ROADMAP.md) #9.
- Los `libs/`/`libs-sim/` (staticlibs, ~15 MB) están **gitignored**: se regeneran
  con el comando de arriba.

## Android

El **mismo `src/`** corre en Android: `ray bundle --android` compila el programa
raylang a un **cdylib** (`libray_app.so`) y genera un shell Gradle en
`raydesk-android/`. La `MainActivity` (Java) aloja un `WebView`, arranca el
programa (que sirve la UI en `127.0.0.1`) y expone el mismo **puente IPC** que
escritorio/iOS: `window.ray.send(text)` → evento `"message"` (`RayBridge`); los
eventos `lifecycle` llegan en `onPause`/`onResume`. stdout/stderr van a **logcat**
con tag `ray`.

- **Persistencia**: `std/kv`/`std/fs` escriben en el directorio privado de la app
  (scoped storage; el cwd no es escribible).
- **Red**: `network_security_config.xml` permite cleartext a `127.0.0.1`/`localhost`
  (el webserver embebido).

### Compilar y ejecutar

```sh
ray bundle --android                    # genera el shell + libray_app.so
#   --android-abi arm64|x86_64|all      # construye un ABI (conserva el otro .so)

cd raydesk-android
gradle assembleDebug                    # requiere Android SDK + JDK 17+
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb logcat -s ray                       # stdout/stderr del programa
```

- **ABI**: el `app/build.gradle` fija `arm64-v8a`; para el **emulador x86_64** usa
  `ray bundle --android --android-abi all` (si no: `INSTALL_FAILED_NO_MATCHING_ABIS`).
- **`local.properties`** (ruta del SDK) y todo lo de build (`.gradle/`, `build/`,
  el APK y `libray_app.so`) están **gitignored** — se regeneran. Detalles en
  [`raydesk-android/README.md`](raydesk-android/README.md).

## Características de raylang ejercitadas

paquete `web` 0.2.0 (Tier-2: `listen_on`, `static_embedded`) · `std/ui`
(ventana, **puente IPC** `window.ray.request`/`send` + `as_request`/`reply`,
`eval_js`, `app_menu`, `set_about`, `menu`, `save_file`, eventos) · `std/net` ·
`std/kv` (store con guardado atómico) · `std/fs` (`mkdir`, export) ·
`std/json` · `std/uuid` (`uuid_v7`) · `std/time` · módulos + `pub` ·
concurrencia (`spawn`) · `struct`/`enum` (uso cross-módulo) · pattern matching ·
`Result`/`Option` + `?` · closures (`map`) · `@test`.

## Notas de desarrollo

- [`ROADMAP.md`](ROADMAP.md) — lo que se echó de menos y su estado (varias cosas
  ya resueltas: `listen_on`, `static_embedded`, `ray_doc` de módulos, docs).
- [`BUGS.md`](BUGS.md) — posibles bugs con repro (todos resueltos a día de hoy).
