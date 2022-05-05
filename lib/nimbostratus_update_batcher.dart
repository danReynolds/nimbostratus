import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nimbostratus/nimbostratus.dart';
import 'package:nimbostratus/nimbostratus_optimistic_document_snapshot.dart';
import 'package:nimbostratus/nimbostratus_state_bloc.dart';

/// An extension of the [WriteBatch] with support for making changes and rolling back
/// the Nimbostratus in-memory cache.
class NimbostratusWriteBatch implements WriteBatch {
  final WriteBatch batch;
  final List<Future<void> Function()> listeners = [];

  NimbostratusWriteBatch({
    required this.batch,
  });

  void onCommit(Future<void> Function() callback) {
    listeners.add(callback);
  }

  @override
  Future<void> commit() async {
    await batch.commit();
    for (var callback in listeners) {
      await callback();
    }
  }

  @override
  void delete(DocumentReference document) => batch.delete(document);

  @override
  void set<T>(
    DocumentReference<T> document,
    T data, [
    SetOptions? options,
  ]) =>
      batch.set(document, data, options);

  @override
  void update(DocumentReference document, Map<String, dynamic> data) =>
      batch.update(document, data);
}

class NimbostratusUpdateBatcher {
  final Nimbostratus store;
  final Map<String, NimbostratusStateBloc> _documents;
  final FirebaseFirestore _firestore;
  late NimbostratusWriteBatch _batch;

  NimbostratusUpdateBatcher({
    required this.store,
    required FirebaseFirestore firestore,
    required Map<String, NimbostratusStateBloc> documents,
  })  : _documents = documents,
        _firestore = firestore,
        _batch = NimbostratusWriteBatch(batch: firestore.batch());

  final List<NimbostratusOptimisticDocumentSnapshot> _optimisticSnaps = [];

  Future<NimbostratusDocumentSnapshot<T?>> modify<T>(
    DocumentReference<T> ref,
    T Function(T? currentValue) modifyFn, {
    WritePolicy writePolicy = WritePolicy.serverFirst,
    ToFirestore<T>? toFirestore,
  }) async {
    final snap = await store.modifyDocument<T>(
      ref,
      modifyFn,
      writePolicy: writePolicy,
      toFirestore: toFirestore,
      batch: _batch,
      isOptimistic: true,
    ) as NimbostratusOptimisticDocumentSnapshot<T?>;
    _optimisticSnaps.add(snap);
    return snap;
  }

  Future<NimbostratusDocumentSnapshot<T?>> update<T>(
    DocumentReference<T> ref,
    T data, {
    WritePolicy writePolicy = WritePolicy.serverFirst,
    ToFirestore<T>? toFirestore,
  }) async {
    final snap = await store.updateDocument<T>(
      ref,
      data,
      writePolicy: writePolicy,
      toFirestore: toFirestore,
      batch: _batch,
      isOptimistic: true,
    ) as NimbostratusOptimisticDocumentSnapshot<T?>;
    _optimisticSnaps.add(snap);
    return snap;
  }

  Future<void> commit() async {
    return _batch.commit();
  }

  void rollback() {
    _batch = NimbostratusWriteBatch(batch: _firestore.batch());
    for (final optimisticSnap in _optimisticSnaps) {
      _documents[optimisticSnap.reference.path]!.rollback(optimisticSnap);
    }
  }
}
