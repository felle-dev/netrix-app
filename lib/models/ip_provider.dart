class IPProvider {
  final String name;
  final String ipUrl;
  final String detailsUrl; // Can use {ip} placeholder
  final String ipJsonKey;

  IPProvider({
    required this.name,
    required this.ipUrl,
    required this.detailsUrl,
    required this.ipJsonKey,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'ipUrl': ipUrl,
    'detailsUrl': detailsUrl,
    'ipJsonKey': ipJsonKey,
  };

  factory IPProvider.fromJson(Map<String, dynamic> json) => IPProvider(
    name: json['name'],
    ipUrl: json['ipUrl'],
    detailsUrl: json['detailsUrl'],
    ipJsonKey: json['ipJsonKey'],
  );
}
