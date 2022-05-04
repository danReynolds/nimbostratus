import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nimbostratus/nimbostratus.dart';
import 'package:restate/restate.dart';

/// An extension of the [WriteBatch] with support for making changes and rolling back
/// the Nimbostratus in-memory cache.
class NimbostratusWriteBatch implements WriteBatch {
  final WriteBatch batch;
  final List<Future<void> Function()> listeners = [];

  NimbostratusWriteBatch({
    required this.batch,
  });

  void addListener(Future<void> Function() callback) {
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
  final Map<String, StateBloc<NimbostratusDocumentSnapshot>> _documents;
  final FirebaseFirestore _firestore;
  late NimbostratusWriteBatch _batch;

  NimbostratusUpdateBatcher({
    required this.store,
    required FirebaseFirestore firestore,
    required Map<String, StateBloc<NimbostratusDocumentSnapshot>> documents,
  })  : _documents = documents,
        _firestore = firestore,
        _batch = NimbostratusWriteBatch(batch: firestore.batch());

  final Map<String, NimbostratusDocumentSnapshot<dynamic>> _batchChanges = {};

  Future<void> _recordRollback<T>(DocumentReference<T> ref) async {
    final snap = await Nimbostratus.instance
        .getDocument(ref, fetchPolicy: GetFetchPolicy.cacheOnly);
    final refPath = snap.reference.path;

    if (_batchChanges[refPath] == null) {
      _batchChanges[refPath] = snap;
    }
  }

  Future<NimbostratusDocumentSnapshot<T?>> modify<T>(
    DocumentReference<T> ref,
    T Function(T? currentValue) modifyFn, {
    WritePolicy writePolicy = WritePolicy.serverFirst,
    ToFirestore<T>? toFirestore,
  }) async {
    _recordRollback(ref);
    return store.modifyDocument<T>(
      ref,
      modifyFn,
      writePolicy: writePolicy,
      toFirestore: toFirestore,
      batch: _batch,
    );
  }

  Future<NimbostratusDocumentSnapshot<T?>> update<T>(
    DocumentReference<T> ref,
    T data, {
    WritePolicy writePolicy = WritePolicy.serverFirst,
    ToFirestore<T>? toFirestore,
  }) {
    _recordRollback(ref);
    return store.updateDocument<T>(
      ref,
      data,
      writePolicy: writePolicy,
      toFirestore: toFirestore,
      batch: _batch,
    );
  }

  Future<void> commit() async {
    return _batch.commit();
  }

  void rollback() {
    _batch = NimbostratusWriteBatch(batch: _firestore.batch());
    _batchChanges.forEach((key, value) {
      _documents[key]!.add(value);
    });
    _batchChanges.clear();
  }
}
