# justjavac/ttl

[![CI](https://github.com/justjavac/ttl/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/justjavac/ttl/actions/workflows/ci.yml)
[![coverage](https://img.shields.io/codecov/c/github/justjavac/ttl/main?label=coverage)](https://codecov.io/gh/justjavac/ttl)

A small runtime-neutral TTL cache for MoonBit.

```mbt check
///|
test {
  let ttl : @ttl.TTL[String] = @ttl.TTL::new(default_ttl_ms=10_000L)

  assert_true(ttl.set("foo", "bar", now_ms=0L))

  guard ttl.get("foo", now_ms=1L) is Some("bar") else {
    fail("expected foo hit")
  }
  guard ttl.get("foo", now_ms=10_000L) is None else {
    fail("expected foo to expire")
  }
}
```
