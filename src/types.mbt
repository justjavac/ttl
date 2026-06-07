///|
/// Event kind emitted by a `TTL` cache.
pub(all) enum EventKind {
  /// A key was found and has not expired.
  Hit
  /// A key was not found, or was expired before the read completed.
  Miss
  /// A key expired during lazy cleanup.
  Expired
  /// A new key was rejected because the cache was at capacity.
  Drop
  /// A key was added or replaced.
  Set
  /// A key was removed manually, by replacement, by clear, or by expiry.
  Del
} derive(Debug, Eq, Hash)

///|
/// Event payload passed to cache listeners.
pub(all) struct TTLEvent[T] {
  kind : EventKind
  key : String
  val : T?
  expire_ms : Int64?
} derive(Debug, Eq)

///|
/// Item returned by `TTL::entries`.
pub(all) struct CacheEntry[T] {
  key : String
  val : T
  expire_ms : Int64
} derive(Debug, Eq)

///|
/// Item accepted by `TTL::mset`.
pub(all) struct SetEntry[T] {
  key : String
  val : T
  ttl_ms : Int64?
} derive(Debug, Eq)

///|
/// Creates an entry for `TTL::mset`.
pub fn[T] SetEntry::new(key : String, val : T, ttl_ms? : Int64) -> SetEntry[T] {
  { key, val, ttl_ms }
}

///|
struct Item[T] {
  val : T
  expire_ms : Int64
}

///|
struct Listener[T] {
  id : Int
  callback : (TTLEvent[T]) -> Unit
}

///|
/// A generic in-memory time-to-live cache.
///
/// The cache is runtime-neutral: callers pass `now_ms` to methods that need a
/// clock. Expired values are removed lazily on reads or explicit cleanup.
pub struct TTL[T] {
  store : Map[String, Item[T]]
  listeners : Map[EventKind, Array[Listener[T]]]
  mut default_ttl_ms : Int64
  mut capacity : Int
  mut next_listener_id : Int
}
