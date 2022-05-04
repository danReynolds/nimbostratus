import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore_with_metadata/fake_cloud_firestore_with_metadata.dart';
import 'package:fake_cloud_firestore_with_metadata/src/mock_collection_reference.dart';
import 'package:fake_cloud_firestore_with_metadata/src/mock_document_reference.dart';

import 'nimbostratus_mock_collection_reference.dart';
import 'nimbostratus_mock_document_reference.dart';

class FakeFirebaseFirestoreWithSource extends FakeFirebaseFirestore {
  @override
  DocumentReference<Map<String, dynamic>> doc(String path) {
    final doc = super.doc(path) as MockDocumentReference<Map<String, dynamic>>;
    return NimbostratusMockDocumentReference<Map<String, dynamic>>(
      this,
      doc.path,
      doc.id,
      doc.root,
      doc.docsData,
      doc.rootParent,
      doc.snapshotStreamControllerRoot,
      null,
    );
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    final collection = super.collection(path) as MockCollectionReference;

    return NimbostratusMockCollectionReference(
      this,
      collection.path,
      collection.root,
      collection.docsData,
      collection.snapshotStreamControllerRoot,
    );
  }
}
