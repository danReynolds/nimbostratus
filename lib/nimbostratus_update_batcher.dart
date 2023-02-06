import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nimbostratus/nimbostratus.dart';
import 'package:nimbostratus/nimbostratus_state_bloc.dart';
import 'package:nimbostratus/utils.dart';

/// An extension of the [WriteBatch] with support for making changes and rolling back
/// the Nimbostratus in-memory cache.
class NimbostratusWriteBatch implements WriteBatch {
  final WriteBatch batch;

  // Whether the batch has been committed to the server.
  bool _isCommitted = false;
  // Whether the batch has uncommitted changes.
  bool _hasUncommittedChanges = false;

  final List<Future<void> Function()> listeners = [];

  NimbostratusWriteBatch({
    required this.batch,
  });

  void onCommit(Future<void> Function() callback) {
    listeners.add(callback);
  }

  @override
  Future<void> commit() async {
    if (!_hasUncommittedChanges || isCommitted) {
      return;
    }

    _isCommitted = true;
    _hasUncommittedChanges = false;
    await batch.commit();

    for (var callback in listeners) {
      await callback();
    }
  }

  bool get isCommitted {
    return _isCommitted;
  }

  @override
  void delete(DocumentReference document) => batch.delete(document);

  @override
  void set<T>(
    DocumentReference<T> document,
    T data, [
    SetOptions? options,
  ]) {
    if (!_hasUncommittedChanges) {
      _hasUncommittedChanges = true;
    }
    return batch.set(document, data, options);
  }

  @override
  void update(DocumentReference document, Map<String, dynamic> data) {
    if (!_hasUncommittedChanges) {
      _hasUncommittedChanges = true;
    }
    return batch.update(document, data);
  }
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
    NimbostratusFromFirestore<T>? fromFirestore,
  }) _update;

  final Future<NimbostratusDocumentSnapshot<T?>> Function<T>(
    DocumentReference<T> ref,
    T Function(T? currentValue) modifyFn, {
    WritePolicy writePolicy,
    ToFirestore<T>? toFirestore,
    NimbostratusWriteBatch? batch,
    bool isOptimistic,
    NimbostratusFromFirestore<T>? fromFirestore,
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
      NimbostratusFromFirestore<T>? fromFirestore,
    })
        update,
    required Future<NimbostratusDocumentSnapshot<T?>> Function<T>(
      DocumentReference<T> ref,
      T Function(T? currentValue) modifyFn, {
      WritePolicy writePolicy,
      ToFirestore<T>? toFirestore,
      NimbostratusWriteBatch? batch,
      bool isOptimistic,
      NimbostratusFromFirestore<T>? fromFirestore,
    })
        modify,
  })  : _documents = documents,
        _update = update,
        _modify = modify,
        _firestore = firestore,
        _batch = NimbostratusWriteBatch(batch: firestore.batch());

  final List<NimbostratusDocumentSnapshot> _batchOpimisticSnapshots = [];

  Future<NimbostratusDocumentSnapshot<T?>> modify<T>(
    DocumentReference<T> ref,
    T Function(T? currentValue) modifyFn, {
    WritePolicy writePolicy = WritePolicy.serverFirst,
    ToFirestore<T>? toFirestore,
    NimbostratusFromFirestore<T>? fromFirestore,
  }) async {
    final snap = await _modify<T>(
      ref,
      modifyFn,
      writePolicy: writePolicy,
      toFirestore: toFirestore,
      batch: _batch,
      fromFirestore: fromFirestore,

      /// A [WritePolicy.serverFirst] is not optimistic as it waits for the server response. Otherwise
      /// the batch update will be optimistic since both [WritePolicy.cacheOnly] and [WritePolicy.cacheAndServer]
      /// will optimistically write to the cache first.
      isOptimistic: writePolicy != WritePolicy.serverFirst,
    );

    // The returned snap may not be optimistic if for example, the optimistic update we're trying to perform is already the current value of the
    // document, in which case it won't re-emit any new value.
    if (snap.isOptimistic) {
      _batchOpimisticSnapshots.add(snap);
    }
    return snap;
  }

  Future<NimbostratusDocumentSnapshot<T?>> update<T>(
    DocumentReference<T> ref,
    T data, {
    WritePolicy writePolicy = WritePolicy.serverFirst,
    ToFirestore<T>? toFirestore,
    NimbostratusFromFirestore<T>? fromFirestore,
  }) async {
    final snap = await _update<T>(
      ref,
      data,
      writePolicy: writePolicy,
      toFirestore: toFirestore,
      batch: _batch,
      fromFirestore: fromFirestore,

      /// A [WritePolicy.serverFirst] is not optimistic as it waits for the server response. Otherwise
      /// the batch update will be optimistic since both [WritePolicy.cacheOnly] and [WritePolicy.cacheAndServer]
      /// will optimistically write to the cache first.
      isOptimistic: writePolicy != WritePolicy.serverFirst,
    );

    // The returned snap may not be optimistic if for example, the optimistic update we're trying to perform is already the current value of the
    // document, in which case it won't re-emit any new value.
    if (snap.isOptimistic) {
      _batchOpimisticSnapshots.add(snap);
    }
    return snap;
  }

  void commitOptimisticUpdates() {
    // After the batcher completes, all optimistically updated snapshots can be
    // marked as no longer optimistic.
    for (final snap in _batchOpimisticSnapshots) {
      snap.isOptimistic = false;
    }
    _batchOpimisticSnapshots.clear();
  }

  bool get isCommitted {
    return _batch.isCommitted;
  }

  Future<void> commit() async {
    await _batch.commit();
    commitOptimisticUpdates();
  }

  void rollback() {
    _batch = NimbostratusWriteBatch(batch: _firestore.batch());
    // Rollback all optimistic snaps in the reverse order they were applied.
    for (final optimisticSnap in _batchOpimisticSnapshots.reversed) {
      _documents[optimisticSnap.reference.path]!.rollback(optimisticSnap);
    }
  }
}
