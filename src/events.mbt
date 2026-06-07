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
