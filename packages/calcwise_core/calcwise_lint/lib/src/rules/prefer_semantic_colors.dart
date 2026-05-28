import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

const _problematicColors = {
  'green', 'red', 'orange', 'yellow', 'amber', 'teal', 'cyan', 'pink',
  'purple', 'deepOrange', 'lightGreen',
};

class PreferSemanticColors extends DartLintRule {
  const PreferSemanticColors() : super(code: _code);

  static const _code = LintCode(
    name: 'prefer_semantic_colors',
    problemMessage: 'Use CalcwiseSemanticColors or CalcwiseTheme.of(context) instead of raw Colors.{0}',
    correctionMessage: 'Replace with a semantic color token from CalcwiseSemanticColors.',
    errorSeverity: ErrorSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPrefixedIdentifier((node) {
      if (node.prefix.name == 'Colors' &&
          _problematicColors.contains(node.identifier.name)) {
        reporter.reportErrorForNode(_code, node, [node.identifier.name]);
      }
    });
  }
}
