///|
/// Demonstrates basic cache operations with an explicit millisecond clock.
fn main {
  let cache : @ttl.TTL[String] = @ttl.TTL::new(default_ttl_ms=1_000L)
  ignore(cache.set("foo", "bar", now_ms=0L))
  match cache.get("foo", now_ms=1L) {
    Some(value) => println(value)
    None => println("expired")
  }
}
