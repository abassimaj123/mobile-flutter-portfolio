import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

final _spacingMap = {
  2.0: 'AppSpacing.xxs',
  4.0: 'AppSpacing.xs',
  8.0: 'AppSpacing.sm',
  10.0: 'AppSpacing.smPlus',
  12.0: 'AppSpacing.md',
  14.0: 'AppSpacing.mdPlus',
  16.0: 'AppSpacing.lg',
  20.0: 'AppSpacing.xl',
  24.0: 'AppSpacing.xxl',
  28.0: 'AppSpacing.xxlPlus',
  32.0: 'AppSpacing.xxxl',
};

class PreferAppSpacing extends DartLintRule {
  const PreferAppSpacing() : super(code: _code);

  static const _code = LintCode(
    name: 'prefer_app_spacing',
    problemMessage: 'Use AppSpacing token instead of hardcoded value {0}. Prefer: {1}',
    correctionMessage: 'Replace with the AppSpacing token.',
    errorSeverity: ErrorSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((node) {
      // Skip PDF files
      final imports = node.directives.whereType<ImportDirective>();
      final hasPdfImport = imports.any(
        (i) => i.uri.stringValue?.contains('package:pdf/') == true,
      );
      if (hasPdfImport) return;
    });

    context.registry.addInstanceCreationExpression((node) {
      final typeName = node.constructorName.type.name2.lexeme;
      final constructorName = node.constructorName.name?.name;

      if (typeName == 'EdgeInsets') {
        _checkEdgeInsets(node, constructorName, reporter);
      } else if (typeName == 'SizedBox') {
        _checkSizedBox(node, reporter);
      } else if (typeName == 'Gap') {
        _checkGap(node, reporter);
      }
    });
  }

  void _checkEdgeInsets(
    InstanceCreationExpression node,
    String? constructor,
    ErrorReporter reporter,
  ) {
    final args = node.argumentList.arguments;
    if (constructor == null) {
      return;
    }
    if (constructor == 'all' || constructor == 'zero') {
      if (args.length == 1) _checkArg(args[0], reporter);
    } else if (constructor == 'symmetric' || constructor == 'only') {
      for (final arg in args.whereType<NamedExpression>()) {
        _checkArg(arg.expression, reporter);
      }
    } else if (constructor == 'fromLTRB') {
      for (final arg in args) {
        _checkArg(arg, reporter);
      }
    }
  }

  void _checkSizedBox(InstanceCreationExpression node, ErrorReporter reporter) {
    for (final arg in node.argumentList.arguments.whereType<NamedExpression>()) {
      if (arg.name.label.name == 'height' || arg.name.label.name == 'width') {
        _checkArg(arg.expression, reporter);
      }
    }
  }

  void _checkGap(InstanceCreationExpression node, ErrorReporter reporter) {
    final args = node.argumentList.arguments;
    if (args.length == 1) _checkArg(args[0], reporter);
  }

  void _checkArg(Expression expr, ErrorReporter reporter) {
    double? value;
    if (expr is IntegerLiteral) {
      value = expr.value?.toDouble();
    } else if (expr is DoubleLiteral) {
      value = expr.value;
    }
    if (value == null) return;
    final token = _spacingMap[value];
    if (token != null) {
      reporter.reportErrorForNode(
        _code,
        expr,
        [value.toStringAsFixed(0), token],
      );
    }
  }
}
