import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimbostratus/nimbostratus.dart';

import 'fake_firebase_firestore_with_source.dart';

FakeFirebaseFirestoreWithSource store = FakeFirebaseFirestoreWithSource();

class MockUserModel {
  final String name;

  MockUserModel({
    required this.name,
  });

  Map<String, dynamic> toJson() {
    return {
      "name": name,
    };
  }

  MockUserModel.fromJson(Map json) : name = json['name'];
}

class NimbostratusQuerySnapshot<T> extends QuerySnapshot<T> {
  @override
  final List<QueryDocumentSnapshot<T>> docs;
  @override
  final List<DocumentChange<T>> docChanges = [];
  @override
  final SnapshotMetadata metadata;
  @override
  final int size;

  NimbostratusQuerySnapshot({
    required this.docs,
    required this.metadata,
  }) : size = docs.length;
}

void main() async {
  setUp(() {
    store = FakeFirebaseFirestoreWithSource();
    Nimbostratus.instance.setStore(store);
    Nimbostratus.instance.clearDocuments();
  });

  group('getDocument', () {
    group('with a cache-only fetch policy', () {
      group('with a matching cached value', () {
        test('should return a document from the cache', () async {
          final docRef = store.doc('users/alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.cache.name],
          });

          final snap = await Nimbostratus.instance.getDocument(
            docRef,
            fetchPolicy: GetFetchPolicy.cacheFirst,
          );

          expect(
            snap.data(),
            equals(
              {
                "name": "Alice",
                'sources': [Source.cache.name],
              },
            ),
          );
        });
      });

      group('without a matching cached value', () {
        test('should return null', () async {
          final snap = await Nimbostratus.instance.getDocument(
            store.doc('users/alice'),
            fetchPolicy: GetFetchPolicy.cacheFirst,
          );
          expect(
            snap.data(),
            equals(null),
          );
        });
      });
    });

    group('with a server-only fetch policy', () {
      group('with a matching server value', () {
        test('should return the document', () async {
          final docRef = store.doc('users/alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.server.name],
          });

          final snap = await Nimbostratus.instance.getDocument(
            store.doc('users/alice'),
          );

          expect(snap.metadata.isFromCache, false);
          expect(
            snap.data(),
            equals(
              {
                "name": "Alice",
                'sources': [Source.server.name],
              },
            ),
          );
        });
      });

      group('without a matching server value', () {
        test('should return null', () async {
          final snap = await Nimbostratus.instance.getDocument(
            store.doc('users/alice'),
            fetchPolicy: GetFetchPolicy.serverOnly,
          );

          expect(
            snap.data(),
            equals(null),
          );
        });
      });
    });

    group('with a cache-first fetch policy', () {
      group('with a matching cache value', () {
        test('should return the document', () async {
          final docRef = store.doc('users/alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.cache.name],
          });

          final snap = await Nimbostratus.instance.getDocument(
            docRef,
            fetchPolicy: GetFetchPolicy.cacheFirst,
          );

          expect(
            snap.data(),
            equals(
              {
                "name": "Alice",
                'sources': [Source.cache.name],
              },
            ),
          );
        });
      });

      group('without a matching cache value', () {
        group('with a matching server value', () {
          test('should return the document', () async {
            final docRef = store.doc('users/alice');
            await docRef.set({
              'name': 'Alice',
              'sources': [Source.server.name],
            });

            final snap = await Nimbostratus.instance.getDocument(
              docRef,
              fetchPolicy: GetFetchPolicy.cacheFirst,
            );

            expect(
              snap.data(),
              equals(
                {
                  "name": "Alice",
                  'sources': [Source.server.name],
                },
              ),
            );
          });
        });

        group('without a matching server value', () {
          test('should return null', () async {
            final snap = await Nimbostratus.instance.getDocument(
              store.doc('users/alice'),
              fetchPolicy: GetFetchPolicy.cacheFirst,
            );

            expect(
              snap.data(),
              equals(null),
            );
          });
        });
      });
    });
  });

  group('getDocuments', () {
    group('with a cache-only fetch policy', () {
      group('with matching documents', () {
        test('should return the matching documents', () async {
          await store.doc('users/alice').set({
            'name': 'Alice',
            'age': 22,
            'sources': [Source.cache.name],
          });
          await store.doc('users/bob').set({
            'name': 'Bob',
            'age': 22,
            'sources': [Source.cache.name],
          });

          final querySnap = await Nimbostratus.instance.getDocuments(
            store.collection('users').where('age', isEqualTo: 22),
            fetchPolicy: GetFetchPolicy.cacheOnly,
          );

          expect(
            querySnap.map((docSnap) => docSnap.data()).toList(),
            equals([
              {
                'name': 'Alice',
                'age': 22,
                'sources': [Source.cache.name],
              },
              {
                'name': 'Bob',
                'age': 22,
                'sources': [Source.cache.name],
              }
            ]),
          );
        });
      });

      group('without matching documents', () {
        test('should return an empty list', () async {
          final snap = await Nimbostratus.instance.getDocuments(
            store.collection('users').where('age', isEqualTo: 22),
            fetchPolicy: GetFetchPolicy.cacheOnly,
          );

          expect(
            snap,
            equals([]),
          );
        });
      });
    });

    group('with a cache-first fetch policy', () {
      group('with matching cached documents', () {
        test('should return the matching documents', () async {
          await store.doc('users/alice').set({
            'name': 'Alice',
            'age': 22,
            'sources': [Source.cache.name],
          });
          await store.doc('users/bob').set({
            'name': 'Bob',
            'age': 22,
            'sources': [Source.cache.name],
          });

          final querySnap = await Nimbostratus.instance.getDocuments(
            store.collection('users').where('age', isEqualTo: 22),
            fetchPolicy: GetFetchPolicy.cacheFirst,
          );

          expect(
            querySnap.map((docSnap) => docSnap.data()).toList(),
            equals([
              {
                'name': 'Alice',
                'age': 22,
                'sources': [Source.cache.name],
              },
              {
                'name': 'Bob',
                'age': 22,
                'sources': [Source.cache.name],
              }
            ]),
          );
        });
      });

      group('without matching cached documents', () {
        group('with matching server documents', () {
          test('should return the matching server documents', () async {
            await store.doc('users/alice').set({
              'name': 'Alice',
              'age': 22,
              'sources': [Source.server.name],
            });
            await store.doc('users/bob').set({
              'name': 'Bob',
              'age': 22,
              'sources': [Source.server.name],
            });

            final querySnap = await Nimbostratus.instance.getDocuments(
              store.collection('users').where('age', isEqualTo: 22),
              fetchPolicy: GetFetchPolicy.cacheFirst,
            );

            expect(
              querySnap.map((snap) => snap.data()),
              equals([
                {
                  'name': 'Alice',
                  'age': 22,
                  'sources': [Source.server.name],
                },
                {
                  'name': 'Bob',
                  'age': 22,
                  'sources': [Source.server.name],
                }
              ]),
            );
          });
        });

        group('without matching server documents', () {
          test('should return an empty list', () async {
            final querySnap = await Nimbostratus.instance.getDocuments(
              store.collection('users').where('age', isEqualTo: 22),
              fetchPolicy: GetFetchPolicy.serverOnly,
            );

            expect(
              querySnap.map((snap) => snap.data()),
              equals([]),
            );
          });
        });
      });
    });

    group('with a server-only fetch policy', () {
      group("with matching server documents", () {
        test('should return the matching server documents', () async {
          await store.doc('users/alice').set({
            'name': 'Alice',
            'age': 22,
            'sources': [Source.server.name],
          });
          await store.doc('users/bob').set({
            'name': 'Bob',
            'age': 22,
            'sources': [Source.server.name],
          });

          final querySnap = await Nimbostratus.instance.getDocuments(
              store.collection('users').where('age', isEqualTo: 22),
              fetchPolicy: GetFetchPolicy.serverOnly);

          expect(
            querySnap.map((snap) => snap.data()),
            equals(
              [
                {
                  'name': 'Alice',
                  'age': 22,
                  'sources': [Source.server.name],
                },
                {
                  'name': 'Bob',
                  'age': 22,
                  'sources': [Source.server.name],
                }
              ],
            ),
          );
        });
      });

      group('without matching server documents', () {
        test('should return an empty list', () async {
          final querySnap = await Nimbostratus.instance.getDocuments(
            store.collection('users').where('age', isEqualTo: 22),
            fetchPolicy: GetFetchPolicy.serverOnly,
          );

          expect(
            querySnap.map((snap) => snap.data()),
            equals([]),
          );
        });
      });
    });
  });

  group('streamDocument', () {
    group('with a cache-first fetch policy', () {
      const fetchPolicy = StreamFetchPolicy.cacheFirst;

      group('with initial cached data', () {
        test('should stream the cached data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.cache.name],
          });

          final stream = Nimbostratus.instance
              .streamDocument(
                docRef,
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((snap) => snap.data()),
            emitsInOrder([
              {
                "name": 'Alice',
                "sources": [Source.cache.name],
              },
            ]),
          );
        });
      });

      group('with later cached data', () {
        test('should later stream the cached data', () async {
          final docRef = store.collection('users').doc('alice');
          final stream = Nimbostratus.instance
              .streamDocument(
                docRef,
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((snap) => snap.data()),
            emitsInOrder([
              null,
              {
                "name": 'Alice',
                "sources": [Source.cache.name],
              },
            ]),
          );

          await stream.first;
          await Nimbostratus.instance.setDocument(
            docRef,
            {
              "name": 'Alice',
              "sources": [Source.cache.name],
            },
            writePolicy: WritePolicy.cacheOnly,
          );
        });
      });

      group('with initial server data', () {
        test('should stream the server data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            "name": 'Alice',
            'sources': [Source.server.name],
          });

          final stream = Nimbostratus.instance.streamDocument(
            docRef,
            fetchPolicy: fetchPolicy,
          );

          expectLater(
            stream.map((snap) => snap.data()),
            emitsInOrder([
              {
                "name": 'Alice',
                "sources": [Source.server.name],
              },
            ]),
          );
        });
      });

      group('with later server data', () {
        test('should later stream the document', () async {
          final docRef = store.collection('users').doc('alice');

          final stream = Nimbostratus.instance
              .streamDocument(
                docRef,
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((snap) => snap.data()),
            emitsInOrder([
              null,
              {
                "name": 'Alice',
                "sources": [Source.server.name, Source.cache.name],
              },
            ]),
          );

          await stream.first;

          await Nimbostratus.instance.setDocument(docRef, {
            "name": 'Alice',
            // We write both sources here since in reality, writing to the server will also
            // save the value in the cache. Tests that need to simulate this actual behavior
            // declare that both sources are present when writing the server.
            "sources": [Source.server.name, Source.cache.name],
          });
        });
      });
    });

    group('with a cache-only fetch policy', () {
      const fetchPolicy = StreamFetchPolicy.cacheOnly;

      group('with initial cached data', () {
        test('should stream the cached data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.cache.name],
          });

          final stream = Nimbostratus.instance
              .streamDocument(
                docRef,
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((snap) => snap.data()),
            emitsInOrder([
              {
                "name": 'Alice',
                "sources": [Source.cache.name],
              },
            ]),
          );
        });
      });

      group('with later cached data', () {
        test('should later stream the cached data', () async {
          final docRef = store.collection('users').doc('alice');
          final stream = Nimbostratus.instance
              .streamDocument(
                docRef,
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((snap) => snap.data()),
            emitsInOrder([
              null,
              {
                "name": 'Alice',
                "sources": [Source.cache.name],
              },
            ]),
          );

          await stream.first;
          await Nimbostratus.instance.setDocument(
            docRef,
            {
              "name": 'Alice',
              "sources": [Source.cache.name],
            },
            writePolicy: WritePolicy.cacheOnly,
          );
        });
      });
    });

    group('with a server-only fetch policy', () {
      const fetchPolicy = StreamFetchPolicy.serverOnly;

      group('with initial server data', () {
        test('should stream the server data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.server.name],
          });

          final stream = Nimbostratus.instance
              .streamDocument(
                docRef,
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((snap) => snap.data()),
            emitsInOrder([
              {
                "name": 'Alice',
                "sources": [Source.server.name],
              },
            ]),
          );
        });
      });

      group('with later server data', () {
        test('should later stream the server data', () async {
          final docRef = store.collection('users').doc('alice');
          final stream = Nimbostratus.instance
              .streamDocument(
                docRef,
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((snap) => snap.data()),
            emitsInOrder([
              null,
              {
                "name": 'Bob',
                "sources": [Source.server.name, Source.cache.name],
              },
            ]),
          );

          await stream.first;
          await Nimbostratus.instance.setDocument(
            docRef,
            {
              "name": 'Bob',
              "sources": [Source.server.name, Source.cache.name],
            },
            writePolicy: WritePolicy.serverFirst,
          );
        });
      });

      group('with initial cached data', () {
        test('should not stream the cached data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.cache.name],
          });

          final stream = Nimbostratus.instance
              .streamDocument(
                docRef,
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((snap) => snap.data()),
            emitsInOrder([
              {
                "name": 'Bob',
                "sources": [Source.cache.name, Source.server.name],
              },
            ]),
          );

          // In order to test not getting cached data, we later write server data and show
          // that it never emitted the previous cached data.
          await Nimbostratus.instance.setDocument(
            docRef,
            {
              "name": 'Bob',
              "sources": [Source.cache.name, Source.server.name],
            },
            writePolicy: WritePolicy.serverFirst,
          );
        });
      });

      group('with later cached data', () {
        test('should not later stream the cached data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.server.name],
          });

          final stream = Nimbostratus.instance
              .streamDocument(
                docRef,
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((snap) => snap.data()),
            emitsInOrder([
              {
                'name': 'Alice',
                'sources': [Source.server.name],
              },
            ]),
          );

          await stream.first;

          await Nimbostratus.instance.setDocument(
            docRef,
            {
              "name": 'Bob',
              "sources": [Source.cache.name],
            },
            writePolicy: WritePolicy.cacheOnly,
          );
        });
      });
    });

    group('with a server-first fetch policy', () {
      const fetchPolicy = StreamFetchPolicy.serverFirst;

      group('with initial cached data', () {
        test('should not stream the cached data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.cache.name],
          });

          final stream = Nimbostratus.instance
              .streamDocument(
                docRef,
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((snap) => snap.data()),
            emitsInOrder([
              null,
            ]),
          );
        });
      });

      group('with later cached data', () {
        test('should later stream the cached data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.server.name],
          });

          final stream = Nimbostratus.instance
              .streamDocument(
                docRef,
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((snap) => snap.data()),
            emitsInOrder([
              {
                'name': 'Alice',
                'sources': [Source.server.name],
              },
              {
                'name': 'Bob',
                'sources': [Source.cache.name],
              },
            ]),
          );

          await stream.first;

          await Nimbostratus.instance.setDocument(
            docRef,
            {
              'name': 'Bob',
              'sources': [Source.cache.name],
            },
            writePolicy: WritePolicy.cacheOnly,
          );
        });
      });

      group('with initial server data', () {
        test('should stream the server data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.server.name],
          });

          final stream = Nimbostratus.instance
              .streamDocument(
                docRef,
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((snap) => snap.data()),
            emitsInOrder([
              {
                'name': 'Alice',
                'sources': [Source.server.name],
              },
            ]),
          );
        });
      });

      group('with later server data', () {
        test('should not later stream the server data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.server.name],
          });

          final stream = Nimbostratus.instance
              .streamDocument(
                docRef,
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((snap) => snap.data()),
            emitsInOrder([
              {
                'name': 'Alice',
                'sources': [Source.server.name],
              },
              {
                'name': 'Bob',
                'sources': [Source.cache.name, Source.server.name],
              },
            ]),
          );

          await stream.first;

          await Nimbostratus.instance.setDocument(docRef, {
            'name': 'Bob',
            'sources': [Source.cache.name, Source.server.name],
          });
        });
      });
    });

    group('with a cache-and-server fetch policy', () {
      const fetchPolicy = StreamFetchPolicy.cacheAndServer;

      group('with initial cached data', () {
        test('should stream the cached data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.cache.name],
          });

          final stream = Nimbostratus.instance
              .streamDocument(
                docRef,
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((snap) => snap.data()),
            emitsInOrder([
              {
                'name': 'Alice',
                'sources': [Source.cache.name],
              },
            ]),
          );
        });
      });

      group('with later cached data', () {
        test('should later stream the cached data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.cache.name],
          });

          final stream = Nimbostratus.instance
              .streamDocument(
                docRef,
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((snap) => snap.data()),
            emitsInOrder([
              {
                'name': 'Alice',
                'sources': [Source.cache.name],
              },
              {
                'name': 'Bob',
                'sources': [Source.cache.name],
              }
            ]),
          );

          await stream.first;

          await Nimbostratus.instance.setDocument(
            docRef,
            {
              'name': 'Bob',
              'sources': [Source.cache.name],
            },
            writePolicy: WritePolicy.cacheOnly,
          );
        });
      });

      group('with initial server data', () {
        test('should stream the server data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.server.name, Source.cache.name],
          });

          final stream = Nimbostratus.instance
              .streamDocument(
                docRef,
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((snap) => snap.data()),
            emitsInOrder([
              {
                'name': 'Alice',
                'sources': [Source.server.name, Source.cache.name],
              },
            ]),
          );
        });
      });

      group('with later server data', () {
        test('should later stream the server data', () async {
          final docRef = store.collection('users').doc('alice');

          final stream = Nimbostratus.instance
              .streamDocument(
                docRef,
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((snap) => snap.data()),
            emitsInOrder([
              null,
              {
                'name': 'Bob',
                'sources': [Source.server.name],
              },
              {
                'name': 'Charlie',
                'sources': [Source.server.name],
              }
            ]),
          );

          await stream.first;

          await docRef.set({
            'name': 'Bob',
            'sources': [Source.server.name],
          });
          await docRef.set({
            'name': 'Charlie',
            'sources': [Source.server.name],
          });
        });
      });
    });

    group('with a cache-and-server-once fetch policy', () {
      const fetchPolicy = StreamFetchPolicy.cacheAndServerOnce;

      group('with initial cached data', () {
        test('should stream the cached data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.server.name, Source.cache.name],
          });

          final stream = Nimbostratus.instance
              .streamDocument(
                docRef,
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((snap) => snap.data()),
            emitsInOrder([
              {
                'name': 'Alice',
                'sources': [Source.server.name, Source.cache.name],
              },
            ]),
          );
        });
      });

      group('with later cached data', () {
        test('should later stream the cached data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.server.name, Source.cache.name],
          });

          final stream = Nimbostratus.instance
              .streamDocument(
                docRef,
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((snap) => snap.data()),
            emitsInOrder([
              {
                'name': 'Alice',
                'sources': [Source.server.name, Source.cache.name],
              },
              {
                'name': 'Bob',
                'sources': [Source.cache.name],
              }
            ]),
          );

          await stream.first;

          await Nimbostratus.instance.setDocument(
            docRef,
            {
              'name': 'Bob',
              'sources': [Source.cache.name],
            },
            writePolicy: WritePolicy.cacheOnly,
          );
        });
      });

      group('with initial server data', () {
        test('should stream the server data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.server.name, Source.cache.name],
          });

          final stream = Nimbostratus.instance
              .streamDocument(
                docRef,
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((snap) => snap.data()),
            emitsInOrder([
              {
                'name': 'Alice',
                'sources': [Source.server.name, Source.cache.name],
              },
            ]),
          );
        });
      });

      group('with later server data', () {
        test('should later stream the server data', () async {
          final docRef = store.collection('users').doc('alice');

          final stream = Nimbostratus.instance
              .streamDocument(
                docRef,
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((snap) => snap.data()),
            emitsInOrder([
              null,
              {
                'name': 'Charlie',
                'sources': [Source.cache.name],
              }
            ]),
          );

          await stream.first;

          // The update to Bob is never emitted because the cache-and-server-once policy first emitted null from the server
          // and it won't listen to the subsequent Bob server update.
          await docRef.set({
            'name': 'Bob',
            'sources': [Source.server.name],
          });

          // It will listen to the Charlie update though because that involves a cache change.
          await Nimbostratus.instance.setDocument(
            docRef,
            {
              'name': 'Charlie',
              'sources': [Source.cache.name],
            },
            writePolicy: WritePolicy.cacheOnly,
          );
        });
      });
    });

    group('with a cache-and-server-first fetch policy', () {
      const fetchPolicy = StreamFetchPolicy.cacheAndServerFirst;

      group('with cache-then-server data', () {
        test('should only emit the later server data', () async {
          final docRef = store.collection('users').doc('alice');
          final stream = Nimbostratus.instance
              .streamDocument(
                docRef,
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((snap) => snap.data()),
            emitsInOrder([
              null,
              {
                'name': 'Alice',
                'sources': [Source.cache.name, Source.server.name],
              },
            ]),
          );

          await stream.first;

          await docRef.set({
            'name': 'Alice',
            'sources': [Source.cache.name, Source.server.name],
          });
        });
      });

      group('with server-then-cache data', () {
        test('should emit the server data and then the cache data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.cache.name, Source.server.name],
          });

          final stream = Nimbostratus.instance
              .streamDocument(
                docRef,
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.distinct().map((snap) => snap.data()),
            emitsInOrder([
              {
                'name': 'Alice',
                'sources': [Source.cache.name, Source.server.name],
              },
              {
                'name': 'Bob',
                'sources': [Source.cache.name],
              },
            ]),
          );

          await stream.first;

          await Nimbostratus.instance.setDocument(
            docRef,
            {
              'name': 'Bob',
              'sources': [Source.cache.name],
            },
            writePolicy: WritePolicy.cacheOnly,
          );
        });
      });

      group('with server-then-server data', () {
        test('should emit all server data', () async {
          final docRef = store.collection('users').doc('alice');

          await docRef.set({
            'name': 'Alice',
            'sources': [Source.cache.name, Source.server.name],
          });

          final stream = Nimbostratus.instance
              .streamDocument(
                docRef,
                fetchPolicy: StreamFetchPolicy.cacheAndServerFirst,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((snap) => snap.data()),
            emitsInOrder([
              {
                'name': 'Alice',
                'sources': [Source.cache.name, Source.server.name],
              },
              {
                'name': 'Bob',
                'sources': [Source.cache.name, Source.server.name],
              },
            ]),
          );

          await stream.first;

          await docRef.set({
            'name': 'Bob',
            'sources': [Source.cache.name, Source.server.name],
          });
        });
      });
    });
  });

  group('streamDocuments', () {
    group('with a cache-first fetch policy', () {
      const fetchPolicy = StreamFetchPolicy.cacheFirst;

      group('with initial cached data', () {
        test('should stream the cached data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.cache.name],
          });

          final stream = Nimbostratus.instance
              .streamDocuments(
                store.collection('users'),
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((docs) => docs.map((doc) => doc.data()).toList()),
            emitsInOrder([
              [
                {
                  "name": 'Alice',
                  "sources": [Source.cache.name],
                }
              ],
            ]),
          );
        });
      });

      group('with later cached data', () {
        test('should later stream the cached data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.cache.name],
          });

          final stream = Nimbostratus.instance
              .streamDocuments(
                store.collection('users'),
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((docs) => docs.map((doc) => doc.data()).toList()),
            emitsInOrder([
              [
                {
                  "name": 'Alice',
                  "sources": [Source.cache.name],
                }
              ],
              [
                {
                  'name': 'Bob',
                  'sources': [Source.cache.name],
                },
              ]
            ]),
          );

          await stream.first;

          await Nimbostratus.instance.setDocument(
            docRef,
            {
              'name': 'Bob',
              'sources': [Source.cache.name],
            },
            writePolicy: WritePolicy.cacheOnly,
          );
        });
      });

      group('with initial server data', () {
        test('should stream the server data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.server.name],
          });

          final stream = Nimbostratus.instance
              .streamDocuments(
                store.collection('users'),
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((docs) => docs.map((doc) => doc.data()).toList()),
            emitsInOrder([
              [
                {
                  "name": 'Alice',
                  "sources": [Source.server.name],
                }
              ],
            ]),
          );
        });
      });

      group('with later server data', () {
        test('should later stream the server data', () async {
          final collectionRef = store.collection('users');

          await collectionRef.doc('alice').set({
            'name': 'Alice',
            'sources': [Source.server.name],
          });

          final stream = Nimbostratus.instance
              .streamDocuments(
                collectionRef,
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((docs) => docs.map((doc) => doc.data()).toList()),
            emitsInOrder([
              [
                {
                  "name": 'Alice',
                  "sources": [Source.server.name],
                },
              ],
              [
                {
                  "name": 'Alice 2',
                  "sources": [Source.cache.name],
                },
              ],
            ]),
          );

          await stream.first;

          // This event should be skipped since a cache-first fetch policy will
          // not receive subsequent server updates.
          await Nimbostratus.instance.setDocument(collectionRef.doc('bob'), {
            'name': 'Bob',
            'sources': [Source.cache.name, Source.server.name],
          });

          await Nimbostratus.instance.setDocument(
            collectionRef.doc('alice'),
            {
              'name': 'Alice 2',
              'sources': [Source.cache.name],
            },
            writePolicy: WritePolicy.cacheOnly,
          );
        });
      });
    });

    group('with a cache-only fetch policy', () {
      const fetchPolicy = StreamFetchPolicy.cacheOnly;

      group('with initial cached data', () {
        test('should stream the cached data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.cache.name],
          });

          final stream = Nimbostratus.instance
              .streamDocuments(
                store.collection('users'),
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((docs) => docs.map((doc) => doc.data()).toList()),
            emitsInOrder([
              [
                {
                  "name": 'Alice',
                  "sources": [Source.cache.name],
                }
              ],
            ]),
          );
        });
      });

      group('with later cached data', () {
        test('should later stream the cached data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.cache.name],
          });

          final stream = Nimbostratus.instance
              .streamDocuments(
                store.collection('users'),
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((docs) => docs.map((doc) => doc.data()).toList()),
            emitsInOrder([
              [
                {
                  "name": 'Alice',
                  "sources": [Source.cache.name],
                }
              ],
              [
                {
                  "name": 'Alice 2',
                  "sources": [Source.cache.name],
                }
              ],
            ]),
          );

          await stream.first;

          await Nimbostratus.instance.setDocument(
            docRef,
            {
              'name': 'Alice 2',
              'sources': [Source.cache.name],
            },
            writePolicy: WritePolicy.cacheOnly,
          );
        });
      });

      group('with initial server data', () {
        test('should not stream the server data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.server.name],
          });

          final stream = Nimbostratus.instance
              .streamDocuments(
                store.collection('users'),
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((docs) => docs.map((doc) => doc.data()).toList()),
            emitsInOrder([
              [],
            ]),
          );
        });
      });

      group('with later server data', () {
        test('should not later stream the server data', () async {
          final collectionRef = store.collection('users');
          final docRef = collectionRef.doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.cache.name],
          });

          final stream = Nimbostratus.instance
              .streamDocuments(
                collectionRef,
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((docs) => docs.map((doc) => doc.data()).toList()),
            emitsInOrder([
              [
                {
                  'name': 'Alice',
                  'sources': [Source.cache.name],
                }
              ],
              [
                {
                  'name': 'Alice 2',
                  'sources': [Source.cache.name],
                }
              ],
            ]),
          );

          await stream.first;

          // This event should be skipped since a cache-only fetch policy will
          // not receive server updates.
          await Nimbostratus.instance.setDocument(collectionRef.doc('bob'), {
            'name': 'Bob',
            'sources': [Source.cache.name, Source.server.name],
          });

          await Nimbostratus.instance.setDocument(
            collectionRef.doc('alice'),
            {
              'name': 'Alice 2',
              'sources': [Source.cache.name],
            },
            writePolicy: WritePolicy.cacheOnly,
          );
        });
      });
    });

    group('with a server-only fetch policy', () {
      const fetchPolicy = StreamFetchPolicy.serverOnly;

      group('with initial cached data', () {
        test('should not stream the cached data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.cache.name],
          });

          final stream = Nimbostratus.instance
              .streamDocuments(
                store.collection('users'),
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((docs) => docs.map((doc) => doc.data()).toList()),
            emitsInOrder([
              [],
            ]),
          );
        });
      });

      group('with later cached data', () {
        test('should not later stream the cached data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.server.name, Source.cache.name],
          });

          final stream = Nimbostratus.instance
              .streamDocuments(
                store.collection('users'),
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((docs) => docs.map((doc) => doc.data()).toList()),
            emitsInOrder([
              [
                {
                  'name': 'Alice',
                  'sources': [Source.server.name, Source.cache.name],
                }
              ],
            ]),
          );

          await stream.first;

          await Nimbostratus.instance.setDocument(
            docRef,
            {
              'name': 'Alice 2',
              'sources': [Source.cache.name],
            },
            writePolicy: WritePolicy.cacheOnly,
          );
        });
      });

      group('with initial server data', () {
        test('should stream the server data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.server.name],
          });

          final stream = Nimbostratus.instance
              .streamDocuments(
                store.collection('users'),
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((docs) => docs.map((doc) => doc.data()).toList()),
            emitsInOrder([
              [
                {
                  'name': 'Alice',
                  'sources': [Source.server.name],
                }
              ],
            ]),
          );
        });
      });

      group('with later server data', () {
        test('should later stream the server data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.server.name],
          });

          final stream = Nimbostratus.instance
              .streamDocuments(
                store.collection('users'),
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((docs) => docs.map((doc) => doc.data()).toList()),
            emitsInOrder([
              [
                {
                  'name': 'Alice',
                  'sources': [Source.server.name],
                }
              ],
              [
                {
                  'name': 'Alice 2',
                  'sources': [Source.server.name],
                }
              ],
              [
                {
                  'name': 'Alice 2',
                  'sources': [Source.server.name],
                },
                {
                  'name': 'Bob',
                  'sources': [Source.server.name],
                }
              ],
            ]),
          );

          await stream.first;

          await docRef.set({
            'name': 'Alice 2',
            'sources': [Source.server.name],
          });

          await store.collection('users').doc('bob').set({
            'name': 'Bob',
            'sources': [Source.server.name],
          });
        });
      });
    });

    group('with a server-first fetch policy', () {
      const fetchPolicy = StreamFetchPolicy.serverFirst;

      group('with initial cached data', () {
        test('should not stream the cached data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.cache.name],
          });

          final stream = Nimbostratus.instance
              .streamDocuments(
                store.collection('users'),
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((docs) => docs.map((doc) => doc.data()).toList()),
            emitsInOrder([
              [],
            ]),
          );
        });
      });

      group('with later cached data', () {
        test('should later stream the cached data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.server.name],
          });

          final stream = Nimbostratus.instance
              .streamDocuments(
                store.collection('users'),
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((docs) => docs.map((doc) => doc.data()).toList()),
            emitsInOrder([
              [
                {
                  'name': 'Alice',
                  'sources': [Source.server.name],
                },
              ],
              [
                {
                  'name': 'Alice 2',
                  'sources': [Source.cache.name],
                },
              ]
            ]),
          );

          await stream.first;

          await Nimbostratus.instance.setDocument(
            docRef,
            {
              'name': 'Alice 2',
              'sources': [Source.cache.name],
            },
            writePolicy: WritePolicy.cacheOnly,
          );
        });
      });

      group('with initial server data', () {
        test('should stream the server data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.server.name],
          });

          final stream = Nimbostratus.instance
              .streamDocuments(
                store.collection('users'),
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((docs) => docs.map((doc) => doc.data()).toList()),
            emitsInOrder([
              [
                {
                  'name': 'Alice',
                  'sources': [Source.server.name],
                }
              ],
            ]),
          );
        });
      });

      group('with later server data', () {
        test('should not later stream the server data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.server.name],
          });

          final stream = Nimbostratus.instance
              .streamDocuments(
                store.collection('users'),
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((docs) => docs.map((doc) => doc.data()).toList()),
            emitsInOrder([
              [
                {
                  'name': 'Alice',
                  'sources': [Source.server.name],
                },
              ],
              [
                {
                  'name': 'Alice 2',
                  'sources': [Source.cache.name],
                },
              ]
            ]),
          );

          await stream.first;

          // This should not trigger an update because it only listens to one server event.
          await docRef.set({
            'name': 'Bob',
            'sources': [Source.server.name],
          });

          await Nimbostratus.instance.setDocument(
            docRef,
            {
              'name': 'Alice 2',
              'sources': [Source.cache.name],
            },
            writePolicy: WritePolicy.cacheOnly,
          );
        });
      });
    });

    group('with a cache-and-server fetch policy', () {
      const fetchPolicy = StreamFetchPolicy.cacheAndServer;

      group('with initial cached data', () {
        test('should stream the cached data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.cache.name, Source.server.name],
          });

          final stream = Nimbostratus.instance
              .streamDocuments(
                store.collection('users'),
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((docs) => docs.map((doc) => doc.data()).toList()),
            emitsInOrder([
              [
                {
                  'name': 'Alice',
                  'sources': [Source.cache.name, Source.server.name],
                }
              ],
            ]),
          );
        });
      });

      group('with later cached data', () {
        test('should later stream the cached data', () async {
          final docRef = store.collection('users').doc('alice');

          await docRef.set({
            'name': 'Alice',
            'sources': [Source.server.name],
          });

          final stream = Nimbostratus.instance
              .streamDocuments(
                store.collection('users'),
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((docs) => docs.map((doc) => doc.data()).toList()),
            emitsInOrder([
              [
                {
                  'name': 'Alice',
                  'sources': [Source.server.name],
                },
              ],
              [
                {
                  'name': 'Alice 2',
                  'sources': [Source.cache.name],
                },
              ]
            ]),
          );

          await stream.first;

          await Nimbostratus.instance.setDocument(
            docRef,
            {
              'name': 'Alice 2',
              'sources': [Source.cache.name],
            },
            writePolicy: WritePolicy.cacheOnly,
          );
        });
      });

      group('with initial server data', () {
        test('should stream the cached data', () async {
          final docRef = store.collection('users').doc('alice');

          await docRef.set({
            'name': 'Alice',
            'sources': [Source.server.name],
          });

          final stream = Nimbostratus.instance
              .streamDocuments(
                store.collection('users'),
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((docs) => docs.map((doc) => doc.data()).toList()),
            emitsInOrder([
              [
                {
                  'name': 'Alice',
                  'sources': [Source.server.name],
                },
              ],
            ]),
          );
        });
      });

      group('with later server data', () {
        test('should later stream the server data', () async {
          final docRef = store.collection('users').doc('alice');

          final stream = Nimbostratus.instance
              .streamDocuments(
                store.collection('users'),
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((docs) => docs.map((doc) => doc.data()).toList()),
            emitsInOrder([
              [],
              [
                {
                  'name': 'Alice',
                  'sources': [Source.server.name],
                },
              ],
              [
                {
                  'name': 'Alice',
                  'sources': [Source.server.name],
                },
                {
                  'name': 'Bob',
                  'sources': [Source.server.name],
                },
              ]
            ]),
          );

          await stream.first;

          await docRef.set({
            'name': 'Alice',
            'sources': [Source.server.name],
          });

          await store.collection('users').doc('bob').set({
            'name': 'Bob',
            'sources': [Source.server.name],
          });
        });
      });

      group('with duplicate data', () {
        test('should filter out duplicate events', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.cache.name, Source.server.name],
          });

          final stream = Nimbostratus.instance
              .streamDocuments(
                store.collection('users'),
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((docs) => docs.map((doc) => doc.data()).toList()),
            emitsInOrder([
              [
                {
                  'name': 'Alice',
                  'sources': [Source.cache.name, Source.server.name],
                }
              ],
              [
                {
                  'name': 'Alice 2',
                  'sources': [Source.cache.name, Source.server.name],
                }
              ],
            ]),
          );

          await stream.first;

          // This event is not emitted because the deepEq check in _updateFromRef will
          // filter out the change.
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.cache.name, Source.server.name],
          });

          await docRef.set({
            'name': 'Alice 2',
            'sources': [Source.cache.name, Source.server.name],
          });
        });
      });
    });

    group('with a cache-and-server-first fetch policy', () {
      const fetchPolicy = StreamFetchPolicy.cacheAndServerFirst;

      group('with cache-then-server data', () {
        test('should only stream the server data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.cache.name],
          });

          final stream = Nimbostratus.instance
              .streamDocuments(
                store.collection('users'),
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((docs) => docs.map((doc) => doc.data()).toList()),
            emitsInOrder([
              [],
              [
                {
                  'name': 'Alice',
                  'sources': [Source.server.name],
                }
              ],
            ]),
          );

          await stream.first;

          await docRef.set({
            'name': 'Alice',
            'sources': [Source.server.name],
          });
        });
      });

      group('with cache-then-server data', () {
        test('should only stream the server data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.cache.name],
          });

          final stream = Nimbostratus.instance
              .streamDocuments(
                store.collection('users'),
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((docs) => docs.map((doc) => doc.data()).toList()),
            emitsInOrder([
              [],
              [
                {
                  'name': 'Alice',
                  'sources': [Source.server.name],
                }
              ],
            ]),
          );

          await stream.first;

          await docRef.set({
            'name': 'Alice',
            'sources': [Source.server.name],
          });
        });
      });

      group('with server-then-cache', () {
        test('should stream the server and then the cached data', () async {
          final docRef = store.collection('users').doc('alice');

          await docRef.set({
            'name': 'Alice',
            'sources': [Source.server.name],
          });

          final stream = Nimbostratus.instance
              .streamDocuments(
                store.collection('users'),
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((docs) => docs.map((doc) => doc.data()).toList()),
            emitsInOrder([
              [
                {
                  'name': 'Alice',
                  'sources': [Source.server.name],
                },
              ],
              [
                {
                  'name': 'Alice 2',
                  'sources': [Source.cache.name],
                },
              ]
            ]),
          );

          await stream.first;

          await Nimbostratus.instance.setDocument(
            docRef,
            {
              'name': 'Alice 2',
              'sources': [Source.cache.name],
            },
            writePolicy: WritePolicy.cacheOnly,
          );
        });
      });

      group('with server then server data', () {
        test('should stream all the server data', () async {
          final docRef = store.collection('users').doc('alice');

          await docRef.set({
            'name': 'Alice',
            'sources': [Source.server.name],
          });

          final stream = Nimbostratus.instance
              .streamDocuments(
                store.collection('users'),
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((docs) => docs.map((doc) => doc.data()).toList()),
            emitsInOrder([
              [
                {
                  'name': 'Alice',
                  'sources': [Source.server.name],
                },
              ],
              [
                {
                  'name': 'Alice 2',
                  'sources': [Source.server.name],
                },
              ]
            ]),
          );

          await stream.first;

          await docRef.set({
            'name': 'Alice 2',
            'sources': [Source.server.name],
          });
        });
      });
    });

    group('with a cache-and-server-once fetch policy', () {
      const fetchPolicy = StreamFetchPolicy.cacheAndServerOnce;

      group('with initial cached data', () {
        test('should stream the cached data', () async {
          final docRef = store.collection('users').doc('alice');
          await docRef.set({
            'name': 'Alice',
            'sources': [Source.server.name],
          });

          final stream = Nimbostratus.instance
              .streamDocuments(
                store.collection('users'),
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((docs) => docs.map((doc) => doc.data()).toList()),
            emitsInOrder([
              [
                {
                  'name': 'Alice',
                  'sources': [Source.server.name],
                }
              ],
            ]),
          );
        });
      });

      group('with later cached data', () {
        test('should later stream the cached data', () async {
          final docRef = store.collection('users').doc('alice');

          await docRef.set({
            'name': 'Alice',
            'sources': [Source.server.name],
          });

          final stream = Nimbostratus.instance
              .streamDocuments(
                store.collection('users'),
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((docs) => docs.map((doc) => doc.data()).toList()),
            emitsInOrder([
              [
                {
                  'name': 'Alice',
                  'sources': [Source.server.name],
                },
              ],
              [
                {
                  'name': 'Alice 2',
                  'sources': [Source.cache.name],
                },
              ]
            ]),
          );

          await stream.first;

          await Nimbostratus.instance.setDocument(
            docRef,
            {
              'name': 'Alice 2',
              'sources': [Source.cache.name],
            },
            writePolicy: WritePolicy.cacheOnly,
          );
        });
      });

      group('with initial server data', () {
        test('should stream the server data', () async {
          final docRef = store.collection('users').doc('alice');

          await docRef.set({
            'name': 'Alice',
            'sources': [Source.server.name],
          });

          final stream = Nimbostratus.instance
              .streamDocuments(
                store.collection('users'),
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((docs) => docs.map((doc) => doc.data()).toList()),
            emitsInOrder([
              [
                {
                  'name': 'Alice',
                  'sources': [Source.server.name],
                },
              ],
            ]),
          );
        });
      });

      group('with later server data', () {
        test('should not later stream the server data', () async {
          final docRef = store.collection('users').doc('alice');

          await docRef.set({
            'name': 'Alice',
            'sources': [Source.server.name],
          });

          final stream = Nimbostratus.instance
              .streamDocuments(
                store.collection('users'),
                fetchPolicy: fetchPolicy,
              )
              .asBroadcastStream();

          expectLater(
            stream.map((docs) => docs.map((doc) => doc.data()).toList()),
            emitsInOrder([
              [
                {
                  'name': 'Alice',
                  'sources': [Source.server.name],
                }
              ],
              [
                {
                  'name': 'Alice 2',
                  'sources': [Source.cache.name],
                },
              ]
            ]),
          );

          await stream.first;

          // This should not trigger a change since it is only listening to the first server event.
          await docRef.set({
            'name': 'Alice 2',
            'sources': [Source.server.name],
          });

          await Nimbostratus.instance.setDocument(
            docRef,
            {
              'name': 'Alice 2',
              'sources': [Source.cache.name],
            },
            writePolicy: WritePolicy.cacheOnly,
          );
        });
      });
    });
  });

  group('addDocument', () {
    // Since addDocument just proxies setDocument it has minimal testing.
    test('should add the document', () async {
      final snap =
          await Nimbostratus.instance.addDocument(store.collection('users'), {
        "name": 'Alice',
        "sources": [Source.cache.name],
      });

      final doc = await Nimbostratus.instance.getDocument(
        snap.reference,
        fetchPolicy: GetFetchPolicy.cacheOnly,
      );

      expect(
        doc.data(),
        equals(
          {
            "name": 'Alice',
            "sources": [Source.cache.name],
          },
        ),
      );
    });
  });

  group('setDocument', () {
    group('with a server-first write policy', () {
      test('should write to the server and then the cache', () async {
        final docRef = store.collection('users').doc('alice');

        final stream = Nimbostratus.instance
            .streamDocument(
              docRef,
              fetchPolicy: StreamFetchPolicy.cacheAndServer,
            )
            .asBroadcastStream();

        expectLater(
          stream.map((snap) => snap.data()),
          emitsInOrder([
            null,
            {
              "name": "Alice",
              "sources": [Source.cache.name, Source.server.name],
            },
          ]),
        );

        await stream.first;

        final snap = await Nimbostratus.instance.setDocument(
          store.collection('users').doc('alice'),
          {
            "name": "Alice",
            "sources": [Source.cache.name, Source.server.name],
          },
          writePolicy: WritePolicy.serverFirst,
        );

        expect(
          snap.data(),
          equals(
            {
              "name": "Alice",
              "sources": [Source.cache.name, Source.server.name],
            },
          ),
        );
      });
    });

    group('with a cache-only write policy', () {
      test('should write to only the cache', () async {
        final docRef = store.collection('users').doc('alice');

        final stream = Nimbostratus.instance
            .streamDocument(
              docRef,
              fetchPolicy: StreamFetchPolicy.cacheAndServer,
            )
            .asBroadcastStream();

        expectLater(
          stream.map((snap) => snap.data()),
          emitsInOrder([
            null,
            {
              "name": "Alice",
              "sources": [Source.cache.name],
            },
          ]),
        );

        await stream.first;

        final snap = await Nimbostratus.instance.setDocument(
          store.collection('users').doc('alice'),
          {
            "name": "Alice",
            "sources": [Source.cache.name],
          },
          writePolicy: WritePolicy.cacheOnly,
        );

        expect(
          snap.data(),
          equals(
            {
              "name": "Alice",
              "sources": [Source.cache.name],
            },
          ),
        );
      });
    });

    group('with a cache-and-server write policy', () {
      test('should write to both the server and the cache', () async {
        final docRef = store.collection('users').doc('alice');

        final stream = Nimbostratus.instance
            .streamDocument(
              docRef,
              fetchPolicy: StreamFetchPolicy.cacheAndServer,
            )
            .asBroadcastStream();

        expectLater(
          stream.map((snap) => snap.data()),
          emitsInOrder([
            null,
            {
              "name": "Alice",
              "sources": [Source.cache.name, Source.server.name],
            },
          ]),
        );

        await stream.first;

        final snap = await Nimbostratus.instance.setDocument(
          store.collection('users').doc('alice'),
          {
            "name": "Alice",
            "sources": [Source.cache.name, Source.server.name],
          },
          writePolicy: WritePolicy.cacheAndServer,
        );

        expect(
          snap.data(),
          equals(
            {
              "name": "Alice",
              "sources": [Source.cache.name, Source.server.name],
            },
          ),
        );
      });
    });
  });

  group('updateDocument', () {
    group('with a server-first write policy', () {
      test('should update the server and then the cache', () async {
        final docRef = store.collection('users').doc('alice');

        final stream = Nimbostratus.instance
            .streamDocument(
              docRef,
              fetchPolicy: StreamFetchPolicy.cacheAndServer,
            )
            .asBroadcastStream();

        expectLater(
          stream.map((snap) => snap.data()),
          emitsInOrder([
            null,
            {
              "name": "Alice",
              "sources": [Source.cache.name, Source.server.name],
            },
          ]),
        );

        await stream.first;

        final snap = await Nimbostratus.instance.updateDocument(
          store.collection('users').doc('alice'),
          {
            "name": "Alice",
            "sources": [Source.cache.name, Source.server.name],
          },
          writePolicy: WritePolicy.serverFirst,
        );

        expect(
          snap.data(),
          equals(
            {
              "name": "Alice",
              "sources": [Source.cache.name, Source.server.name],
            },
          ),
        );
      });
    });

    group('with a cache-and-server write policy', () {
      test('should update both the cache and server', () async {
        final docRef = store.collection('users').doc('alice');

        final stream = Nimbostratus.instance
            .streamDocument(
              docRef,
              fetchPolicy: StreamFetchPolicy.cacheAndServer,
            )
            .asBroadcastStream();

        expectLater(
          stream.map((snap) => snap.data()),
          emitsInOrder([
            null,
            {
              "name": "Alice",
              "sources": [Source.cache.name, Source.server.name],
            },
          ]),
        );

        await stream.first;

        final snap = await Nimbostratus.instance.updateDocument(
          store.collection('users').doc('alice'),
          {
            "name": "Alice",
            "sources": [Source.cache.name, Source.server.name],
          },
          writePolicy: WritePolicy.cacheAndServer,
        );

        expect(
          snap.data(),
          equals(
            {
              "name": "Alice",
              "sources": [Source.cache.name, Source.server.name],
            },
          ),
        );
      });
    });

    group('with a cache-only write policy', () {
      test('should update both the cache and server', () async {
        final docRef = store.collection('users').doc('alice');

        final stream = Nimbostratus.instance
            .streamDocument(
              docRef,
              fetchPolicy: StreamFetchPolicy.cacheAndServer,
            )
            .asBroadcastStream();

        expectLater(
          stream.map((snap) => snap.data()),
          emitsInOrder([
            null,
            {
              "name": "Alice",
              "sources": [Source.cache.name],
            },
          ]),
        );

        await stream.first;

        final snap = await Nimbostratus.instance.updateDocument(
            store.collection('users').doc('alice'),
            {
              "name": "Alice",
              "sources": [Source.cache.name],
            },
            writePolicy: WritePolicy.cacheOnly);

        expect(
          snap.data(),
          equals(
            {
              "name": "Alice",
              "sources": [Source.cache.name],
            },
          ),
        );
      });
    });

    group('with a toFirestore converter', () {
      test('should serialize and write the converted document data', () async {
        final docRef = store
            .collection('users')
            .withConverter<MockUserModel>(
              fromFirestore: (snap, _) => MockUserModel.fromJson(snap.data()!),
              toFirestore: (user, _) => user.toJson(),
            )
            .doc('alice');

        final stream = Nimbostratus.instance
            .streamDocument(
              docRef,
              fetchPolicy: StreamFetchPolicy.cacheAndServer,
            )
            .asBroadcastStream();

        expectLater(
          stream.map((snap) => snap.data()?.toJson()),
          emitsInOrder([
            null,
            {
              "name": "Alice",
            },
          ]),
        );

        await stream.first;

        final snap = await Nimbostratus.instance.updateDocument<MockUserModel>(
          docRef,
          MockUserModel(name: 'Alice'),
          writePolicy: WritePolicy.cacheAndServer,
          toFirestore: (user, _) => user.toJson(),
        );

        expect(
          snap.data()!.toJson(),
          equals(
            {
              "name": "Alice",
            },
          ),
        );
      });
    });
  });

  group('modifyDocument', () {
    group('without an existing value for the document', () {
      test('should write the document', () async {
        final docRef = store.collection('users').doc('alice');

        final stream = Nimbostratus.instance
            .streamDocument(
              docRef,
              fetchPolicy: StreamFetchPolicy.cacheAndServer,
            )
            .asBroadcastStream();

        expectLater(
          stream.map((snap) => snap.data()),
          emitsInOrder([
            null,
            {
              "name": "Alice",
              "sources": [Source.cache.name, Source.server.name],
            },
          ]),
        );

        await stream.first;

        final snap = await Nimbostratus.instance.modifyDocument(
          store.collection('users').doc('alice'),
          (value) {
            expect(value, equals(null));
            return {
              "name": "Alice",
              "sources": [Source.cache.name, Source.server.name],
            };
          },
          writePolicy: WritePolicy.cacheAndServer,
        );

        expect(
          snap.data(),
          equals(
            {
              "name": "Alice",
              "sources": [Source.cache.name, Source.server.name],
            },
          ),
        );
      });
    });

    group('with an existing value for the document', () {
      test('should write the document', () async {
        final docRef = store.collection('users').doc('alice');
        await docRef.set({
          "name": "Alice",
          "sources": [Source.cache.name, Source.server.name],
        });

        final stream = Nimbostratus.instance
            .streamDocument(
              docRef,
              fetchPolicy: StreamFetchPolicy.cacheAndServer,
            )
            .asBroadcastStream();

        expectLater(
          stream.map((snap) => snap.data()),
          emitsInOrder([
            {
              "name": "Alice",
              "sources": [Source.cache.name, Source.server.name],
            },
            {
              "name": "Bob",
              "sources": [Source.cache.name, Source.server.name],
            },
          ]),
        );

        await stream.first;

        final snap = await Nimbostratus.instance.modifyDocument(
          store.collection('users').doc('alice'),
          (value) {
            expect(
              value,
              equals(
                {
                  "name": "Alice",
                  "sources": [Source.cache.name, Source.server.name],
                },
              ),
            );
            return {
              "name": "Bob",
              "sources": [Source.cache.name, Source.server.name],
            };
          },
          writePolicy: WritePolicy.cacheAndServer,
        );

        expect(
          snap.data(),
          equals(
            {
              "name": "Bob",
              "sources": [Source.cache.name, Source.server.name],
            },
          ),
        );
      });
    });
  });

  group('deleteDocument', () {
    test('should remove the document from the cache', () async {
      final docRef = store.collection('users').doc('alice');

      await docRef.set({
        "name": 'alice',
        "sources": [Source.cache.name, Source.server.name],
      });

      final stream = Nimbostratus.instance
          .streamDocument(
            docRef,
            fetchPolicy: StreamFetchPolicy.cacheOnly,
          )
          .asBroadcastStream();

      expectLater(
        stream.map((snap) => snap.data()),
        emitsInOrder(
          [
            {
              "name": 'alice',
              "sources": [Source.cache.name, Source.server.name],
            },
            null
          ],
        ),
      );

      await stream.first;

      await Nimbostratus.instance.deleteDocument(docRef);
    });
  });

  group('batchUpdateDocuments', () {
    group('with server-first changes', () {
      test('should write all cache updates after the commit', () async {
        final docRef = store.collection('users').doc('alice');

        await docRef.set({
          "name": 'alice',
          "sources": [Source.cache.name, Source.server.name],
        });

        await Nimbostratus.instance.batchUpdateDocuments((batcher) async {
          await batcher.modify<Map<String, dynamic>>(docRef, (data) {
            return {
              ...data!,
              "age": 22,
            };
          });

          await batcher.update<Map<String, dynamic>>(docRef, {
            "name": "Alice 2",
          });

          await batcher.commit();
        });

        final snap = await Nimbostratus.instance.getDocument(
          docRef,
          fetchPolicy: GetFetchPolicy.cacheOnly,
        );

        expect(
          snap.data(),
          equals(
            {
              "name": "Alice 2",
              "age": 22,
              "sources": [Source.cache.name, Source.server.name],
            },
          ),
        );
      });

      test('should not write cache updates before the commit', () async {
        final docRef = store.collection('users').doc('alice');

        await docRef.set({
          "name": 'Alice',
          "sources": [Source.cache.name, Source.server.name],
        });

        await Nimbostratus.instance.batchUpdateDocuments((batcher) async {
          await batcher.modify<Map<String, dynamic>>(docRef, (data) {
            return {
              ...data!,
              "age": 22,
            };
          });

          await batcher.update<Map<String, dynamic>>(docRef, {
            "name": "Alice 2",
          });

          final snap = await Nimbostratus.instance.getDocument(
            docRef,
            fetchPolicy: GetFetchPolicy.cacheOnly,
          );

          expect(
            snap.data(),
            equals(
              {
                "name": "Alice",
                "sources": [Source.cache.name, Source.server.name],
              },
            ),
          );

          await batcher.commit();
        });

        final snap = await Nimbostratus.instance.getDocument(
          docRef,
          fetchPolicy: GetFetchPolicy.cacheOnly,
        );

        expect(
          snap.data(),
          equals(
            {
              "name": "Alice 2",
              "age": 22,
              "sources": [Source.cache.name, Source.server.name],
            },
          ),
        );
      });
    });

    group('with optimistic changes', () {
      test(
          'should optimistically update the cache before the data is committed',
          () async {
        final docRef = store.collection('users').doc('alice');

        await docRef.set({
          "name": 'alice',
          "sources": [Source.cache.name, Source.server.name],
        });

        await Nimbostratus.instance.batchUpdateDocuments((batcher) async {
          await batcher.modify<Map<String, dynamic>>(
            docRef,
            (data) {
              return {
                ...data!,
                "age": 22,
              };
            },
            writePolicy: WritePolicy.cacheAndServer,
          );

          await batcher.update<Map<String, dynamic>>(
            docRef,
            {
              "name": "Alice 2",
            },
            writePolicy: WritePolicy.cacheAndServer,
          );

          final snap = await Nimbostratus.instance.getDocument(
            docRef,
            fetchPolicy: GetFetchPolicy.cacheOnly,
          );

          expect(
            snap.data(),
            equals(
              {
                "name": "Alice 2",
                "age": 22,
                "sources": [Source.cache.name, Source.server.name],
              },
            ),
          );

          await batcher.commit();
        });

        final snap = await Nimbostratus.instance.getDocument(
          docRef,
          fetchPolicy: GetFetchPolicy.cacheOnly,
        );

        expect(
          snap.data(),
          equals(
            {
              "name": "Alice 2",
              "age": 22,
              "sources": [Source.cache.name, Source.server.name],
            },
          ),
        );
      });

      test(
        'should mark the optimistic snaps as non-optimistic after the changes are committed',
        () async {
          final docRef = store.collection('users').doc('alice');

          await docRef.set({
            "name": 'alice',
            "sources": [Source.cache.name, Source.server.name],
          });

          NimbostratusDocumentSnapshot? update1;
          NimbostratusDocumentSnapshot? update2;

          await Nimbostratus.instance.batchUpdateDocuments((batcher) async {
            update1 = await batcher.modify<Map<String, dynamic>>(
              docRef,
              (data) {
                return {
                  ...data!,
                  "age": 22,
                };
              },
              writePolicy: WritePolicy.cacheAndServer,
            );

            expect(
              update1!.isOptimistic,
              equals(true),
            );

            update2 = await batcher.update<Map<String, dynamic>>(
              docRef,
              {
                "name": "Alice 2",
              },
              writePolicy: WritePolicy.cacheAndServer,
            );

            expect(
              update2!.isOptimistic,
              equals(true),
            );

            await batcher.commit();
          });

          expect(
            update1!.isOptimistic,
            equals(false),
          );
          expect(
            update2!.isOptimistic,
            equals(false),
          );
        },
      );

      test(
        'should mark the optimistic snaps as non-optimistic after the update completes',
        () async {
          final docRef = store.collection('users').doc('alice');

          await docRef.set({
            "name": 'alice',
            "sources": [Source.cache.name, Source.server.name],
          });

          NimbostratusDocumentSnapshot? update1;
          NimbostratusDocumentSnapshot? update2;

          await Nimbostratus.instance.batchUpdateDocuments((batcher) async {
            update1 = await batcher.modify<Map<String, dynamic>>(
              docRef,
              (data) {
                return {
                  ...data!,
                  "age": 22,
                };
              },
              writePolicy: WritePolicy.cacheOnly,
            );

            expect(
              update1!.isOptimistic,
              equals(true),
            );

            update2 = await batcher.update<Map<String, dynamic>>(
              docRef,
              {
                "name": "Alice 2",
              },
              writePolicy: WritePolicy.cacheOnly,
            );

            expect(
              update2!.isOptimistic,
              equals(true),
            );
          });

          expect(
            update1!.isOptimistic,
            equals(false),
          );
          expect(
            update2!.isOptimistic,
            equals(false),
          );
        },
      );

      test('should rollback the cache changes if an exception is thrown',
          () async {
        final docRef = store.collection('users').doc('alice');

        await docRef.set({
          "name": 'Alice',
          "sources": [Source.cache.name, Source.server.name],
        });

        final stream = Nimbostratus.instance
            .streamDocument(
              docRef,
              fetchPolicy: StreamFetchPolicy.cacheOnly,
            )
            .asBroadcastStream();

        expectLater(
          stream.map((snap) => snap.data()),
          emitsInOrder([
            {
              "name": 'Alice',
              "sources": [Source.cache.name, Source.server.name],
            },
            {
              "name": 'Alice',
              "age": 22,
              "sources": [Source.cache.name, Source.server.name],
            },
            {
              "name": 'Alice 2',
              "age": 22,
              "sources": [Source.cache.name, Source.server.name],
            },
            // Once the exception is thrown, the document stream will replay
            // the optimistic updates in reverse order to unwind the changes.
            {
              "name": 'Alice',
              "age": 22,
              "sources": [Source.cache.name, Source.server.name],
            },
            {
              "name": 'Alice',
              "sources": [Source.cache.name, Source.server.name],
            },
          ]),
        );

        await Nimbostratus.instance.batchUpdateDocuments((batcher) async {
          await batcher.modify<Map<String, dynamic>>(
            docRef,
            (data) {
              return {
                ...data!,
                "age": 22,
              };
            },
            writePolicy: WritePolicy.cacheAndServer,
          );

          await batcher.update<Map<String, dynamic>>(
            docRef,
            {
              "name": "Alice 2",
            },
            writePolicy: WritePolicy.cacheAndServer,
          );

          final snap = await Nimbostratus.instance.getDocument(
            docRef,
            fetchPolicy: GetFetchPolicy.cacheOnly,
          );

          expect(
            snap.data(),
            equals(
              {
                "name": "Alice 2",
                "age": 22,
                "sources": [Source.cache.name, Source.server.name],
              },
            ),
          );

          throw Error();
        });

        final snap = await Nimbostratus.instance.getDocument(
          docRef,
          fetchPolicy: GetFetchPolicy.cacheOnly,
        );

        expect(
          snap.data(),
          equals(
            {
              "name": 'Alice',
              "sources": [Source.cache.name, Source.server.name],
            },
          ),
        );
      });

      test('should not rollback snapshots added on top of optimistic updates',
          () async {
        final docRef = store.collection('users').doc('alice');

        await docRef.set({
          "name": 'Alice',
          "sources": [Source.cache.name, Source.server.name],
        });

        final stream = Nimbostratus.instance
            .streamDocument(
              docRef,
              fetchPolicy: StreamFetchPolicy.cacheOnly,
            )
            .asBroadcastStream();

        expectLater(
          stream.map((snap) => snap.data()),
          emitsInOrder([
            {
              "name": 'Alice',
              "sources": [Source.cache.name, Source.server.name],
            },
            {
              "name": 'Alice',
              "age": 22,
              "sources": [Source.cache.name, Source.server.name],
            },
            {
              "name": 'Alice 2',
              "age": 22,
              "sources": [Source.cache.name, Source.server.name],
            },
            {
              "name": 'Alice 3',
              "age": 22,
              "sources": [Source.cache.name, Source.server.name],
            },
            {
              "name": 'Alice 4',
              "age": 22,
              "sources": [Source.cache.name, Source.server.name],
            },
          ]),
        );

        await Nimbostratus.instance.batchUpdateDocuments((batcher) async {
          await batcher.modify<Map<String, dynamic>>(
            docRef,
            (data) {
              return {
                ...data!,
                "age": 22,
              };
            },
            writePolicy: WritePolicy.cacheAndServer,
          );

          await batcher.update<Map<String, dynamic>>(
            docRef,
            {
              "name": "Alice 2",
            },
            writePolicy: WritePolicy.cacheAndServer,
          );

          // This is an example of an update somewhere else on the client that occurs during the batch update.
          // This update is on top of the optimistic batch updates so the rollback should not re-emit the old
          // optimistic updates on the stream and should preserve this value.
          await Nimbostratus.instance.updateDocument(
            docRef,
            {
              "name": "Alice 3",
            },
            writePolicy: WritePolicy.cacheOnly,
          );

          throw Error();
        });

        final snap = await Nimbostratus.instance.getDocument(
          docRef,
          fetchPolicy: GetFetchPolicy.cacheOnly,
        );

        // At the end of the rollback, the current value for the document should be the
        // non-optimistic update applied during the batch.
        expect(
          snap.data(),
          equals(
            {
              "name": 'Alice 3',
              "age": 22,
              "sources": [Source.cache.name, Source.server.name],
            },
          ),
        );

        await Nimbostratus.instance.updateDocument(
          docRef,
          {
            "name": "Alice 4",
          },
          writePolicy: WritePolicy.cacheOnly,
        );
      });

      test('should not rollback snapshots added in between optimistic updates',
          () async {
        final docRef = store.collection('users').doc('alice');

        await docRef.set({
          "name": 'Alice',
          "sources": [Source.cache.name, Source.server.name],
        });

        final stream = Nimbostratus.instance
            .streamDocument(
              docRef,
              fetchPolicy: StreamFetchPolicy.cacheOnly,
            )
            .asBroadcastStream();

        expectLater(
          stream.map((snap) => snap.data()),
          emitsInOrder([
            {
              "name": 'Alice',
              "sources": [Source.cache.name, Source.server.name],
            },
            {
              "name": 'Alice',
              "age": 22,
              "sources": [Source.cache.name, Source.server.name],
            },
            {
              "name": 'Alice 2',
              "age": 22,
              "sources": [Source.cache.name, Source.server.name],
            },
            {
              "name": 'Alice 3',
              "age": 22,
              "sources": [Source.cache.name, Source.server.name],
            },
            {
              "name": 'Alice 2',
              "age": 22,
              "sources": [Source.cache.name, Source.server.name],
            },
            {
              "name": 'Alice 4',
              "age": 22,
              "sources": [Source.cache.name, Source.server.name],
            },
          ]),
        );

        await Nimbostratus.instance.batchUpdateDocuments((batcher) async {
          await batcher.modify<Map<String, dynamic>>(
            docRef,
            (data) {
              return {
                ...data!,
                "age": 22,
              };
            },
            writePolicy: WritePolicy.cacheAndServer,
          );

          // This is an example of an update somewhere else on the client that occurs during the batch update.
          // This update is in between optimistic batch updates so the rollback should replay optimistic updates
          // on top of this intermediate value, but not re-emit optimistic updates that occurred before it since
          // this is still the correct value.
          await Nimbostratus.instance.updateDocument(
            docRef,
            {
              "name": "Alice 2",
            },
            writePolicy: WritePolicy.cacheOnly,
          );

          await batcher.update<Map<String, dynamic>>(
            docRef,
            {
              "name": "Alice 3",
            },
            writePolicy: WritePolicy.cacheAndServer,
          );

          throw Error();
        });

        final snap = await Nimbostratus.instance.getDocument(
          docRef,
          fetchPolicy: GetFetchPolicy.cacheOnly,
        );

        // At the end of the rollback, the current value for the document should be the
        // non-optimistic update applied during the batch.
        expect(
          snap.data(),
          equals(
            {
              "name": 'Alice 2',
              "age": 22,
              "sources": [Source.cache.name, Source.server.name],
            },
          ),
        );

        await Nimbostratus.instance.updateDocument(
          docRef,
          {
            "name": "Alice 4",
          },
          writePolicy: WritePolicy.cacheOnly,
        );
      });

      test(
          'should not apply or rollback optimistic snapshots that do not change the document value',
          () async {
        final docRef = store.collection('users').doc('alice');

        await docRef.set({
          "name": 'Alice',
          "sources": [Source.cache.name, Source.server.name],
        });

        final stream = Nimbostratus.instance
            .streamDocument(
              docRef,
              fetchPolicy: StreamFetchPolicy.cacheOnly,
            )
            .asBroadcastStream();

        expectLater(
          stream.map((snap) => snap.data()),
          emitsInOrder([
            {
              "name": 'Alice',
              "sources": [Source.cache.name, Source.server.name],
            },
            // The optimistic update should not be re-emitted since it did not change the existing cached snapshot value.
            {
              "name": 'Alice 2',
              "sources": [Source.cache.name, Source.server.name],
            },
          ]),
        );

        await Nimbostratus.instance.batchUpdateDocuments((batcher) async {
          final updatedSnap = await batcher.update<Map<String, dynamic>>(
            docRef,
            {
              "name": 'Alice',
            },
            writePolicy: WritePolicy.cacheAndServer,
          );

          expect(updatedSnap.isOptimistic, equals(false));

          throw Error();
        });

        final snap = await Nimbostratus.instance.getDocument(
          docRef,
          fetchPolicy: GetFetchPolicy.cacheOnly,
        );

        // At the end of the rollback, the current value for the document should be the
        // non-optimistic update applied during the batch.
        expect(
          snap.data(),
          equals(
            {
              "name": 'Alice',
              "sources": [Source.cache.name, Source.server.name],
            },
          ),
        );

        await Nimbostratus.instance.updateDocument(
          docRef,
          {
            "name": "Alice 2",
          },
          writePolicy: WritePolicy.cacheOnly,
        );
      });
    });
  });
}
