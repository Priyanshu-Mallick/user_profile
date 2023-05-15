class Topic {
  String id;
  final String name;
  final String description;

  Topic({this.id = '', required this.name, required this.description});

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
    };
  }

  factory Topic.fromMap(Map<String, dynamic> map, {required String id}) {
    return Topic(
      id: id,
      name: map['name'],
      description: map['description'],
    );
  }
}