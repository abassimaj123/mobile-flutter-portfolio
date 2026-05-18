import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'rules/prefer_app_radius.dart';
import 'rules/prefer_app_spacing.dart';
import 'rules/prefer_semantic_colors.dart';

PluginBase createPlugin() => _CalcwiseLintPlugin();

class _CalcwiseLintPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
    PreferAppSpacing(),
    PreferAppRadius(),
    PreferSemanticColors(),
  ];
}
