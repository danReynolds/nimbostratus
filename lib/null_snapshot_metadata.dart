import 'package:cloud_firestore/cloud_firestore.dart';

class NullSnapshotMetadata implements SnapshotMetadata {
  @override
  bool get isFromCache => true;
  @override
  bool get hasPendingWrites => false;
}
