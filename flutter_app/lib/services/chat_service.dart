/// SKILL: mensaena-features
/// Chat-Helpers: Markdown-Parser, @mentions, Permalink-Builder,
/// URL-Detection. Spiegel der Web-Chat-Logik.
class ChatService {
  const ChatService._();

  /// URL-Detection RegExp (http/https mit oder ohne www).
  static final RegExp urlPattern = RegExp(
    r'https?:\/\/[^\s<>"]+',
    caseSensitive: false,
  );

  /// @mention RegExp — @username (alphanumerisch + _, mindestens 2 Zeichen).
  static final RegExp mentionPattern = RegExp(r'@([A-Za-z0-9_]{2,32})');

  /// Findet alle erwaehnten Usernames (ohne @-Prefix).
  static List<String> extractMentions(String text) {
    return mentionPattern
        .allMatches(text)
        .map((m) => m.group(1)!)
        .toSet()
        .toList();
  }

  /// Findet alle URLs in einem Text.
  static List<String> extractUrls(String text) {
    return urlPattern.allMatches(text).map((m) => m.group(0)!).toList();
  }

  /// Permalink fuer eine einzelne Nachricht.
  /// Format matched die Web-Route: /dashboard/chat?conv={id}&msg={id}
  static String messagePermalink({
    required String conversationId,
    required String messageId,
  }) {
    return '/dashboard/chat?conv=$conversationId&msg=$messageId';
  }

  /// Markdown-Light: **bold**, *italic*, ~~strike~~, `code`,
  /// ```fenced code blocks```. Liefert eine Liste von Segmenten mit
  /// Markup-Hint die der UI-Layer zu Spans rendern kann.
  static List<MarkdownSegment> parseLight(String text) {
    final segments = <MarkdownSegment>[];
    final regex = RegExp(
      r'(```[\s\S]*?```|`[^`]+`|\*\*[^*]+\*\*|\*[^*]+\*|~~[^~]+~~)',
    );
    var lastEnd = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        segments.add(
          MarkdownSegment(
          text: text.substring(lastEnd, match.start),
          style: MarkdownStyle.normal,
          ),
        );
      }
      final raw = match.group(0)!;
      if (raw.startsWith('```')) {
        segments.add(
          MarkdownSegment(
          text: raw.substring(3, raw.length - 3),
          style: MarkdownStyle.codeBlock,
          ),
        );
      } else if (raw.startsWith('`')) {
        segments.add(
          MarkdownSegment(
          text: raw.substring(1, raw.length - 1),
          style: MarkdownStyle.code,
          ),
        );
      } else if (raw.startsWith('**')) {
        segments.add(
          MarkdownSegment(
          text: raw.substring(2, raw.length - 2),
          style: MarkdownStyle.bold,
          ),
        );
      } else if (raw.startsWith('~~')) {
        segments.add(
          MarkdownSegment(
          text: raw.substring(2, raw.length - 2),
          style: MarkdownStyle.strike,
          ),
        );
      } else if (raw.startsWith('*')) {
        segments.add(
          MarkdownSegment(
          text: raw.substring(1, raw.length - 1),
          style: MarkdownStyle.italic,
          ),
        );
      }
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      segments.add(
        MarkdownSegment(
          text: text.substring(lastEnd),
          style: MarkdownStyle.normal,
        ),
      );
    }
    return segments;
  }

  /// Chat-Export als Plain-Text (fuer "Verlauf exportieren").
  static String exportConversation({
    required List<({String sender, String content, DateTime at})> messages,
    required String title,
  }) {
    final buf = StringBuffer()
      ..writeln('# $title')
      ..writeln('Exportiert am ${DateTime.now()}')
      ..writeln();
    for (final m in messages) {
      buf
        ..writeln('[${m.at.toIso8601String()}] ${m.sender}:')
        ..writeln(m.content)
        ..writeln();
    }
    return buf.toString();
  }
}

enum MarkdownStyle { normal, bold, italic, strike, code, codeBlock }

class MarkdownSegment {
  const MarkdownSegment({required this.text, required this.style});
  final String text;
  final MarkdownStyle style;
}
