import 'package:flutter/material.dart';

import '../app_theme.dart';

enum LoanApplicationStep { details, participants, documents, review }

class LoanProgressIndicator extends StatelessWidget {
  final int currentStep;
  final List<String> stages;
  final bool participantsDemo;
  final bool previewOnly;
  final bool hasParticipants;

  const LoanProgressIndicator({
    super.key,
    required this.currentStep,
    this.stages = const ['Loan Details', 'Documents', 'Review'],
    this.participantsDemo = false,
    this.previewOnly = false,
    this.hasParticipants = false,
  });

  factory LoanProgressIndicator.forApplication(
    LoanApplicationStep step, {
    required bool participantsDemo,
    bool previewOnly = false,
    bool hasParticipants = false,
  }) {
    if (participantsDemo || previewOnly || hasParticipants) {
      return LoanProgressIndicator(
        currentStep: step.index,
        stages: const ['Loan Details', 'Participants', 'Documents', 'Review'],
        participantsDemo: participantsDemo,
        previewOnly: previewOnly,
        hasParticipants: hasParticipants,
      );
    }
    assert(
      step != LoanApplicationStep.participants,
      'A participants step requires a participant workflow.',
    );
    return LoanProgressIndicator(
      currentStep: step == LoanApplicationStep.details ? 0 : step.index - 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeline = LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          for (var step = 0; step < stages.length; step++) ...[
            if (step > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: currentStep >= step - 1
                      ? AppTheme.primaryGreen
                      : const Color(0xFFE0E0E0),
                ),
              ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth / stages.length,
              ),
              child: _buildStep(stages[step], step, currentStep),
            ),
          ],
        ],
      ),
    );
    if (!participantsDemo && !previewOnly && !hasParticipants) return timeline;
    return Column(
      children: [
        Text(
          previewOnly
              ? 'Updated application review'
              : participantsDemo
              ? 'Participant selection demo'
              : 'Co-maker consent workflow',
          style: AppTheme.captionBold,
        ),
        const SizedBox(height: AppTheme.spacingS),
        timeline,
      ],
    );
  }

  Widget _buildStep(String label, int step, int currentStep) {
    final isActive = step == currentStep;
    final isCompleted = step < currentStep;

    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isActive || isCompleted
                ? AppTheme.primaryGreen
                : const Color(0xFFE0E0E0),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    '${step + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive || isCompleted
                ? AppTheme.primaryGreen
                : const Color(0xFF7D8A82),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
