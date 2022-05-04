import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore_with_metadata/fake_cloud_firestore_with_metadata.dart';
import 'package:fake_cloud_firestore_with_metadata/src/converter.dart';
import 'package:fake_cloud_firestore_with_metadata/src/mock_document_reference.dart';
import 'package:nimbostratus/nimbostratus_document_snapshot.dart';

// ignore: subtype_of_sealed_class
class NimbostratusMockDocumentReference<T> extends MockDocumentReference<T> {
  NimbostratusMockDocumentReference(
    FakeFirebaseFirestore firestore,
    String path,
    String id,
    Map<String, dynamic> root,
    Map<String, dynamic> docsData,
    Map<String, dynamic> rootParent,
    Map<String, dynamic> snapshotStreamControllerRoot,
    Converter<T>? converter,
  ) : super(
          firestore,
          path,
          id,
          root,
          docsData,
          rootParent,
          snapshotStreamControllerRoot,
          converter,
        );

  @override
  Future<DocumentSnapshot<T>> get([GetOptions? options]) async {
    final snap = await super.get(options);
    final data = snap.data() as Map<String, dynamic>?;
    final source = options?.source ?? Source.server;

    if (data != null && !((data['sources'] as List).contains(source.name))) {
      // Missing cached data throws a FirebaseException in the real firestore service
      // so we simulate that here.
      if (source == Source.cache) {
        throw FirebaseException(plugin: 'test_env');
        // Missing server data returns a null snap.
      } else {
        return NimbostratusDocumentSnapshot(
          value: null,
          stream: const Stream.empty(),
          reference: this,
        );
      }
    }

    return snap;
  }

  @override
  Stream<DocumentSnapshot<T>> snapshots({bool includeMetadataChanges = false}) {
    return super.snapshots(includeMetadataChanges: false).where((snap) {
      final data = snap.data();

      if (data is Map<String, dynamic>) {
        return data['sources'].contains(Source.server.name);
      }

      return true;
    });
  }
}
