class Contact {
  const Contact({
    required this.id,
    required this.role,
    required this.displayName,
    required this.allowedConversationTypes,
    required this.reason,
    this.email,
  });

  final String id;
  final String role;
  final String displayName;
  final String? email;
  final List<String> allowedConversationTypes;
  final String reason;

  bool allowsConversationType(String type) {
    return allowedConversationTypes.contains(type);
  }
}
