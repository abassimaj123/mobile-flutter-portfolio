import 'package:flutter/material.dart';
import 'package:calcwise_core/calcwise_core.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) => CalcwiseOnboarding(
        appKey: 'joboffer',
        nextScreen: const HomeScreen(),
        pages: const [
          OnboardingPage(
            icon: Icons.work_rounded,
            title: 'Compare Job Offers\nClearly',
            subtitle:
                'Net salary, benefits, RSUs — see the full picture before you decide.',
            pills: ['Net Salary', 'Benefits', 'RSUs'],
            titleFr: "Comparez les offres\nd'emploi clairement",
            subtitleFr:
                'Salaire net, avantages, RSUs — le tableau complet avant de décider.',
            pillsFr: ['Salaire net', 'Avantages', 'RSUs'],
            titleEs: 'Compara ofertas\nde trabajo claramente',
            subtitleEs:
                'Salario neto, beneficios, RSUs — el panorama completo antes de decidir.',
            pillsEs: ['Salario neto', 'Beneficios', 'RSUs'],
          ),
          OnboardingPage(
            icon: Icons.payments_rounded,
            title: 'Know What\nYou Actually Earn',
            subtitle:
                'Federal + state taxes, 401k, health insurance — all calculated.',
            pills: ['Federal Tax', 'State Tax', '401k'],
            titleFr: 'Calculez ce que\nvous gagnez vraiment',
            subtitleFr:
                'Impôts fédéraux + État, 401k, assurance santé — tout calculé.',
            pillsFr: ['Impôt fédéral', 'Impôt État', '401k'],
            titleEs: 'Conoce lo que\nrealmente ganas',
            subtitleEs:
                'Impuestos federales + estatales, 401k, seguro médico — todo calculado.',
            pillsEs: ['Impuesto federal', 'Impuesto estatal', '401k'],
          ),
          OnboardingPage(
            icon: Icons.bookmark_rounded,
            title: 'Save Your\nBest Offers',
            subtitle:
                'Your saved offers are always ready to compare — set deadlines and revisit anytime.',
            pills: ['History', 'Deadlines', 'Compare Offers'],
            titleEs: 'Guarda tus\nmejores ofertas',
            subtitleEs:
                'Tus ofertas guardadas están listas para comparar — establece plazos y consulta cuando quieras.',
            pillsEs: ['Historial', 'Fechas límite', 'Comparar ofertas'],
          ),
        ],
      );
}
