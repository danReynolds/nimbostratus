# Nimbostratus 🌩

Nimbostratus is a reactive data-fetching and cache management library built on top of [Cloud Firestore](https://pub.dev/packages/cloud_firestore).

The Cloud Firestore client API for Flutter is great at fetching and streaming documents. Nimbostratus extends that API to include some additional features:

1. Reading, writing and subscribing to documents changes on the client using the Nimbostratus in-memory cache.
2. Data fetching policies like cache-first and cache-and-server to implement common data fetching practices for responsive UIs.
3. Optimistic updates through cache-write policies.

## Usage

### Reading documents

```dart
import 'package:nimbostratus/nimbostratus.dart';

final snap = await Nimbostratus.instance.getDocument(
  FirebaseFirestore.instance.collection('users').doc('alice'),
  fetchPolicy: GetFetchPolicy.cacheFirst,
);
```

In this example, we request to read a Firestore document from the cache first, falling back to the server if it is unavailable. There are a few handly fetch policies to choose from which you can look at [here].

### Streaming documents

Documents can similarly be streamed from the cache, server, or a combination of both:

```dart
final documentStream = Nimbostratus.instance
  .streamDocument(
    FirebaseFirestore.instance.collection('users').doc('user-1'),
    fetchPolicy: StreamFetchPolicy.cacheAndServer,
  ).listen((snap) {
    print(snap.data());
    // { 'id': 'user-1', 'name': 'Anakin Skywalker' }
  });
```

In this case, we're streaming the document `users/alice` from both the cache and the server. A fetch policy like this can be valuable since data can be eagerly returned from the cache in order to create a zippy user experience, while maintaining a subscription to changes from the server in the future.

Streamed documents will also update when changes are made to the cache. In the example below, we can manually update a value in the in-memory cache, causing all of the places across our app that are streaming that document to update:

```dart
final docRef = FirebaseFirestore.instance.collection('users').doc('example2');

final documentStream = Nimbostratus.instance
  .streamDocument(
    docRef,
    fetchPolicy: StreamFetchPolicy.cacheAndServer,
  ).listen((snap) {
    print(snap.data());
    // { 'id': 'user-1', 'name': 'Anakin Skywalker' }
    // { 'id': 'user-1', 'name': 'Darth Vader' }
  });

await NimbostratusInstance.updateDocument(
  docRef,
  { 'name': 'Darth Vader' }
  writePolicy: WritePolicy.cacheOnly,
);
```

Executing and reacting to client-side cache changes is an intentional gap in the feature set of the default `cloud_firestore` library, which is meant to function as a relatively simple document-fetching layer rather than a document management layer. Nimbostratus aims to fill that gap and provide functionality similar to other data fetching libraries that offer more extensive data lifecycle APIs.

## Querying documents

Querying for documents follows a similar pattern:

```dart
final stream = Nimbostratus.instance
  .streamDocuments(
    store.collection('users').where('first_name', isEqualTo: 'Ben'),
    fetchPolicy: StreamFetchPolicy.serverFirst,
  ).listen((snap) {
    print(snap.data());
    // [
    //   { 'id': 'user-1', 'first_name': 'Ben', 'last_name': 'Kenobi', 'side': 'light' },
    //   { 'id': 'user-2', 'first_name': 'Ben', 'last_name': 'Solo', 'side': 'light' }
    // ]
  });
```

With the `serverFirst` policy shown above, data will first be delivered to the stream from the server once and then the stream will listen to any changes to the cached data. When a later cache update occurs like this:

```dart
await NimbostratusInstance.updateDocument(
   store.collection('users').doc('user-2'),
  { 'side': 'dark' }
  writePolicy: WritePolicy.cacheAndServer,
);
```

The stream is subscribed to any changes to documents `user-1` and `user-2` so when we update the document with a `cacheAndServer` write policy, the stream will immediately receive the updated query snapshot from the cache:

```dart
// [
//   { 'id': 'user-1', 'first_name': 'Ben', 'last_name': 'Kenobi', 'side': 'light' },
//   { 'id': 'user-2', 'first_name': 'Ben', 'last_name': 'Solo', 'side': 'dark' }
// ]
```

and then later emit another value based on the server response if it has any new data, such as if another field had been added to the document on the server since we last queried for it:

```dart
// [
//   { 'id': 'user-1', 'first_name': 'Ben', 'last_name': 'Kenobi', 'side': 'light' },
//   { 'id': 'user-2', 'first_name': 'Ben', 'last_name': 'Solo', 'side': 'dark', 'relationship_status: 'complicated' }
// ]
```

## Optimistic updates

Some libraries take advantage of optimistic updates on the client to make an operation appear complete to the user before the response from the server is returned. We've accomplished something similar above with our 