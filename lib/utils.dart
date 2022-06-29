import 'package:cloud_firestore/cloud_firestore.dart';

extension DocumentServerSnapshots<T> on DocumentReference<T> {
  Stream<DocumentSnapshot<T>> serverSnapshots() {
    // We need to include metadata changes in order to always receive the server change
    // since otherwise if the server data has not changed from the cached data, it would not emit the
    // server event as denoted by an `isFromCache` value of false.
    return snapshots(includeMetadataChanges: true)
        .where((snap) => !snap.metadata.isFromCache)
        .cast<DocumentSnapshot<T>>();
  }
}

extension QueryServerSnapshots<T> on Query<T> {
  Stream<QuerySnapshot<T>> serverSnapshots() {
    // We need to include metadata changes in order to always receive the server change
    // since otherwise if the server data has not changed from the cached data, it would not emit the
    // server event as denoted by an `isFromCache` value of false.
    return snapshots(includeMetadataChanges: true)
        .where((snap) => !snap.metadata.isFromCache);
  }
}

Map<String, dynamic> serializeData<T>({
  required T data,
  required ToFirestore<T>? toFirestore,
}) {
  if (data is Map<String, dynamic>) {
    return data;
  } else {
    assert(
      toFirestore != null,
      'A toFirestore function must be provivded for converted-type server updates.',
    );
    return toFirestore!(data, null);
  }
}

/// Attempt to replicate how the Cloud Firestore server updates document data in order to support client-side
/// cache changes.
/// TODO: The server merge logic is more advanced than this, figure out how replicate it fully on the client
/// for cache-first updates.
T? updateMerge<T>(
  T? existingData,
  T? newData,
) {
  if (newData == null) {
    return null;
  }

  if (existingData == null) {
    return newData;
  }

  if (existingData is Map<String, dynamic> && newData is Map<String, dynamic>) {
    return {
      ...existingData,
      ...newData,
    } as T;
  } else {
    return newData;
  }
}

/// Attempt to replicate how the Cloud Firestore server sets document data in order to support client-side
/// cache changes.
/// TODO: The server merge logic is more advanced than this, figure out how replicate it fully on the client
/// for cache-first updates.
T? setMerge<T>(T? existingData, T? newData, [SetOptions? options]) {
  final shouldMerge = options?.merge ?? false;

  if (newData == null) {
    return null;
  }

  if (newData is Map<String, dynamic> &&
      existingData is Map<String, dynamic> &&
      shouldMerge) {
    return {
      ...existingData,
      ...newData,
    } as T;
  }

  return newData;
}

typedef NimbostratusFromFirestore<T> = T? Function(T? existing, T? incoming);

/// A merge function for specifying how a server response from Firestore should be merged into
/// the cache given the existing and incoming data.
T? mergeFromFirestore<T>(
  T? existing,
  T? incoming,
  NimbostratusFromFirestore<T>? fromFirestore,
) {
  if (existing == null || fromFirestore == null) {
    return incoming;
  }

  return fromFirestore(
    existing,
    incoming,
  );
}
