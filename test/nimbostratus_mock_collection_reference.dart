import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore_with_metadata/src/mock_collection_reference.dart';
import 'package:fake_cloud_firestore_with_metadata/src/mock_document_reference.dart';

import 'fake_firebase_firestore_with_source.dart';
import 'nimbostratus_mock_document_reference.dart';
import 'nimbostratus_test.dart';

// ignore: subtype_of_sealed_class
class NimbostratusMockCollectionReference<T>
    extends MockCollectionReference<T> {
  final FakeFirebaseFirestoreWithSource store;

  NimbostratusMockCollectionReference(
    this.store,
    String path,
    Map<String, dynamic> root,
    Map<String, dynamic> docsData,
    Map<String, dynamic> snapshotStreamControllerRoot,
  ) : super(
          store,
          path,
          root,
          docsData,
          snapshotStreamControllerRoot,
        );

  @override
  Future<QuerySnapshot<T>> get([GetOptions? options]) async {
    final source = options?.source ?? Source.server;

    final snap = await super.get(options);

    if (snap.docs.isEmpty) {
      return snap;
    }

    final sourceDocs = snap.docs.where((doc) {
      final docData = doc.data() as Map<String, dynamic>?;

      return docData != null && docData['sources'].contains(source.name);
    }).toList();

    return NimbostratusQuerySnapshot(
      docs: sourceDocs,
      metadata: snap.metadata,
    );
  }

  @override
  DocumentReference<T> doc([String? path]) {
    final doc = super.doc(path) as MockDocumentReference<Map<String, dynamic>>;
    return NimbostratusMockDocumentReference(
      store,
      doc.path,
      doc.id,
      doc.root,
      doc.docsData,
      doc.rootParent,
      doc.snapshotStreamControllerRoot,
      null,
    );
  }
}
