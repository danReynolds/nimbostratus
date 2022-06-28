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
  /// Specifies that documents should initially be delivered on the stream from the cache if present, otherwise requested from the server.
  /// Subsequent updates are delivered whenever any of the initial documents returned change in the cache.
  cacheFirst,

  /// Specifies that documents should only be delivered on the stream from changes to documents in the cache.
  cacheOnly,

  /// Specifies that document should be delivered on the stream from the server once, blocking on waiting for server data before returning data from the cache and then
  /// emitting continued cache updates. Helpful when trying to show the latest value first to prevent staleness and then continue with changes made to the cache.
  serverFirst,

  /// Specifies that documents should only be delivered on the stream from changes to the server snapshot and never changes
  /// to those documents in the cache.
  serverOnly,

  /// Specifies that documents should be delivered on the stream from both the cache and server whenever they have updated data.
  cacheAndServer,

  /// Specifies that documents should initially delivered on the stream from both the cache and server with updated data similarly to [cacheAndServer],
  /// but only emits a single update from the server and then continue with changes made to the cache. Helpful when trying to show data immediately (via cache)
  /// but fetching the updated data once to prevent long-term staleness.
  cacheAndServerOnce,

  /// Specifies that documents should be delivered on the stream from the server first and then subsequently whenever either the cache or
  /// server have updated data the same as [cacheAndServer].
  cacheAndServerFirst,
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
