import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:webview_flutter/webview_flutter.dart';

class LegalWebScreen extends StatefulWidget {
  const LegalWebScreen({
    super.key,
    required this.title,
    required this.url,
  });

  final String title;
  final String url;

  @override
  State<LegalWebScreen> createState() => _LegalWebScreenState();
}

class _LegalWebScreenState extends State<LegalWebScreen> {
  late final WebViewController _controller;
  int _loadingProgress = 0;

  @override
  void initState() {
    super.initState();
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onProgress:
                  (progress) =>
                      setState(() => _loadingProgress = progress),
            ),
          )
          ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? colors.bg : const Color(0xFFFFFBF7),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                dims.scaleWidth(8),
                dims.scaleSpace(8),
                dims.scaleWidth(16),
                dims.scaleSpace(8),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: dims.scaleText(20),
                      color: isDark ? colors.textPrimary : const Color(0xFF2D170F),
                    ),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontFamily: AppTheme.headingFontFamily,
                        fontSize: dims.scaleText(18),
                        fontWeight: FontWeight.w700,
                        color: isDark ? colors.textPrimary : const Color(0xFF2D170F),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_loadingProgress < 100)
              LinearProgressIndicator(
                value: _loadingProgress / 100,
                minHeight: 2,
                backgroundColor: Colors.transparent,
                color: const Color(0xFFFF8A4C),
              ),
            Expanded(
              child: WebViewWidget(controller: _controller),
            ),
          ],
        ),
      ),
    );
  }
}
