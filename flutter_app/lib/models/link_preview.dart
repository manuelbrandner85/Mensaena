/// Metadaten einer URL-Vorschau (Open Graph / Twitter Cards).
///
/// Wird via [LinkPreviewService] aus dem HTML-Head gezogen und im Chat
/// unter Nachrichten als Karte gerendert.
///
/// Adaptiert aus Weltenbibliothek-App (manuelbrandner85/Weltenbibliothekapp,
/// lib/models/link_preview.dart) — identisches Schema.
class LinkPreview {
  const LinkPreview({
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
  });

  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? siteName;

  bool get hasContent =>
      (title != null && title!.trim().isNotEmpty) ||
      (description != null && description!.trim().isNotEmpty) ||
      (imageUrl != null && imageUrl!.trim().isNotEmpty);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'url': url,
        'title': title,
        'description': description,
        'image_url': imageUrl,
        'site_name': siteName,
      };

  factory LinkPreview.fromJson(Map<String, dynamic> json) => LinkPreview(
        url: json['url']?.toString() ?? '',
        title: json['title']?.toString(),
        description: json['description']?.toString(),
        imageUrl: json['image_url']?.toString(),
        siteName: json['site_name']?.toString(),
      );
}
