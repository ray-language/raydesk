# RayLang — características que se echaron de menos

Lista de deseos surgida al construir **RayDesk** (una app de escritorio real:
ventana nativa + servidor HTTP local + persistencia). No son bugs (esos van en
[`BUGS.md`](BUGS.md)), sino huecos de API, ergonomía o documentación que
habrían hecho el trabajo más directo. Ordenado por impacto percibido.

---

## 1. Un servidor/router HTTP mínimo en la stdlib

El patrón recomendado para apps de escritorio (`std/ui`) es *"tu webserver
embebido en 127.0.0.1"*, pero el único webserver está en **`packages/net`**
(Tier 2, no embebido). Para un proyecto autocontenido hubo que escribir a mano
sobre `std/net`:

- parseo de la request line y las cabeceras,
- lectura del cuerpo respetando `Content-Length` (en bytes, no en caracteres),
- construcción de respuestas y `Content-Type`.

Es *boilerplate* que casi toda app local va a reescribir. **Deseable:** un
`std/http` mínimo (aunque sea solo el lado servidor: parseo de request +
helpers de respuesta + router por ruta/método), o mover un subconjunto de
`packages/net/webserver` a la stdlib embebida.

## 2. Un puente IPC de primera clase para `std/ui`

`std/ui` da `eval_js(h, js)` (raylang → JS, *fire-and-forget*) pero el camino
de vuelta (JS → raylang) hay que fabricarlo con un servidor HTTP local. Un
canal de mensajes bidireccional tipado (p. ej. `ui.on_message()` +
`window.raydesk.send(...)` en el webview) eliminaría por completo la necesidad
del servidor para la mayoría de apps.

## 3. Ergonomía: tupla/paréntesis como expresión final de un bloque

```raylang
fn f(...) -> (string, [Todo]) {
    if (cond) { xs.push(...); }
    (payload, xs)   // ← se parsea como  if{...}(payload, xs)  → error
}
```

Hay que intercalar un `let` para romper la ambigüedad. El error es claro, pero
una expresión-tupla al final de un bloque es una forma muy común (sobre todo al
devolver varios valores). **Deseable:** resolver la ambigüedad a favor de la
tupla cuando el bloque previo es una sentencia `if`/`while` sin `else`, o al
menos que `ray fmt` inserte el separador.

## 4. Documentación de módulos accesible desde el MCP / `ray doc`

`ray_doc` (MCP) solo cubre *builtins*; no da la firma de una función de módulo
(`fs.write_file`, `kv.*`, `ui.*`). Para descubrir la API hubo que probar por
compilación (`ray_check` como oráculo). **Deseable:** `ray_doc "fs.write_file"`
o un `ray doc std/fs` que liste las exportaciones de un módulo. Relacionado con
los huecos de la referencia (ver #6).

## 5. Mejor diagnóstico al chocar con un builtin genérico

`struct Task { … }` → `Task expects 1 type argument, not 0`. El mensaje no dice
que `Task` es un builtin (`Task<T>`, concurrencia) y que el nombre está tomado.
**Deseable:** algo como *"'Task' es un tipo builtin (Task<T>); elige otro
nombre"*.

## 6. Huecos en `reference.md`

Encontrados al vuelo (la implementación va por delante de la doc):

- **`std/fs.mkdir`** existe y compila, pero **no aparece** en la superficie de
  `std/fs` de la referencia §10. (Útil, por ejemplo, para crear `~/.raydesk/`.)
- **`std/kv`** documenta un get/set que no existe (ver `BUGS.md #1`).

**Deseable:** mantener §10 sincronizada con las exportaciones reales, o
generarla desde el código.

## 7. Verificación multi-módulo desde el MCP

`ray_check`/`ray_run` compilan **un archivo autocontenido** en un tmp aislado,
así que un proyecto multi-módulo no se puede verificar módulo a módulo por el
MCP (las importaciones a archivos propios no resuelven). Por eso RayDesk mantiene
todo el backend en un único `src/main.ray`. **Deseable:** un modo del MCP que
compile en el contexto del proyecto (`ray.toml`) para poder dividir en módulos
sin perder la validación por agente.

---

## Cosas que SÍ estaban y funcionaron muy bien

Para equilibrar: el lenguaje cubrió la mayor parte de la app sin fricción.

- `std/ui` (ventana + webview del sistema) y `std/embed` (assets embebidos) —
  la app de escritorio nativa sale "de fábrica".
- `std/net` TCP: `tcp_listen`/`accept`/`socket_read`/`socket_write_bytes` +
  `local_port` bastaron para el servidor; el binding a puerto 0 da puerto libre.
- Concurrencia: `spawn` para el servidor en paralelo a la UI, con estado mutable
  encapsulado en la fibra del servidor (sin locks).
- `std/json` (parse/stringify + enum `Json`) — serialización limpia; maneja
  UTF-8 correctamente (probado con acentos end-to-end).
- `std/fs`, `std/uuid` (`uuid_v7` ordenable por tiempo), `std/time`.
- `Result`/`Option` + `?` — el manejo de errores del servidor quedó conciso.
- `@test` + `ray test` — 6 tests de la lógica pura, todos verdes vía MCP.
