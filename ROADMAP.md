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

### 2. Descubrir un puerto libre para `web.listen`

`web.listen(build, host, port)` exige un puerto fijo y **bloquea**. Para una app
de escritorio hay que abrir la ventana en el mismo puerto, así que RayDesk pide
un puerto efímero con `std/net` (bind 0 → `local_port` → `close`) y se lo pasa a
`web.listen` — hay una micro-ventana de carrera entre el `close` y el re-bind.
**Deseable:** que `web.listen`/`webserver.serve*` acepten puerto `0` y devuelvan
el puerto elegido (p. ej. por un canal/callback), o un `bind()` + `serve(listener)`
separados.

### 3. `web.static_embedded` no existe (pese al `llms.txt`)

El `llms.txt` dice que `web` trae `static_embedded` "para los assets de
`[native] embed`", pero el paquete solo expone `static_files`/`static_files_cached`
(sirven desde un **directorio en disco**, que no vale en una `.app` con `cwd=/`).
Por eso RayDesk sirve los assets embebidos con una ruta catch-all + `std/embed`.
**Deseable:** implementar `static_embedded(app, prefix)` sobre `std/embed`, o
corregir el `llms.txt`.

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

### 5. Documentación de módulos accesible desde el MCP / `ray doc`

`ray_doc` (MCP) solo cubre *builtins*; no da la firma de una función de módulo
(`fs.write_file`, `ui.*`) ni de un paquete (`web.*`). Para aprender la API de
`web` hubo que **leer su código** en `.ray-deps/web/framework.ray`. **Deseable:**
`ray_doc "web.listen"` o `ray doc <paquete>` que liste exportaciones y firmas.

### ✅ RESUELTO — 6. Diagnóstico al chocar con un builtin genérico

En 1.4.0 el mensaje al usar `struct Task` como tipo ya es claro (antes: el
confuso *"Task expects 1 type argument, not 0"*):

```
type error: 'Task' is a builtin type (Task<T>) and shadows your struct of the
same name; rename your type
```

Justo lo que se pedía. (Ver `BUGS.md`.)

### 7. Huecos en `reference.md`

- **`std/fs.mkdir`** existe y compila, pero **no aparece** en la superficie de
  `std/fs` de la referencia §10.
- **`std/kv`** documenta un get/set que no existe (ver `BUGS.md #1`).
- El **paquete `web`** no está documentado en la referencia §11 (que solo cubre
  `net`, `rpc`, `db`), aunque el `llms.txt` sí lo menciona.

**Deseable:** mantener la referencia sincronizada con la superficie real, o
generarla desde el código.

### 8. Estado compartido entre handlers del framework `web`

Con `web`, cada conexión corre en su fibra y las fibras tienen heaps aislados, así
que no se puede compartir un `var todos` capturado entre handlers. RayDesk lo
resuelve siendo **stateless** (carga/guarda el archivo por request; la app es
mono-usuario y los datos son pequeños). Para algo con más carga haría falta el
patrón actor (un dueño de estado + canales) o `std/kv` en su forma `share`.
**Deseable:** un helper de estado por-app en `web` (p. ej. un actor de sesión de
aplicación) para no reimplementarlo en cada proyecto.

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
