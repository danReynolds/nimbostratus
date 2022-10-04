import 'package:cloud_firestore/cloud_firestore.dart';

extension DocumentServerSnapshots<T> on DocumentReference<T> {
  Stream<DocumentSnapshot<T>> serverSnapshots() {
    // According to the docs: https://firebase.google.com/docs/firestore/query-data/listen#events-metadata-changes
    // The sequence of events when performing client-side Firestore writes *with* metadata changes is as follows:
    // 1. An immediate event fired with the new data. The document has not yet been written to the backend so the "pending writes" flag is true and isFromCache is false
    // because this is an event destined to reflect the state of the server (a little unintuitive).
    // ```
    // SnapshotMetadata(isFromCache: false, hasPendingWrites: true)
    // ```
    // 2. The backend then notifies the client of the successful write when it's done. There is no change to the document data, but there is a metadata change because the "pending writes" flag is now false.
    // to indicate that the document was successfully written.
    // ```
    // SnapshotMetadata(isFromCache: false, hasPendingWrites: false)
    // ```
    //
    // Whereas the sequence when perform client-side Firestore writes *without* metadata changes is only the first event.
    //
    // To guarantee that a server snapshot as a result of a client-side write has been persisted to the server, the behavior you would want for a serverOnly policy
    // that uses serverSnapshots would therefore be to filter the snapshots with metadata change events once hasPendingWrites has become false:
    //
    // ```
    // snapshots(includeMetadataChanges: true).where((snap) => !snap.metadata.isFromCache && !snap.metadata.hasPendingWrites);
    // ```
    //
    // The downside to this approach is that it delays receiving the update for the write event and also leaves you vulnerable to inconsistencies
    // where a cache-only write (into Nimbostratus' in-memory cache) that immediately follows a server-bound write would be blown away by the delayed server response.
    // To mitigate these issues, at this time metadata changes are *not* included and client side writes will immediately emit server changes before the server
    // has indicated the write was successful.
    //
    // There is an argument to be made that this is incorrect but it is also the default behavior (includeMetadataChanges defaults to false) and it can be re-visited
    // in the future if related issues arise.
    return snapshots(includeMetadataChanges: false).cast<DocumentSnapshot<T>>();
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
