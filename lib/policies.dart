/// The policy options that determine whether Cloud Firestore documents should be returned
/// from the cache only, server only, or a combination of both for future-based requests.
enum GetFetchPolicy {
  /// Specifies that documents should be returned from the cache first, otherwise
  /// it should fallback to trying to read it from the server.
  cacheFirst,

  /// Specifies that documents should be read from the cache only and return null if not present,
  /// never hitting the server.
  cacheOnly,

  /// Specifies that documents should only be read from the server and will never be populated from cached data.
  serverOnly,
}

/// The policy options that determine whether Cloud Firestore documents should be returned
/// from the cache only, server only, or a combination of both over time for stream-based requests.
enum StreamFetchPolicy {
  /// Specifies that the initial set of documents should be delivered from the cache if present, otherwise requested from the server.
  /// Subsequent updates are delivered whenever any of the initial entries returned change in the cache.
  cacheFirst,

  /// Specifies that documents should only be delivered on the stream from changes to documents in the cache.
  cacheOnly,

  /// Specifies that documents should only be delivered on the stream from changes to the server snapshot and never changes
  /// to those documents in the cache.
  serverOnly,

  /// Specifies that documents should be delivered on the stream once from the server first and then subsequently from the cache
  /// whenever any of the entries the server returned change in the cache.
  serverFirst,

  /// Specifies that the stream should immediately subscribe to changes from both the cache and server, updating whenever either has
  /// updated data.
  cacheAndServer,

  /// Specifies that the stream should immediately subscribe to changes from both the cache and server similarly to [cacheAndServer], but only emits a
  ///  single update from the server and then continued changes from the cache. Helpful when trying to show data immediately (via cache) but fetching
  /// the updated data one time to prevent staleness.
  cacheAndServerOnce
}

enum WritePolicy {
  /// Specifies that the data should be written only to the cache and not persisted to the server.
  cacheOnly,

  /// Specifies that the data should be written to the cache and server simultaneously. If the write to the server fails, then the write to the cache will be rolled back.
  cacheAndServer,

  // Specifies that the data should be written to the server first, followed by the cache when the write to the server completes.
  serverFirst
}

enum DeletePolicy {
  /// Specifies that the data should be deleted only from the cache and not persisted to the server.
  cacheOnly,

  /// Specifies that the data should be deleted from the cache and server simultaneously. If the write to the server fails, then the delete to the cache will be rolled back.
  cacheAndServer,

  // Specifies that the data should be deleted on the server first, followed by the cache when the delete from the server completes.
  serverFirst
}

GetFetchPolicy convertStreamFetchPolicyToGetFetchPolicy(
  StreamFetchPolicy fetchPolicy,
) {
  switch (fetchPolicy) {
    case StreamFetchPolicy.serverFirst:
      return GetFetchPolicy.serverOnly;
    case StreamFetchPolicy.cacheFirst:
      return GetFetchPolicy.cacheFirst;
    default:
      return GetFetchPolicy.cacheOnly;
  }
}
