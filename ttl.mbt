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
pub impl Show for EventKind with fn to_string(self) {
  match self {
    Hit => "Hit"
    Miss => "Miss"
    Expired => "Expired"
    Drop => "Drop"
    Set => "Set"
    Del => "Del"
  }
}

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

///|
/// Creates an empty TTL cache.
pub fn[T] TTL::new(
  default_ttl_ms? : Int64 = 10_000L,
  capacity? : Int = 1_000_000_000,
) -> TTL[T] {
  { store: {}, listeners: {}, default_ttl_ms, capacity, next_listener_id: 0 }
}

///|
/// Returns the configured default TTL in milliseconds.
pub fn[T] TTL::default_ttl_ms(self : TTL[T]) -> Int64 {
  self.default_ttl_ms
}

///|
/// Updates the default TTL in milliseconds.
pub fn[T] TTL::set_default_ttl_ms(self : TTL[T], ttl_ms : Int64) -> Unit {
  self.default_ttl_ms = ttl_ms
}

///|
/// Returns the maximum number of keys accepted by the cache.
pub fn[T] TTL::capacity(self : TTL[T]) -> Int {
  self.capacity
}

///|
/// Updates cache capacity. Negative values are rejected.
pub fn[T] TTL::set_capacity(self : TTL[T], capacity : Int) -> Bool {
  if capacity < 0 {
    false
  } else {
    self.capacity = capacity
    true
  }
}

///|
/// Registers an event listener and returns its listener id.
pub fn[T] TTL::add_listener(
  self : TTL[T],
  kind : EventKind,
  callback : (TTLEvent[T]) -> Unit,
) -> Int {
  self.next_listener_id += 1
  let listener = Listener::{ id: self.next_listener_id, callback }
  match self.listeners.get(kind) {
    Some(listeners) => listeners.push(listener)
    None => self.listeners[kind] = [listener]
  }
  self.next_listener_id
}

///|
/// Removes a previously registered listener.
pub fn[T] TTL::remove_listener(
  self : TTL[T],
  kind : EventKind,
  listener_id : Int,
) -> Bool {
  match self.listeners.get(kind) {
    None => false
    Some(listeners) => {
      let before = listeners.length()
      listeners.retain(fn(listener) { listener.id != listener_id })
      before != listeners.length()
    }
  }
}

///|
fn[T] TTL::dispatch(self : TTL[T], event : TTLEvent[T]) -> Unit {
  match self.listeners.get(event.kind) {
    Some(listeners) =>
      for listener in listeners {
        (listener.callback)(event)
      }
    None => ()
  }
}

///|
fn[T] TTL::emit(
  self : TTL[T],
  kind : EventKind,
  key : String,
  val : T?,
  expire_ms : Int64?,
) -> Unit {
  self.dispatch({ kind, key, val, expire_ms })
}

///|
fn[T] TTL::remove_expired_key(
  self : TTL[T],
  key : String,
  item : Item[T],
) -> Unit {
  self.emit(Expired, key, Some(item.val), Some(item.expire_ms))
  ignore(self.del(key))
}

///|
/// Sets a key-value pair. Returns `false` when a new key is dropped because the
/// cache is at capacity.
pub fn[T] TTL::set(
  self : TTL[T],
  key : String,
  val : T,
  now_ms~ : Int64,
  ttl_ms? : Int64,
) -> Bool {
  let ttl = match ttl_ms {
    Some(ttl) => ttl
    None => self.default_ttl_ms
  }
  let already_present = self.store.contains(key)
  if !already_present && self.store.length() >= self.capacity {
    self.emit(Drop, key, Some(val), None)
    false
  } else {
    if already_present {
      ignore(self.del(key))
    }
    let expire_ms = now_ms + ttl
    self.store[key] = { val, expire_ms }
    self.emit(Set, key, Some(val), Some(expire_ms))
    true
  }
}

///|
/// Sets multiple keys and returns the number accepted by the cache.
pub fn[T] TTL::mset(
  self : TTL[T],
  entries : ArrayView[SetEntry[T]],
  now_ms~ : Int64,
) -> Int {
  let mut accepted = 0
  for entry in entries {
    let ok = match entry.ttl_ms {
      Some(ttl) => self.set(entry.key, entry.val, now_ms~, ttl_ms=ttl)
      None => self.set(entry.key, entry.val, now_ms~)
    }
    if ok {
      accepted += 1
    }
  }
  accepted
}

///|
fn[T] entry_key(pair : (String, Item[T])) -> String {
  let (key, _) = pair
  key
}

///|
fn[T] entry_item(pair : (String, Item[T])) -> Item[T] {
  let (_, item) = pair
  item
}

///|
fn[T] cache_entry_from_pair(pair : (String, Item[T])) -> CacheEntry[T] {
  let (key, item) = pair
  CacheEntry::{ key, val: item.val, expire_ms: item.expire_ms }
}

///|
/// Gets a value by key and removes it first if it has expired.
pub fn[T] TTL::get(self : TTL[T], key : String, now_ms~ : Int64) -> T? {
  match self.store.get(key) {
    None => {
      self.emit(Miss, key, None, None)
      None
    }
    Some(item) =>
      if item.expire_ms <= now_ms {
        self.remove_expired_key(key, item)
        self.emit(Miss, key, None, None)
        None
      } else {
        self.emit(Hit, key, Some(item.val), Some(item.expire_ms))
        Some(item.val)
      }
  }
}

///|
/// Returns whether a key exists and has not expired.
pub fn[T] TTL::has(self : TTL[T], key : String, now_ms~ : Int64) -> Bool {
  match self.store.get(key) {
    None => false
    Some(item) =>
      if item.expire_ms <= now_ms {
        self.remove_expired_key(key, item)
        false
      } else {
        true
      }
  }
}

///|
/// Deletes a key and returns its value when present.
pub fn[T] TTL::del(self : TTL[T], key : String) -> T? {
  match self.store.get(key) {
    None => None
    Some(item) => {
      self.store.remove(key)
      self.emit(Del, key, Some(item.val), Some(item.expire_ms))
      Some(item.val)
    }
  }
}

///|
/// Removes all keys, emitting `Del` for each removed item.
pub fn[T] TTL::clear(self : TTL[T]) -> Unit {
  let entries = self.store.to_array()
  for pair in entries {
    let key = entry_key(pair)
    ignore(self.del(key))
  }
}

///|
/// Removes all expired keys and returns the number removed.
pub fn[T] TTL::purge_expired(self : TTL[T], now_ms~ : Int64) -> Int {
  let entries = self.store.to_array()
  let mut removed = 0
  for pair in entries {
    let key = entry_key(pair)
    let item = entry_item(pair)
    if item.expire_ms <= now_ms {
      self.remove_expired_key(key, item)
      removed += 1
    }
  }
  removed
}

///|
/// Returns the number of stored keys. When `now_ms` is supplied, expired keys
/// are purged before counting.
pub fn[T] TTL::size(self : TTL[T], now_ms? : Int64) -> Int {
  match now_ms {
    Some(now) => ignore(self.purge_expired(now_ms=now))
    None => ()
  }
  self.store.length()
}

///|
/// Returns unexpired cache entries. Expired keys are purged before the snapshot
/// is produced.
pub fn[T] TTL::entries(self : TTL[T], now_ms~ : Int64) -> Array[CacheEntry[T]] {
  ignore(self.purge_expired(now_ms~))
  self.store.to_array().map(cache_entry_from_pair)
}
