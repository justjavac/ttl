# justjavac/ttl

A small in-memory TTL(Time To Live) cache for MoonBit.

The API follows the shape of
[justjavac/deno_ttl](https://github.com/justjavac/deno_ttl), adapted for
MoonBit's runtime-neutral packages. Callers pass `now_ms` to operations that
need time, and expired items are removed lazily on reads or explicit cleanup.

## Usage

```mbt check
///|
test {
  let ttl : @ttl.TTL[String] = @ttl.TTL::new(default_ttl_ms=10_000L)
  let hits : Array[String] = []

  ttl.add_listener(@ttl.EventKind::Hit, fn(event) { hits.push(event.key) })
  |> ignore

  assert_true(ttl.set("foo", "bar", now_ms=0L))
  assert_true(ttl.set("ping", "pong", now_ms=0L, ttl_ms=20_000L))

  guard ttl.get("foo", now_ms=1L) is Some("bar") else {
    fail("expected foo hit")
  }
  guard ttl.get("lol", now_ms=1L) is None else { fail("expected lol miss") }

  guard ttl.get("foo", now_ms=10_000L) is None else {
    fail("expected foo to expire")
  }
  guard ttl.del("ping") is Some("pong") else { fail("expected ping delete") }
  ttl.clear()
  assert_eq(ttl.size(), 0)
  assert_eq(hits.join(", "), "foo")
}
```

## Events

The cache emits:

- `Set` - a key has been added or changed.
- `Del` - a key has been removed manually, by replacement, by clear, or by expiry.
- `Expired` - a key expired during lazy cleanup.
- `Hit` - a key was found in the cache.
- `Miss` - a key was not found, or was expired before the read completed.
- `Drop` - a new key was rejected because the cache was at capacity.

## License

MIT
