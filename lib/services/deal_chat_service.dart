/// Lightweight stub for deal chat actions so the UI can compile.
/// Replace with real implementation when backend is ready.
class DealChatService {
  /// Respond to a deal proposal (accept/reject).
  Future<bool> respondToDeal({
    required String? dealProposalId,
    required bool accepted,
  }) async {
    // Stubbed to always succeed.
    return true;
  }
}
