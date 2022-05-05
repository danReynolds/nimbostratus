import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nimbostratus/nimbostratus_document_snapshot.dart';

// ignore: subtype_of_sealed_class
class NimbostratusOptimisticDocumentSnapshot<T>
    extends NimbostratusDocumentSnapshot<T> {
  NimbostratusDocumentSnapshot<T>? prev;
  NimbostratusDocumentSnapshot<T>? next;

  NimbostratusOptimisticDocumentSnapshot({
    required T? value,
    required Stream<NimbostratusDocumentSnapshot<T?>> stream,
    required DocumentReference<T> reference,
    required SnapshotMetadata metadata,
  }) : super(
          reference: reference,
          stream: stream,
          value: value,
          metadata: metadata,
        );

  static NimbostratusOptimisticDocumentSnapshot fromSnap<S>(
      NimbostratusDocumentSnapshot<S> snap) {
    return NimbostratusOptimisticDocumentSnapshot<S>(
      reference: snap.reference,
      value: snap.value,
      stream: snap.stream,
      metadata: snap.metadata,
    );
  }
}
