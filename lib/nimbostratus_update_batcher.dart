import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nimbostratus/nimbostratus.dart';
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
  final Map<String, NimbostratusStateBloc> _documents;
  final FirebaseFirestore _firestore;
  late NimbostratusWriteBatch _batch;

  final Future<NimbostratusDocumentSnapshot<T?>> Function<T>(
    DocumentReference<T> ref,
    T data, {
    WritePolicy writePolicy,
    ToFirestore<T>? toFirestore,
    NimbostratusWriteBatch? batch,
    bool isOptimistic,
  }) _update;

  final Future<NimbostratusDocumentSnapshot<T?>> Function<T>(
    DocumentReference<T> ref,
    T Function(T? currentValue) modifyFn, {
    WritePolicy writePolicy,
    ToFirestore<T>? toFirestore,
    NimbostratusWriteBatch? batch,
    bool isOptimistic,
  }) _modify;

  NimbostratusUpdateBatcher({
    required FirebaseFirestore firestore,
    required Map<String, NimbostratusStateBloc> documents,
    required Future<NimbostratusDocumentSnapshot<T?>> Function<T>(
      DocumentReference<T> ref,
      T data, {
      WritePolicy writePolicy,
      ToFirestore<T>? toFirestore,
      NimbostratusWriteBatch? batch,
      bool isOptimistic,
    })
        update,
    required Future<NimbostratusDocumentSnapshot<T?>> Function<T>(
      DocumentReference<T> ref,
      T Function(T? currentValue) modifyFn, {
      WritePolicy writePolicy,
      ToFirestore<T>? toFirestore,
      NimbostratusWriteBatch? batch,
      bool isOptimistic,
    })
        modify,
  })  : _documents = documents,
        _update = update,
        _modify = modify,
        _firestore = firestore,
        _batch = NimbostratusWriteBatch(batch: firestore.batch());

  final List<NimbostratusDocumentSnapshot> _optimisticSnaps = [];

  Future<NimbostratusDocumentSnapshot<T?>> modify<T>(
    DocumentReference<T> ref,
    T Function(T? currentValue) modifyFn, {
    WritePolicy writePolicy = WritePolicy.serverFirst,
    ToFirestore<T>? toFirestore,
  }) async {
    /// A [WritePolicy.serverFirst] is not optimistic as it waits for the server response. Otherwise
    /// the batch update will be optimistic since both [WritePolicy.cacheOnly] and [WritePolicy.cacheAndServer]
    /// will optimistically write to the cache first.
    bool isOptimistic = writePolicy != WritePolicy.serverFirst;

    final snap = await _modify<T>(
      ref,
      modifyFn,
      writePolicy: writePolicy,
      toFirestore: toFirestore,
      batch: _batch,
      isOptimistic: isOptimistic,
    );

    assert(
      snap.isOptimistic == isOptimistic,
      'An update indiciated as optimistic was expected to return an optimistic snapshot.',
    );

    if (isOptimistic) {
      _optimisticSnaps.add(snap);
    }
    return snap;
  }

  Future<NimbostratusDocumentSnapshot<T?>> update<T>(
    DocumentReference<T> ref,
    T data, {
    WritePolicy writePolicy = WritePolicy.serverFirst,
    ToFirestore<T>? toFirestore,
  }) async {
    /// A [WritePolicy.serverFirst] is not optimistic as it waits for the server response. Otherwise
    /// the batch update will be optimistic since both [WritePolicy.cacheOnly] and [WritePolicy.cacheAndServer]
    /// will optimistically write to the cache first.
    bool isOptimistic = writePolicy != WritePolicy.serverFirst;

    final snap = await _update<T>(
      ref,
      data,
      writePolicy: writePolicy,
      toFirestore: toFirestore,
      batch: _batch,
      isOptimistic: isOptimistic,
    );

    assert(
      snap.isOptimistic == isOptimistic,
      'An update indiciated as optimistic was expected to return an optimistic snapshot.',
    );

    if (isOptimistic) {
      _optimisticSnaps.add(snap);
    }
    return snap;
  }

  void commitOptimisticUpdates() {
    // After the batcher completes, all optimistically updated snapshots can be
    // marked as no longer optimistic.
    for (final snap in _optimisticSnaps) {
      snap.isOptimistic = false;
    }
    _optimisticSnaps.clear();
  }

  Future<void> commit() async {
    await _batch.commit();
    commitOptimisticUpdates();
  }

  void rollback() {
    _batch = NimbostratusWriteBatch(batch: _firestore.batch());
    // Rollback all optimistic snaps in the reverse order they were applied.
    for (final optimisticSnap in _optimisticSnaps.reversed) {
      _documents[optimisticSnap.reference.path]!.rollback(optimisticSnap);
    }
  }
}
