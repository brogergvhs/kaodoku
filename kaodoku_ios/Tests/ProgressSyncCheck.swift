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
}
