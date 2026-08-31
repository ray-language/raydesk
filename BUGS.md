# RayLang — posibles bugs detectados

Anotaciones de comportamientos que parecen incorrectos, encontrados mientras
se construía RayDesk. Verificados con `ray mcp` (`ray_check` / `ray_run`).
Cada uno lleva un repro mínimo para revisarlo después.

> Revisado contra **raylang 1.4.0**. Estado al día: #1 sigue vigente; #2 quedó
> **RESUELTO** en 1.4.0.

---

## 1. `std/kv`: la API get/set documentada no existe

**Severidad:** media (el módulo parece inutilizable tal como está documentado).

`reference.md` §10 describe `std/kv` como:

> `Store` — estado clave/valor persistido: `open(path)`/`empty` + get/set sobre
> `Map<string, bytes>` con guardado atómico…

Pero el módulo **no exporta** ninguna de las funciones de lectura/escritura
que la documentación implica. Todas fallan en compilación:

```raylang
import std/kv;
fn w(s: kv.Store) -> unit          { kv.set(s, "k", "v".to_bytes()); } // no export 'set'
fn r(s: kv.Store) -> Option<bytes> { kv.get(s, "k") }                  // no export 'get'
fn p(s: kv.Store) -> unit          { kv.put(s, "k", "v".to_bytes()); } // no export 'put'
fn l(s: kv.Store) -> Option<bytes> { kv.load(s, "k") }                 // no export 'load'
fn main() -> int { 0 }
```

Diagnóstico en cada caso:

```
module 'std/kv' does not export 'set' (missing 'pub'?)
```

El tipo `kv.Store` sí resuelve, así que el módulo existe; lo que falta es su
superficie de get/set. O bien las funciones no llevan `pub`, o bien la
referencia describe una API que no se implementó.

**Impacto en RayDesk:** se descartó `std/kv` para persistencia y se usó
`std/fs` (`read_file`/`write_file` + JSON), que funciona sin problemas.

**Qué revisar:** confirmar la superficie real de `std/kv` y alinear
`reference.md`, o exponer las funciones que faltan con `pub`.

---

## 2. Coma final rechazada en llamadas — ✅ RESUELTO en 1.4.0

**Estado:** corregido. En 1.4.0 `f(1, 2,)` **compila** (exit 0). Se deja el
registro por trazabilidad; el texto original se conserva abajo.

La coma final está permitida en literales de arreglo (`[1, 2, 3,]`) y en
literales de struct, y `reference.md` §3 lo confirma. Pero en la **lista de
argumentos de una llamada** es un error de sintaxis:

```raylang
fn f(a: int, b: int) -> int { a + b }
fn main() -> int { f(1, 2,) }
```

```
syntax error at 2:27: expected an expression, found RParen
  2 | fn main() -> int { f(1, 2,) }
    |                           ^
```

Molesta especialmente al escribir llamadas multi-línea (un argumento por línea),
que es justo la forma a la que `ray fmt` reparte las listas largas. Se cayó en
esto en los `@test` de RayDesk:

```raylang
handle_api(
    Request { method: "POST", path: "/api/tasks", body: "…" },
    todos,   // ← esta coma final rompe la compilación
);
```

**Qué revisar:** permitir la coma final en las listas de argumentos (y de
parámetros de `fn`) por consistencia con arrays/structs, o documentar la
diferencia explícitamente.

---

## Observaciones que NO son bugs (comportamiento esperado, anotado para contexto)

- **`struct Task` colisiona con el builtin `Task<T>`** (el tipo de
  concurrencia). Un `struct Task { … }` falla con
  `type error: Task expects 1 type argument, not 0`. Es coherente con la regla
  "un builtin gana a un nombre de usuario", pero el mensaje no menciona la
  colisión. Se renombró a `Todo`. (Ver ROADMAP #5 para la mejora de mensaje.)

- **Tupla como expresión final tras un `if`/bloque** se parsea como *llamada*
  del valor del bloque. Está documentado en `llms.txt` y el error lo explica
  ("a tail starting with '(' … separate it with 'return' or 'let'"). No es un
  bug; es un papercut ergonómico (ver ROADMAP #2).
