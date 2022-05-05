library nimbostratus;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:nimbostratus/nimbostratus_document_snapshot.dart';
import 'package:nimbostratus/nimbostratus_optimistic_document_snapshot.dart';
import 'package:nimbostratus/nimbostratus_state_bloc.dart';
import 'package:nimbostratus/nimbostratus_update_batcher.dart';
import 'package:nimbostratus/policies.dart';
import 'package:nimbostratus/utils.dart';
import 'package:rxdart/rxdart.dart';

export './nimbostratus_document_snapshot.dart';
export './policies.dart';

Function deepEq = const DeepCollectionEquality().equals;

/// Nimbostratus is a reactive data-fetching and state management library built on top of Cloud Firestore.
class Nimbostratus {
  FirebaseFirestore? _firestore;

  Nimbostratus._();

  static final instance = Nimbostratus._();

  final Map<String, NimbostratusStateBloc> _documents = {};

  /// Set the internal Firebase store used to interact with the cloud_firestore APIs.
  /// Used in tests to mock out the store.
  void setStore(FirebaseFirestore store) {
    _firestore = store;
  }

  FirebaseFirestore get firestore {
    return _firestore ?? FirebaseFirestore.instance;
  }

  NimbostratusStateBloc<T?> _createDocBloc<T>({
    required T? value,
    required DocumentReference<T> reference,
    SnapshotMetadata? metadata,
  }) {
    final bloc = NimbostratusStateBloc<T?>();
    _documents[reference.path] = bloc;
    bloc.add(
      NimbostratusDocumentSnapshot<T>(
        reference: reference,
        metadata: metadata,
        value: value,
        stream: bloc.nonNullStream,
      ),
    );
    return bloc;
  }

  void _rollbackDocBloc<T>(NimbostratusOptimisticDocumentSnapshot<T?> snap) {
    final refPath = snap.reference.path;
    _documents[refPath]!.rollback(snap);
  }

  NimbostratusDocumentSnapshot<T?> _updateDocBloc<T>(
    DocumentSnapshot<T?> snap, {
    bool isOptimistic = false,
  }) {
    final refPath = snap.reference.path;

    if (_documents[refPath] == null) {
      return _createDocBloc(
        value: snap.data(),
        reference: snap.reference,
        metadata: snap.metadata,
      ).value!;
    }

    final docBloc = _documents[refPath]! as NimbostratusStateBloc<T?>;
    final previousSnap = docBloc.value;
    final snapData = snap.data();

    if (!deepEq(previousSnap?.data(), snapData)) {
      docBloc.add(
        isOptimistic
            ? NimbostratusOptimisticDocumentSnapshot(
                value: snapData,
                reference: snap.reference,
                metadata: snap.metadata,
                stream: docBloc.nonNullStream,
              )
            : NimbostratusDocumentSnapshot<T?>(
                value: snapData,
                reference: snap.reference,
                metadata: snap.metadata,
                stream: docBloc.nonNullStream,
              ),
      );
    }

    return docBloc.value!;
  }

  /// Clears all documents from the Nimbostratus in-memory cache.
  void clearDocuments() {
    _documents.clear();
  }

  /// Allows batch updating of documents using the Nimbostratus write policies on top of the
  /// Firestore [WriteBatch] APIs.
  /// Useful for performing optimistic cache updates that are rolled back if the batch update fails.
  /// Ex.
  /// ```dart
  // Nimbostratus.instance.batchUpdateDocuments((batch) {
  //   await batch.update<Map<String, dynamic>>(
  //     FirebaseFirestore.instance.collection('users').doc('alice'),
  //     {
  //       "name": "Alice 2",
  //     },
  //     writePolicy: WritePolicy.cacheAndServer,
  //   );

  //   await batcher.update<Map<String, dynamic>>(
  //     FirebaseFirestore.instance.collection('users').doc('bob'),
  //     {
  //       "name": "Bob 2",
  //     },
  //     writePolicy: WritePolicy.serverFirst,
  //   );

  //   await batch.commit();
  // });
  /// ```
  /// The first update with a [WritePolicy.cacheAndServer] policy will immediately update the in-memory cache and delay writing
  /// to the server until the batch is committed.
  /// The second update with the [WritePolicy.serverFirst] policy will defer writing to the cache until after the server response is
  /// committed.
  /// If the commit or any other API throws an exception in the [batchUpdateDocuments] function, then the cached changes are automatically rolled back to the
  /// values prior to when [batchUpdateDocuments] was called.
  Future<void> batchUpdateDocuments(
    Future<void> Function(NimbostratusUpdateBatcher batcher) updateCallback,
  ) async {
    final batcher = NimbostratusUpdateBatcher(
      store: this,
      firestore: firestore,
      documents: _documents,
    );

    try {
      await updateCallback(batcher);
    } catch (e) {
      batcher.rollback();
    }
  }

  /// Adds a Firestore document and updates the in-memory cache according to the specified [WritePolicy].
  Future<NimbostratusDocumentSnapshot<T?>> addDocument<T>(
    CollectionReference<T> collection,
    T data, {
    WritePolicy writePolicy = WritePolicy.serverFirst,
  }) async {
    return setDocument(
      collection.doc(),
      data,
      writePolicy: writePolicy,
    );
  }

  /// Sets a Firestore document and updates the in-memory cache according to the specified [WritePolicy].
  Future<NimbostratusDocumentSnapshot<T?>> setDocument<T>(
    DocumentReference<T> ref,
    T data, {
    WritePolicy writePolicy = WritePolicy.serverFirst,
    SetOptions? options,
    bool isOptimistic = false,
  }) async {
    switch (writePolicy) {
      case WritePolicy.serverFirst:
        await ref.set(data, options);
        final snap = await ref.get(const GetOptions(source: Source.cache));
        return _updateDocBloc(snap);
      case WritePolicy.cacheAndServer:
        final cachedSnap = await setDocument(
          ref,
          data,
          writePolicy: WritePolicy.cacheOnly,
          isOptimistic: true,
        ) as NimbostratusOptimisticDocumentSnapshot<T?>;
        try {
          final serverSnap = await setDocument(
            ref,
            data,
            writePolicy: WritePolicy.serverFirst,
          );
          return serverSnap;
        } catch (e) {
          // On a server error, rollback the optimistic update and rethrow.
          _rollbackDocBloc(cachedSnap);
          rethrow;
        }

      case WritePolicy.cacheOnly:
        try {
          final snap =
              await getDocument(ref, fetchPolicy: GetFetchPolicy.cacheOnly);
          return _updateDocBloc(snap.withValue(data));
          // An exception is thrown if the document doesn't yet exist in the cache.
        } on FirebaseException {
          return _createDocBloc(value: data, reference: ref).value!;
        }
    }
  }

  /// Updates a Firestore document and updates the in-memory cache according to the specified [WritePolicy].
  Future<NimbostratusDocumentSnapshot<T?>> updateDocument<T>(
    DocumentReference<T> ref,
    T data, {
    WritePolicy writePolicy = WritePolicy.serverFirst,
    ToFirestore<T>? toFirestore,
    NimbostratusWriteBatch? batch,
    bool isOptimistic = false,
  }) async {
    switch (writePolicy) {
      case WritePolicy.serverFirst:
        Map<String, dynamic> serializedData;

        if (data is Map<String, dynamic>) {
          serializedData = data;
        } else {
          assert(
            toFirestore != null,
            'A toFirestore function must be provivded for converted-type server updates.',
          );
          serializedData = toFirestore!(data, null);
        }
        if (batch != null) {
          batch.update(ref, serializedData);
          batch.onCommit(() async {
            final snap = await ref.get(const GetOptions(source: Source.cache));
            _updateDocBloc(snap);
          });
          return getDocument(ref, fetchPolicy: GetFetchPolicy.cacheOnly);
        } else {
          await ref.update(serializedData);
          final snap = await ref.get(const GetOptions(source: Source.cache));
          return _updateDocBloc(snap);
        }
      case WritePolicy.cacheAndServer:
        final cachedSnap = await updateDocument(
          ref,
          data,
          writePolicy: WritePolicy.cacheOnly,
          isOptimistic: true,
        ) as NimbostratusOptimisticDocumentSnapshot<T?>;
        try {
          final serverSnap = await updateDocument(
            ref,
            data,
            writePolicy: WritePolicy.serverFirst,
            toFirestore: toFirestore,
          );
          return serverSnap;
        } catch (e) {
          // If an error is encountered when trying to update the data on the server,
          // rollback the cache change and rethrow the error.
          _rollbackDocBloc(cachedSnap);
          rethrow;
        }
      case WritePolicy.cacheOnly:
        try {
          final snap =
              await getDocument(ref, fetchPolicy: GetFetchPolicy.cacheOnly);
          return _updateDocBloc(snap.withValue(data));
          // An exception is thrown if the document doesn't yet exist in the cache.
        } on FirebaseException {
          return _createDocBloc(value: data, reference: ref).value!;
        }
    }
  }

  /// Updates a Firestore document and updates the in-memory cache according to the specified [WritePolicy].
  /// Convenience wrapper around the [updateDocument] API that provides an update callback which is given
  /// the current document value.
  Future<NimbostratusDocumentSnapshot<T?>> modifyDocument<T>(
    DocumentReference<T> ref,
    T Function(T? currentValue) modifyFn, {
    WritePolicy writePolicy = WritePolicy.serverFirst,
    ToFirestore<T>? toFirestore,
    NimbostratusWriteBatch? batch,
  }) async {
    final snap =
        await getDocument<T>(ref, fetchPolicy: GetFetchPolicy.cacheOnly);

    return updateDocument<T>(
      ref,
      modifyFn(snap.value),
      toFirestore: toFirestore,
      writePolicy: writePolicy,
      batch: batch,
    );
  }

  // Deletes a Firestore document from the server and removes it from the in-memory cache.
  Future<void> deleteDocument<T>(
    DocumentReference<T> ref,
  ) async {
    final snap = await getDocument(ref, fetchPolicy: GetFetchPolicy.cacheOnly);
    await ref.delete();
    _updateDocBloc(snap.withValue(null));
  }

  /// Retrieves a Firestore document from the in-memory cache or server according to the specified [GetFetchPolicy].
  Future<NimbostratusDocumentSnapshot<T?>> getDocument<T>(
    DocumentReference<T> docRef, {
    GetFetchPolicy fetchPolicy = GetFetchPolicy.serverOnly,
  }) async {
    DocumentSnapshot<T?> snap;

    switch (fetchPolicy) {
      case GetFetchPolicy.cacheFirst:
      case GetFetchPolicy.cacheOnly:
        // First try to read the document from the NS cache, falling back to the Firestore cache.
        final docBloc = _documents[docRef.path];
        if (docBloc != null) {
          return docBloc.value as NimbostratusDocumentSnapshot<T?>;
        }

        try {
          // If the data was not available in the Firestore cache, it throws an error.
          // We then fallback to fetching the data from the server.
          snap = await docRef.get(const GetOptions(source: Source.cache));

          // The documentation indicates that an exception should be thrown if the document
          // does not exist in the cache.
          if (!snap.exists) {
            throw FirebaseException(plugin: 'missing_document');
          }
          // ignore: empty_catches.
        } on FirebaseException {
          if (fetchPolicy == GetFetchPolicy.cacheFirst) {
            return getDocument(
              docRef,
              fetchPolicy: GetFetchPolicy.serverOnly,
            );
          } else {
            return _createDocBloc(reference: docRef, value: null).value!;
          }
        }
        break;
      case GetFetchPolicy.serverOnly:
        try {
          snap = await docRef.get();
        } on FirebaseException {
          return _createDocBloc(value: null, reference: docRef).value!;
        }
    }

    return _updateDocBloc(snap);
  }

  /// Executes a Firestore [Query] for documents against the in-memory cache or server according to the specified [GetFetchPolicy].
  Future<List<NimbostratusDocumentSnapshot<T?>>> getDocuments<T>(
    Query<T> docQuery, {
    GetFetchPolicy fetchPolicy = GetFetchPolicy.serverOnly,
  }) async {
    QuerySnapshot<T>? snap;

    switch (fetchPolicy) {
      case GetFetchPolicy.cacheFirst:
      case GetFetchPolicy.cacheOnly:
        final snap = await docQuery.get(const GetOptions(source: Source.cache));
        final docs = snap.docs;

        // If there is no data in the cache to satisfy the get() call, QuerySnapshot.get() will return an empty
        /// QuerySnapshot with no documents. If this is a cache-first operation, we then go check the server
        /// to see if we can satisfy the query there.
        if (docs.isNotEmpty) {
          return docs.map<NimbostratusDocumentSnapshot<T?>>((doc) {
            final docBloc = _documents[doc.reference.path];

            // If the document is already in the NS cache, return the NS value. Otherwise
            // cache it to NS and fallback to the FS cache value.
            if (docBloc != null) {
              return docBloc.value as NimbostratusDocumentSnapshot<T>;
            }
            return _updateDocBloc(doc);
          }).toList();
        } else if (fetchPolicy == GetFetchPolicy.cacheFirst) {
          return getDocuments(
            docQuery,
            fetchPolicy: GetFetchPolicy.serverOnly,
          );
        }

        return [];
      case GetFetchPolicy.serverOnly:
        try {
          snap = await docQuery.get();
        } on FirebaseException {
          return [];
        }
        break;
    }

    return snap.docs.map((snap) => _updateDocBloc(snap)).toList();
  }

  /// Streams changes to a Firestore document from the in-memory cache or server according to the specified [StreamFetchPolicy].
  Stream<NimbostratusDocumentSnapshot<T?>> streamDocument<T>(
    DocumentReference<T> ref, {
    StreamFetchPolicy fetchPolicy = StreamFetchPolicy.serverFirst,
  }) {
    switch (fetchPolicy) {
      case StreamFetchPolicy.serverFirst:
      case StreamFetchPolicy.cacheFirst:
      case StreamFetchPolicy.cacheOnly:
        return Stream.fromFuture(
          getDocument(
            ref,
            fetchPolicy: convertStreamFetchPolicyToGetFetchPolicy(fetchPolicy),
          ),
        ).switchMap((_) {
          return _documents[ref.path]!
              .nonNullStream
              .cast<NimbostratusDocumentSnapshot<T?>>();
        });
      // A server and cache policy will read the data from both the server and cache simultaneously.
      // If a value is present in the cache first, it will deliver that data eagerly. It then listens
      // to subsequent cache and server updates.
      case StreamFetchPolicy.cacheAndServer:
        final serverStream = ref.serverSnapshots();
        return MergeStream([
          // While waiting for the server data, keep returning changes to the cached data.
          streamDocument(ref, fetchPolicy: StreamFetchPolicy.cacheOnly)
              .takeUntil(serverStream),
          serverStream.cast<DocumentSnapshot<T?>>().switchMap((snap) {
            return _updateDocBloc(snap).stream;
          }),
          // The cache vs server streams can emit a duplicate event transitioning between them. Distinct the results
          // to remove that duplicate event.
        ]).distinct();
      case StreamFetchPolicy.cacheAndServerOnce:
        final serverStream = ref.serverSnapshots().take(1);
        return MergeStream([
          streamDocument(ref, fetchPolicy: StreamFetchPolicy.cacheOnly)
              .takeUntil(serverStream),
          serverStream.cast<DocumentSnapshot<T?>>().switchMap((snap) {
            return _updateDocBloc(snap).stream;
          }),
        ]).distinct();
      case StreamFetchPolicy.serverOnly:
        return ref.serverSnapshots().switchMap((snap) {
          return Stream.value(_updateDocBloc(snap));
        });
    }
  }

  /// Streams changes to the specified Firestore [Query] for documents against the in-memory cache or server according to the specified [StreamFetchPolicy].
  Stream<List<NimbostratusDocumentSnapshot<T?>>> streamDocuments<T>(
    Query<T> docQuery, {
    StreamFetchPolicy fetchPolicy = StreamFetchPolicy.serverFirst,
  }) {
    switch (fetchPolicy) {
      case StreamFetchPolicy.serverFirst:
      case StreamFetchPolicy.cacheOnly:
      case StreamFetchPolicy.cacheFirst:
        return Stream.fromFuture(
          getDocuments(
            docQuery,
            fetchPolicy: convertStreamFetchPolicyToGetFetchPolicy(fetchPolicy),
          ),
        ).switchMap((snapshots) {
          if (snapshots.isEmpty) {
            return Stream.value([]);
          }

          final streams = snapshots.map((snapshot) => snapshot.stream).toList();
          return CombineLatestStream.list(streams);
        });
      case StreamFetchPolicy.cacheAndServer:
        final serverStream = docQuery.serverSnapshots();
        return MergeStream([
          streamDocuments(
            docQuery,
            fetchPolicy: StreamFetchPolicy.cacheOnly,
          ).takeUntil(serverStream),
          serverStream.switchMap((snap) {
            final docSnaps = snap.docs;

            if (docSnaps.isEmpty) {
              return Stream.value([]);
            }

            final streams = docSnaps
                .map((docSnap) => _updateDocBloc(docSnap).stream)
                .toList();
            return CombineLatestStream.list(streams);
          }),
        ]);
      case StreamFetchPolicy.cacheAndServerOnce:
        final serverStream = docQuery.serverSnapshots().take(1);
        return MergeStream([
          streamDocuments(
            docQuery,
            fetchPolicy: StreamFetchPolicy.cacheOnly,
          ).takeUntil(serverStream),
          serverStream.switchMap((snap) {
            final docSnaps = snap.docs;
            final streams = docSnaps
                .map((docSnap) => _updateDocBloc(docSnap).stream)
                .toList();
            return CombineLatestStream.list(streams);
          }),
        ]);
      case StreamFetchPolicy.serverOnly:
        return docQuery.serverSnapshots().switchMap((snap) {
          final docSnaps = snap.docs;

          final snaps = docSnaps.map((docSnap) {
            return _updateDocBloc(docSnap);
          }).toList();

          return Stream.value(snaps);
        });
    }
  }
}
