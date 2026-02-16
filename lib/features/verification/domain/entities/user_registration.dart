class UserRegistration {
  final String id;
  final String name;
  final List<double> faceEmbedding; // The registered face template

  UserRegistration({
    required this.id,
    required this.name,
    required this.faceEmbedding,
  });
}
