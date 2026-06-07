///|
test "set get miss and events" {
  let cache : @ttl.TTL[String] = @ttl.TTL::new(default_ttl_ms=10L)
  let events : Array[String] = []
  cache.add_listener(@ttl.EventKind::Set, fn(event) {
    events.push("\{event.kind}:\{event.key}:\{event.val.unwrap()}")
  })
  |> ignore
  cache.add_listener(@ttl.EventKind::Hit, fn(event) {
    events.push("\{event.kind}:\{event.key}:\{event.val.unwrap()}")
  })
  |> ignore
  cache.add_listener(@ttl.EventKind::Miss, fn(event) {
    events.push("\{event.kind}:\{event.key}")
  })
  |> ignore

  assert_true(cache.set("foo", "bar", now_ms=0L))
  assert_eq(cache.size(), 1)
  guard cache.get("foo", now_ms=1L) is Some("bar") else {
    fail("expected foo hit")
  }
  guard cache.get("hello", now_ms=1L) is None else {
    fail("expected hello miss")
  }
  assert_eq(events.join(", "), "Set:foo:bar, Hit:foo:bar, Miss:hello")
}

///|
test "expiry is lazy and emits expired del miss" {
  let cache : @ttl.TTL[String] = @ttl.TTL::new(default_ttl_ms=10L)
  let events : Array[String] = []
  cache.add_listener(@ttl.EventKind::Expired, fn(event) {
    events.push("\{event.kind}:\{event.key}:\{event.val.unwrap()}")
  })
  |> ignore
  cache.add_listener(@ttl.EventKind::Del, fn(event) {
    events.push("\{event.kind}:\{event.key}:\{event.val.unwrap()}")
  })
  |> ignore
  cache.add_listener(@ttl.EventKind::Miss, fn(event) {
    events.push("\{event.kind}:\{event.key}")
  })
  |> ignore

  assert_true(cache.set("foo", "bar", now_ms=100L))
  guard cache.get("foo", now_ms=110L) is None else {
    fail("expected foo to expire")
  }
  assert_eq(cache.size(), 0)
  assert_eq(events.join(", "), "Expired:foo:bar, Del:foo:bar, Miss:foo")
}

///|
test "delete clear and capacity" {
  let cache : @ttl.TTL[String] = @ttl.TTL::new(default_ttl_ms=10L, capacity=1)
  let dropped : Array[String] = []
  cache.add_listener(@ttl.EventKind::Drop, fn(event) {
    dropped.push("\{event.key}:\{event.val.unwrap()}")
  })
  |> ignore

  assert_true(cache.set("foo", "bar", now_ms=0L))
  assert_false(cache.set("hello", "world", now_ms=0L))
  assert_eq(cache.size(), 1)
  guard cache.del("foo") is Some("bar") else { fail("expected foo delete") }
  guard cache.del("foo") is None else {
    fail("expected second foo delete to miss")
  }
  assert_true(cache.set("hello", "world", now_ms=0L))
  cache.clear()
  assert_eq(cache.size(), 0)
  assert_eq(dropped.join(", "), "hello:world")
}

///|
test "mset entries purge and listener removal" {
  let cache : @ttl.TTL[String] = @ttl.TTL::new(default_ttl_ms=10L)
  let hits : Array[String] = []
  let id = cache.add_listener(@ttl.EventKind::Hit, fn(event) {
    hits.push(event.key)
  })

  let accepted = cache.mset(
    [
      @ttl.SetEntry::new("foo", "bar"),
      @ttl.SetEntry::new("ping", "pong", ttl_ms=20L),
    ],
    now_ms=0L,
  )
  assert_eq(accepted, 2)
  assert_eq(cache.entries(now_ms=5L).length(), 2)
  guard cache.get("foo", now_ms=5L) is Some("bar") else {
    fail("expected foo hit")
  }
  assert_true(cache.remove_listener(@ttl.EventKind::Hit, id))
  guard cache.get("ping", now_ms=5L) is Some("pong") else {
    fail("expected ping hit")
  }
  assert_eq(cache.purge_expired(now_ms=20L), 2)
  assert_eq(cache.size(), 0)
  assert_eq(hits.join(", "), "foo")
}
