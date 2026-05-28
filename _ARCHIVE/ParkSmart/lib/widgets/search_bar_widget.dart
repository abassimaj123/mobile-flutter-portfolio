import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'package:calcwise_core/calcwise_core.dart';

class SearchBarWidget extends StatefulWidget {
  final Function(String query) onSearch;
  final VoidCallback? onClear;

  const SearchBarWidget({
    super.key,
    required this.onSearch,
    this.onClear,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        _hasText = _controller.text.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(38),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.lg),
          const Icon(
            Icons.search_rounded,
            color: Color(0xFF475569),
            size: 22,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Chercher une adresse…',
                hintStyle: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: AppTextSize.bodyMd,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(
                fontSize: AppTextSize.bodyMd,
                color: AppTheme.primary,
                fontWeight: FontWeight.w500,
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  widget.onSearch(value);
                }
              },
              textInputAction: TextInputAction.search,
            ),
          ),
          if (_hasText)
            GestureDetector(
              onTap: () {
                _controller.clear();
                widget.onClear?.call();
              },
              child: const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Icon(
                  Icons.close_rounded,
                  color: Color(0xFF64748B),
                  size: 18,
                ),
              ),
            )
          else
            const SizedBox(width: AppSpacing.lg),
        ],
      ),
    );
  }
}
