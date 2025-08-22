import Foundation

/// A synchronization primitive that protects shared mutable state via mutual exclusion.
///
/// A back-port of Swift's `Mutex` type for wider platform availability.
#if hasFeature(StaticExclusiveOnly)
  @_staticExclusiveOnly
#endif
struct Mutex<Value: ~Copyable>: ~Copyable {
  private let _lock = NSLock()
  private let _box: Box

  /// Initializes a value of this mutex with the given initial state.
  ///
  /// - Parameter initialValue: The initial value to give to the mutex.
  package init(_ initialValue: consuming sending Value) {
    _box = Box(initialValue)
  }

  private final class Box {
    var value: Value
    init(_ initialValue: consuming sending Value) {
      value = initialValue
    }
  }
}

extension Mutex: @unchecked Sendable where Value: ~Copyable {}

extension Mutex where Value: ~Copyable {
  /// Calls the given closure after acquiring the lock and then releases ownership.
  borrowing func withLock<Result: ~Copyable, E: Error>(
    _ body: (inout sending Value) throws(E) -> sending Result
  ) throws(E) -> sending Result {
    _lock.lock()
    defer { _lock.unlock() }
    return try body(&_box.value)
  }
}
