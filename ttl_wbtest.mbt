///|
test "set capacity rejects negative values" {
  let cache : TTL[Int] = TTL::new()
  assert_false(cache.set_capacity(-1))
  assert_eq(cache.capacity(), 1_000_000_000)
  assert_true(cache.set_capacity(0))
  assert_eq(cache.capacity(), 0)
}
