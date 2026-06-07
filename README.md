# justjavac/ttl

[![CI](https://github.com/justjavac/ttl/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/justjavac/ttl/actions/workflows/ci.yml)
[![coverage](https://img.shields.io/codecov/c/github/justjavac/ttl/main?label=coverage)](https://codecov.io/gh/justjavac/ttl)
[![linux](https://img.shields.io/codecov/c/github/justjavac/ttl/main?flag=linux&label=linux)](https://codecov.io/gh/justjavac/ttl)
[![macos](https://img.shields.io/codecov/c/github/justjavac/ttl/main?flag=macos&label=macos)](https://codecov.io/gh/justjavac/ttl)
[![windows](https://img.shields.io/codecov/c/github/justjavac/ttl/main?flag=windows&label=windows)](https://codecov.io/gh/justjavac/ttl)

`justjavac/ttl` is a small in-memory TTL(Time To Live) cache for MoonBit. It is inspired by [justjavac/deno_ttl](https://github.com/justjavac/deno_ttl), with the API adapted for MoonBit packages and cross-target builds.

The package is runtime-neutral. It does not read the system clock or schedule timers internally. Instead, callers pass `now_ms` to operations that need time, and expired entries are removed lazily when they are read, checked, listed, counted with a timestamp, or explicitly purged.

## Installation

```bash
moon add justjavac/ttl
```

Then import it from a package:

```moonbit
import {
  "justjavac/ttl"
}
```

## Usage

```moonbit
fn main {
  let ttl : @ttl.TTL[String] = @ttl.TTL::new(default_ttl_ms=10_000L)

  ignore(ttl.set("foo", "bar", now_ms=0L))
  ignore(ttl.set("ping", "pong", now_ms=0L, ttl_ms=20_000L))

  match ttl.get("foo", now_ms=1L) {
    Some(value) => println(value)
    None => println("missing")
  }

  match ttl.get("foo", now_ms=10_000L) {
    Some(value) => println(value)
    None => println("expired")
  }
}
```

Run the bundled example:

```bash
moon run src/examples/basic --target native
```

## Time Model

The cache stores expiration times as millisecond timestamps. `TTL::set` computes `expire_ms` as `now_ms + ttl_ms`. An entry is considered expired when `expire_ms <= now_ms`.

This explicit clock model makes the package deterministic in tests and keeps it usable on `wasm`, `wasm-gc`, `js`, and `native` without target-specific timer dependencies.

## API

### `TTL::new(default_ttl_ms? : Int64 = 10_000L, capacity? : Int = 1_000_000_000) -> TTL[T]`

Creates an empty cache. `default_ttl_ms` is used by `set` and `mset` when no per-entry TTL is supplied. `capacity` limits the number of distinct keys.

### `TTL::set(key, val, now_ms~, ttl_ms?) -> Bool`

Adds or replaces a key. Returns `false` when the key is new and the cache is already at capacity. Replacing an existing key emits `Del` for the old entry and `Set` for the new entry.

### `TTL::mset(entries, now_ms~) -> Int`

Adds multiple entries and returns how many were accepted. Use `SetEntry::new(key, val, ttl_ms?)` to build each entry.

### `TTL::get(key, now_ms~) -> T?`

Returns `Some(value)` when the key exists and has not expired. If the key is missing or expired, returns `None`. Expired entries are removed before returning.

### `TTL::has(key, now_ms~) -> Bool`

Returns whether a key exists and has not expired. Expired entries are removed.

### `TTL::del(key) -> T?`

Deletes a key and returns its value when present.

### `TTL::clear() -> Unit`

Deletes all entries.

### `TTL::purge_expired(now_ms~) -> Int`

Removes all expired entries and returns the number removed.

### `TTL::size(now_ms?) -> Int`

Returns the number of stored entries. If `now_ms` is supplied, expired entries are purged before counting.

### `TTL::entries(now_ms~) -> Array[CacheEntry[T]]`

Purges expired entries and returns a snapshot of unexpired entries.

### `TTL::set_capacity(capacity) -> Bool`

Updates the capacity. Negative values are rejected and return `false`.

### `TTL::set_default_ttl_ms(ttl_ms) -> Unit`

Updates the default TTL used by later `set` calls.

## Events

Listeners are registered per event kind:

```moonbit
let cache : @ttl.TTL[String] = @ttl.TTL::new()

let listener_id = cache.add_listener(@ttl.EventKind::Hit, fn(event) {
  println("hit \{event.key}")
})

ignore(cache.remove_listener(@ttl.EventKind::Hit, listener_id))
```

The cache emits:

| Event | Meaning |
| --- | --- |
| `Set` | A key was added or replaced. |
| `Del` | A key was removed manually, by replacement, by clear, or by expiry. |
| `Expired` | A key expired during lazy cleanup. |
| `Hit` | A key was found and has not expired. |
| `Miss` | A key was missing, or expired before the read completed. |
| `Drop` | A new key was rejected because the cache was at capacity. |

`TTLEvent[T]` contains:

| Field | Description |
| --- | --- |
| `kind` | Event kind. |
| `key` | Cache key. |
| `val` | Value when the event has one. |
| `expire_ms` | Expiration timestamp when available. |

## Project Structure

This repository follows the same root-documentation and `src` package layout used by `moonbit-ci`:

| Path | Purpose |
| --- | --- |
| `README.md` | Detailed GitHub-facing documentation. |
| `README.mbt.md` | Concise MoonBit markdown README with checked example. |
| `src/` | Main `justjavac/ttl` package. |
| `src/examples/basic/` | Runnable example package. |
| `.github/workflows/ci.yml` | Multi-platform MoonBit CI and coverage. |
| `codecov.yml` | Codecov flag configuration. |

## Development

```bash
moon check --target all
moon test --target all
moon run src/examples/basic --target native
moon test --target native --enable-coverage
moon coverage analyze -p justjavac/ttl -- -f summary
```

Regenerate public interfaces after API changes:

```bash
moon info
```

Format before committing:

```bash
moon fmt --check
moon fmt
```

## License

MIT. See [LICENSE](LICENSE).
