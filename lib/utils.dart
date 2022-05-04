import 'package:cloud_firestore/cloud_firestore.dart';

extension DocumentServerSnapshots<T> on DocumentReference<T> {
  Stream<DocumentSnapshot<T>> serverSnapshots() {
    // We need to include metadata changes in order to always receive the server change
    // since otherwise if the server data has not changed from the cached data, it would not emit the
    // server event as denoted by an `isFromCache` value of false.
    return snapshots(includeMetadataChanges: true)
        .where((snap) => !snap.metadata.isFromCache);
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
