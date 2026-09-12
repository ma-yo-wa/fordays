import Foundation
import Supabase

enum AppConfig {
  /// Same project as the web/PWA and former Expo client (anon key is public).
  static let supabaseURL = URL(string: "https://emuygnacujwcodbgupjn.supabase.co")!
  static let supabaseAnonKey =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVtdXlnbmFjdWp3Y29kYmd1cGpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU0MzQ5NTksImV4cCI6MjEwMTAxMDk1OX0.rlisz8hym_GOs3_4PWE32FpsO_unkWEHxR-TsBxkz4k"
  static let authCallback = URL(string: "fordays://auth/callback")!
}

enum FordaysError: LocalizedError {
  case backend
  case message(String)

  var errorDescription: String? {
    switch self {
    case .backend:
      return "Fordays can’t reach the server. Check your connection and try again."
    case .message(let s):
      return s
    }
  }

  static func fromAuth(_ error: Error) -> FordaysError {
    let msg = error.localizedDescription
    if msg.localizedCaseInsensitiveContains("invalid login") {
      return .message("Wrong email or password")
    }
    if msg.localizedCaseInsensitiveContains("email not confirmed") {
      return .message("Confirm your email first, then try again")
    }
    if msg.localizedCaseInsensitiveContains("rate") {
      return .message("Too many tries — wait a minute and try again")
    }
    return .message(msg.isEmpty ? "Couldn’t sign in" : msg)
  }
}

@MainActor
final class SupabaseService {
  static let shared = SupabaseService()

  let client: SupabaseClient

  private init() {
    client = SupabaseClient(
      supabaseURL: AppConfig.supabaseURL,
      supabaseKey: AppConfig.supabaseAnonKey,
      options: .init(
        auth: .init(
          redirectToURL: AppConfig.authCallback,
          emitLocalSessionAsInitialSession: true
        )
      )
    )
  }
}
