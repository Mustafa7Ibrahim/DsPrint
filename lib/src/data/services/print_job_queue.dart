import 'dart:async';

/// Serializes jobs on a single instance so job B never starts before job A
/// settles. No static state (unlike the legacy chained-`Future` `_sendLock`
/// in `printer_html_dart_channel_controller.dart`) — each queue instance
/// owns its own tail.
class PrintJobQueue {
  Future<void> _tail = Future.value();

  /// A throwing/rejecting [job] does not wedge the queue — the tail always
  /// advances, so the next job still runs.
  Future<T> enqueue<T>(Future<T> Function() job) {
    final resultCompleter = Completer<T>();
    final settled = Completer<void>();
    final previousTail = _tail;
    _tail = settled.future;

    previousTail.then((_) async {
      try {
        resultCompleter.complete(await job());
      } catch (e, stackTrace) {
        resultCompleter.completeError(e, stackTrace);
      } finally {
        settled.complete();
      }
    });

    return resultCompleter.future;
  }
}
