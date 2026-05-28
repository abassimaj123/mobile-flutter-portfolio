import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

final _radiusMap = {
  4.0: 'AppRadius.xs',
  6.0: 'AppRadius.sm',
  8.0: 'AppRadius.md',
  10.0: 'AppRadius.mdPlus',
  12.0: 'AppRadius.lg',
  16.0: 'AppRadius.xl',
  24.0: 'AppRadius.xxl',
  999.0: 'AppRadius.full',
};

class PreferAppRadius extends DartLintRule {
  const PreferAppRadius() : super(code: _code);

  static const _code = LintCode(
    name: 'prefer_app_radius',
    problemMessage: 'Use AppRadius token instead of hardcoded value {0}. Prefer: {1}',
    correctionMessage: 'Replace with the AppRadius token.',
    errorSeverity: ErrorSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final typeName = node.constructorName.type.name2.lexeme;
      final constructorName = node.constructorName.name?.name;

      if ((typeName == 'BorderRadius' || typeName == 'Radius') &&
          constructorName == 'circular') {
        final args = node.argumentList.arguments;
        if (args.length == 1) {
          final expr = args[0];
          double? value;
          if (expr is IntegerLiteral) value = expr.value?.toDouble();
          else if (expr is DoubleLiteral) value = expr.value;
          if (value == null) return;
          final token = _radiusMap[value];
          if (token != null) {
            reporter.reportErrorForNode(
              _code,
              expr,
              [value.toStringAsFixed(0), token],
            );
          }
        }
      }
    });
  }
}
