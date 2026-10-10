import Foundation
@testable import Kaodoku
import Testing

@MainActor
@Test("A flush that never reaches the server says so and keeps the marks")
func flushFailureIsVisible() async throws {
  let instance = "sync-\(UUID().uuidString)"
  let dir = LocalStore.root.appendingPathComponent(instance, isDirectory: true)
  defer { try? FileManager.default.removeItem(at: dir) }

  let store = LocalStore()
  await store.load(instance: instance)
  store.recordMark(id: 1, volume: false, page: 1, totalPages: 3)
  store.recordMark(id: 1, volume: false, page: 2, totalPages: 3)
  #expect(store.pendingMarks == 2)

  // Port 1 refuses immediately, so the POST fails the way an unreachable
  // server does. Before the fix this was swallowed and nothing surfaced.
  try await store.flush(APIClient(baseURL: #require(URL(string: "http://127.0.0.1:1")), token: "t"))

  #expect(store.syncError != nil)
  #expect(store.pendingMarks == 2) // kept for the next attempt, never dropped
  #expect(store.lastSyncAt == nil) // nothing reached the server
  #expect(store.queuedMarks.count == 2) // the sync screen sees what's waiting
  #expect(store.queuedMarks.map(\.page) == [1, 2])
  #expect(!store.flushing)
}

@MainActor
@Test("A device that has never downloaded can still save reading progress")
func freshDevicePersistsProgress() async {
  let files = FileManager.default
  let instance = "fresh-\(UUID().uuidString)"
  let dir = LocalStore.root.appendingPathComponent(instance, isDirectory: true)
  defer { try? files.removeItem(at: dir) }
  #expect(!files.fileExists(atPath: dir.path)) // nothing was ever downloaded

  let store = LocalStore()
  await store.load(instance: instance)
  store.recordMark(id: 1, volume: false, page: 1, totalPages: 3)
  await store.flush(nil) // save locally, no server involved

  #expect(store.persistenceError == nil)
  #expect(files.fileExists(atPath: LocalStore.queueURL(instance).path))
  #expect(files.fileExists(atPath: LocalStore.indexURL(instance).path))
}
