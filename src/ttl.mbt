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
  { key, val: item.val, expire_ms: item.expire_ms }
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
