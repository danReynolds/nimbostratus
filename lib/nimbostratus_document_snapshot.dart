// ignore: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nimbostratus/cache_snapshot_metadata.dart';

// ignore: subtype_of_sealed_class
class NimbostratusDocumentSnapshot<T> implements DocumentSnapshot<T> {
  final T? value;
  final Stream<NimbostratusDocumentSnapshot<T?>> stream;

  // Optimistic snapshots maintain pointers to previous and next snaps to support
  // rollback of optimistic updates.
  NimbostratusDocumentSnapshot<T>? prev;
  NimbostratusDocumentSnapshot<T>? next;
  // Whether the snapshot is an optimistic snapshot update.
  bool isOptimistic;

  @override
  late final String id;

  @override
  late final SnapshotMetadata metadata;

  @override
  final DocumentReference<T> reference;

  NimbostratusDocumentSnapshot({
    required this.value,
    required this.stream,
    required this.reference,
    this.isOptimistic = false,
    SnapshotMetadata? metadata,
  })  : id = reference.id,
        metadata = metadata ?? CacheSnapshotMetadata();

  @override
  bool get exists => data() != null;

  @override
  T? data() => value;

  @override
  dynamic get(Object field) {
    return null;
  }

  @override
  dynamic operator [](Object field) => get(field);

  NimbostratusDocumentSnapshot<T?> withValue(T? value) {
    return NimbostratusDocumentSnapshot<T?>(
      reference: reference,
      value: value,
      stream: stream,
    );
  }
}
