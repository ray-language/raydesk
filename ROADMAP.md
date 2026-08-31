# RayLang — características que se echaron de menos

Lista de deseos surgida al construir **RayDesk** (app de escritorio real:
ventana nativa + backend HTTP local + persistencia). No son bugs (esos van en
[`BUGS.md`](BUGS.md)), sino huecos de API, ergonomía o documentación.

> Revisado contra **raylang 1.4.0**. Varias entradas de la primera pasada ya
> quedaron cubiertas por el propio lenguaje/ecosistema; se marcan como
> ✅ RESUELTO y se conservan por trazabilidad.

---

## ✅ RESUELTO — verificación multi-módulo desde el MCP

En la primera versión, `ray_check`/`ray_run`/`ray_test` solo compilaban un
archivo autocontenido (parámetro `code`), así que un proyecto multi-módulo no se
podía validar por el MCP. En 1.4.0 el `llms.txt` documenta el parámetro
**`path`**: las tres tools corren con el proyecto como contexto (resuelven
imports entre archivos y `[dependencies]` igual que `ray run`). RayDesk pasó a
ser un proyecto de verdad (`src/model.ray`, `src/store.ray`, `src/main.ray`) y
se valida entero por MCP con `path`.

## ✅ RESUELTO (vía paquete Tier-2) — base HTTP para apps de escritorio

La primera versión escribía a mano el parseo HTTP sobre `std/net`. El `llms.txt`
de 1.4.0 explicita el paquete **`web`** (Express-style sobre `net/webserver`),
descrito como *"la base recomendada para backends de escritorio con `std/ui`"*.
RayDesk ahora lo usa (`ray add web`): rutas, catch-all `"/*rest"` para servir los
assets embebidos, y `web.listen` en una fibra mientras `std/ui` corre en el hilo
principal. Se eliminó todo el HTTP hecho a mano.

Queda como deseo **menor**: un servidor mínimo en la *stdlib embebida* (sin
`ray add`) para apps locales de cero dependencias.

---

## Pendientes

### 1. Un puente IPC de primera clase para `std/ui`

`std/ui` da `eval_js(h, js)` (raylang → JS) pero el camino de vuelta (JS →
raylang) hay que fabricarlo con un servidor HTTP local (ahora con `web`). Un
canal de mensajes bidireccional tipado (`ui.on_message()` + `window.raydesk.send`
en el webview) evitaría el servidor para la mayoría de apps.

### ✅ RESUELTO Y ADOPTADO (web 0.2.0) — 2. Puerto libre para `web.listen`

**`web.listen_on(build, listener)`** (M150) da el split bind/serve. RayDesk
bindea con `net.tcp_listen("127.0.0.1", 0)`, lee el puerto con `net.local_port`
(lo conoce sin carrera; el backlog acepta desde el bind) y sirve en ese mismo
listener. Se eliminó `free_port()` y su micro-carrera close/re-bind.

### ✅ RESUELTO Y ADOPTADO (web 0.2.0) — 3. `web.static_embedded`

**`static_embedded(app, prefix, dir)`** (M147) sirve del espacio `[native] embed`
(disco en vivo en dev, horneado en nativo). RayDesk monta `static_embedded(app,
"/", "assets")` y con ello ganó **ETag + 304 + Range** y bloqueo de path-traversal
"de fábrica"; se borraron `serve_asset`, `content_type` y el import de `std/embed`
(~40 líneas menos). Detalle del framework: los mounts sirven GET/HEAD **antes** que
las rutas, así que la API se expone como **POST** (incluida la lectura
`/api/list`) — el modelo explícito "GET = assets, POST = rutas".

### 4. Ergonomía: tupla/paréntesis como expresión final de un bloque

```raylang
fn f(...) -> (string, [Todo]) {
    if (cond) { xs.push(...); }
    (payload, xs)   // ← se parsea como  if{...}(payload, xs)  → error
}
```

Hay que intercalar un `let` para romper la ambigüedad. El error es claro, pero es
una forma muy común al devolver varios valores. **Deseable:** resolver a favor de
la tupla cuando el bloque previo es una sentencia, o que `ray fmt` lo separe.

### ✅ RESUELTO — 5. Documentación de módulos desde el MCP / `ray doc`

`ray_doc` ahora resuelve funciones de módulo std (`ray_doc "fs.write_file"`),
**métodos de trait** (`ray_doc "kv.get_string"` → *"trait StoreOps"*) y símbolos de
paquete pasando `path` (`ray_doc "web.listen"` sobre el proyecto). Ya no hace falta
leer el código del paquete para conocer una firma. (Queda como deseo menor: un
listado de TODAS las exportaciones de un módulo — `ray_doc "std/kv"` responde
"usa module.function").

### ✅ RESUELTO — 6. Diagnóstico al chocar con un builtin genérico

En 1.4.0 el mensaje al usar `struct Task` como tipo ya es claro (antes: el
confuso *"Task expects 1 type argument, not 0"*):

```
type error: 'Task' is a builtin type (Task<T>) and shadows your struct of the
same name; rename your type
```

Justo lo que se pedía. (Ver `BUGS.md`.)

### ✅ RESUELTO — 7. Huecos en `reference.md`

Los tres huecos que se habían anotado ya están corregidos en la referencia:

- **`std/fs.mkdir`** aparece ahora en la superficie de `std/fs` §10 (y en `ray_doc`:
  *"Creates a directory, including any missing parents (like `mkdir -p`)"*).
- **`std/kv`** §10 describe la API real (métodos del trait `StoreOps`:
  `s.get`/`s.set`/`s.get_string`/`s.set_string`/`s.delete`/`s.keys`). Ver `BUGS.md #1`.
- El **paquete `web`** tiene su propia sección en §11 (título ahora
  `net`, `web`, `rpc`, `db`).

Queda un desajuste **inverso** menor: la referencia §11 documenta `listen_on` y
`static_embedded` (M150/M147) que aún no están en el paquete publicado 0.1.0
(ver #2 y #3) — ahora la doc va por delante del paquete.

### 8. Estado compartido entre handlers del framework `web`

Con `web`, cada conexión corre en su fibra y las fibras tienen heaps aislados, así
que no se puede compartir un `var todos` capturado entre handlers. RayDesk lo
resuelve siendo **stateless**: cada request abre el store `std/kv`, opera y guarda
(guardado atómico). La app es mono-usuario y los datos pequeños, así que abrir por
request es barato. Para más carga se usaría la forma **actor** de `std/kv`
(`open_shared`/`share`, un dueño de estado + canales) y así no releer el archivo en
cada request. **Deseable:** un helper de estado por-app en `web` (p. ej. envolver
ese actor) para no cablearlo en cada proyecto.

---

## Cosas que SÍ estaban y funcionaron muy bien

- `std/ui` (ventana + webview) + `std/embed` (assets embebidos) — app de
  escritorio nativa "de fábrica".
- El paquete **`web`**: routing, catch-all `"/*rest"`, `web.json`/`web.body`,
  escritura directa de `Res.body` (bytes) para servir binario — muy directo.
- `ray add` resolvió `web` + `net` desde el registro sin fricción.
- Concurrencia: `spawn` para el servidor en paralelo a la UI.
- `std/json`, `std/fs`, `std/uuid` (`uuid_v7`), `std/time`.
- `Result`/`Option` + `?`, closures, `@test` (3 tests del `model`, verdes por MCP).
- **Verificación por `path`**: `ray_check`/`ray_test` sobre el proyecto real,
  con dependencias resueltas.
