class CatalogItem {
  const CatalogItem({required this.id, required this.name});

  factory CatalogItem.fromJson(Map<String, dynamic> json) {
    return CatalogItem(id: json['id'] as int, name: json['name'] as String);
  }

  final int id;
  final String name;
}
