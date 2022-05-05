import 'package:nimbostratus/nimbostratus_document_snapshot.dart';
import 'package:nimbostratus/nimbostratus_optimistic_document_snapshot.dart';
import 'package:restate/restate.dart';

class NimbostratusStateBloc<T>
    extends StateBloc<NimbostratusDocumentSnapshot<T?>> {
  NimbostratusStateBloc([NimbostratusDocumentSnapshot<T?>? initialValue])
      : super(initialValue);

  @override
  // ignore: avoid_renaming_method_parameters
  void add(snap) {
    if (snap is NimbostratusOptimisticDocumentSnapshot<T?>) {
      final currentSnap = value;

      if (currentSnap is NimbostratusOptimisticDocumentSnapshot<T?>) {
        currentSnap.next = snap;
      }
      snap.prev = value;
    }
    super.add(snap);
  }

  void rollback(NimbostratusOptimisticDocumentSnapshot<T?> snap) {
    final currentSnap = value;
    final prev = snap.prev;
    final next = snap.next;

    // If the current value is the snap we're trying to roll back, then emit
    // the previous snap either optimistic or otherwise.
    if (currentSnap == snap) {
      // If there is no previous value, meaning that the first snap for this document was an optimistic snap,
      // then create a null non-optimistic snap and emit that.
      if (prev == null) {
        add(currentSnap!.withValue(null));
      } else {
        add(prev);
      }
      // Otherwise we're an intermediate optimistic value that has either optimistic or real
      // updates after it. We don't need to re-emit the snap being rolled back since it is already
      // a stale value and just need to remove it from the optimistic update linked list.
    } else {
      if (prev is NimbostratusOptimisticDocumentSnapshot<T?>) {
        prev.next = next;
      }
      if (next is NimbostratusOptimisticDocumentSnapshot<T?>) {
        next.prev = prev;
      }
    }
  }
}
