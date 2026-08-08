import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// 行内公式文本：按 `$...$` 拆分，公式用 Math.tex 行内渲染，解析失败回退纯文本。
class LatexText extends StatelessWidget {
  const LatexText(this.text, {super.key, this.style, this.textAlign});

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  static final RegExp _latexPattern = RegExp(r'\$([^$]+)\$');

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final spans = _buildSpans(text, baseStyle);
    return Text.rich(
      TextSpan(children: spans),
      style: baseStyle,
      textAlign: textAlign,
    );
  }

  List<InlineSpan> _buildSpans(String source, TextStyle baseStyle) {
    if (!source.contains(r'$')) {
      return [TextSpan(text: source)];
    }
    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in _latexPattern.allMatches(source)) {
      if (match.start > start) {
        spans.add(TextSpan(text: source.substring(start, match.start)));
      }
      final tex = match.group(1)!.trim();
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Math.tex(
            tex,
            mathStyle: MathStyle.text,
            textStyle: baseStyle,
            onErrorFallback: (_) => Text(tex, style: baseStyle),
          ),
        ),
      );
      start = match.end;
    }
    if (start < source.length) {
      spans.add(TextSpan(text: source.substring(start)));
    }
    return spans;
  }
}
