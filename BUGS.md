# RayLang — posibles bugs detectados

Anotaciones de comportamientos que parecen incorrectos, encontrados mientras
se construía RayDesk. Verificados con `ray mcp` (`ray_check` / `ray_run`).
Cada uno lleva un repro mínimo.

> **Revisado contra raylang 1.4.0.** Estado al día:
> - #1 (`std/kv`) — **reclasificado**: no es "API inexistente" sino un error de
>   documentación; el módulo funciona con su API real (métodos). Sigue abierto
>   como bug de doc.
> - #2 (coma final en llamadas) — ✅ **RESUELTO** en 1.4.0.
> - Nota "struct Task" — ✅ el **mensaje** ya es claro en 1.4.0.
> - Nota "tupla tras `if`" — sigue vigente (papercut documentado).

---

## 1. `std/kv`: la referencia describe la API como `get`/`set` libres, pero es de métodos

**Severidad:** baja (bug de **documentación**; el módulo funciona).

**Corrección respecto a la primera versión de esta nota:** antes concluí que
`std/kv` era inutilizable. Es falso — me engañó la referencia. El módulo
funciona; lo que está mal es cómo lo describe `reference.md` §10:

> `Store` — estado clave/valor persistido: `open(path)`/`empty` + **get/set** sobre
> `Map<string, bytes>` …

Ese "get/set" se lee como funciones libres `kv.get` / `kv.set`, que **no existen**:

```raylang
import std/kv;
fn w(s: kv.Store) -> unit          { kv.set(s, "k", "v".to_bytes()); } // no export 'set'
fn r(s: kv.Store) -> Option<bytes> { kv.get(s, "k") }                  // no export 'get'
fn main() -> int { 0 }
```

```
module 'std/kv' does not export 'set' (missing 'pub'?)
```

La **API real** (descubierta en `.ray-deps/web/framework.ray`, que usa `std/kv`
para las sesiones) son constructores + **métodos sobre el store**:

- Constructores: `kv.open(path)`, `kv.empty(path)`, `kv.open_shared(path)`
  (forma actor `SharedStore`), `kv.share(store)`.
- Operaciones (métodos): `s.set_string(k, v)`, `s.get_string(k) -> Option<string>`,
  `s.delete(k)`, `s.save() -> Result<int, string>`.

Repro que **sí funciona** (verificado con `ray_run`, imprime `hola kv`):

```raylang
import std/kv;
fn demo() -> Result<string, string> {
    let s = kv.open_shared("/tmp/x.rkv")?;
    s.set_string("greeting", "hola kv");
    let got = match (s.get_string("greeting")) {
        Option.Some(v) => v,
        Option.None => "MISSING",
    };
    let _n = s.save()?;
    Result.Ok(got)
}
fn main() -> int { match (demo()) { Result.Ok(v) => { print(v); 0 }, Result.Err(_) => 1 } }
```

**Qué revisar:** alinear `reference.md` §10 — nombrar los constructores y aclarar
que las operaciones son **métodos** (`get_string`/`set_string`/`delete`/`save`),
no funciones libres `get`/`set`. (RayDesk sigue usando `std/fs` + JSON, que es
adecuado para su caso; pero `std/kv` era una opción válida desde el principio.)

---

## 2. Coma final rechazada en llamadas — ✅ RESUELTO en 1.4.0

**Estado:** corregido. En 1.4.0 `f(1, 2,)` **compila** (exit 0). Se conserva el
registro por trazabilidad.

Originalmente: la coma final se permitía en arrays (`[1, 2, 3,]`) y structs, pero
en la lista de argumentos de una llamada era `syntax error at …: expected an
expression, found RParen`. Molestaba en llamadas multi-línea (la forma a la que
`ray fmt` reparte las listas largas). Ya no ocurre.

---

## Observaciones que NO son bugs (comportamiento esperado)

- **`struct Task` colisiona con el builtin `Task<T>`** (concurrencia). Usar `Task`
  como tipo sigue siendo un error — es correcto (el builtin gana). **Mejora en
  1.4.0:** el mensaje ahora lo explica con claridad (antes era el confuso *"Task
  expects 1 type argument, not 0"*):

  ```
  type error: 'Task' is a builtin type (Task<T>) and shadows your struct of the
  same name; rename your type
  ```

  RayDesk usa `Todo`. La mejora de mensaje que se pedía en el ROADMAP ya está.

- **Tupla como expresión final tras un `if`/bloque** se parsea como *llamada* del
  valor del bloque (sigue en 1.4.0). Está documentado en `llms.txt` y el error lo
  explica (*"a tail starting with '(' … separate it with 'return' or 'let'"*). No
  es un bug; es un papercut ergonómico (ver ROADMAP #4). Repro:

  ```raylang
  fn f(cond: bool) -> (int, int) {
      if (cond) { let _x = 1; }
      (1, 2)   // ← error: se parsea como  if{...}(1, 2)
  }
  ```
