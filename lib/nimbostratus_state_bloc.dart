import 'package:nimbostratus/nimbostratus_document_snapshot.dart';
import 'package:restate/restate.dart';

class NimbostratusStateBloc<T>
    extends StateBloc<NimbostratusDocumentSnapshot<T?>> {
  NimbostratusStateBloc([NimbostratusDocumentSnapshot<T?>? initialValue])
      : super(initialValue);

  @override
  // ignore: avoid_renaming_method_parameters
  void add(snap) {
    // Optimistic snapshots link their previous and next snapshots in order to support
    // rollback of optimistic updates.
    if (snap?.isOptimistic ?? false) {
      final currentSnap = value;

      if (currentSnap?.isOptimistic ?? false) {
        currentSnap!.next = snap;
      }
      snap!.prev = value;
    }
    super.add(snap);
  }

  // Replay an optimistic snap on the stream after a rollback.
  void _replay(NimbostratusDocumentSnapshot<T?> snap) {
    super.add(snap);
  }

  /// Rolls back the supplied optimistic snapshot. If the snapshot being rolled back is the current
  /// value on the stream, then the snapshot that was chronologically emitted before it becomes the most logical current value
  /// for the stream and it is replayed on the stream.
  void rollback(NimbostratusDocumentSnapshot<T?> snap) {
    assert(
      snap.isOptimistic,
      'Attempted to rollback a non-optimistic snap',
    );

    final currentSnap = value;
    final prev = snap.prev;
    final next = snap.next;

    // If the current value is the optimistic snap that is being rolled back, then we need to re-emit the previous value.
    if (currentSnap == snap) {
      // If there is no previous value, meaning that the first snap for this document was an optimistic snap,
      // then create a null non-optimistic snap and replay that.
      if (prev == null) {
        _replay(currentSnap!.withValue(null));
      } else {
        _replay(prev);
      }
      // Otherwise we're rolling back an intermediate optimistic value that has either optimistic or real
      // updates after it. We don't need to re-emit the snap being rolled back since it is already
      // a stale value and just need to remove it from the optimistic updates snapshot linked list.
    } else {
      if (prev != null && prev.isOptimistic) {
        prev.next = next;
      }
      if (next != null && next.isOptimistic) {
        next.prev = prev;
      }
    }
  }
}
