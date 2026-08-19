/// Category label for overall user safety score.
enum SafetyCategory {
  excellent, // 85 - 100
  good,      // 70 - 84
  moderate,  // 50 - 69
  low,       // 0 - 49
}

/// Itemized contributing factor explaining safety score calculation.
class SafetyScoreFactor {
  const SafetyScoreFactor({
    required this.name,
    required this.impactScore, // negative for deductions, positive for bonuses
    required this.explanation,
    required this.isPositive,
  });

  final String name;
  final int impactScore;
  final String explanation;
  final bool isPositive;
}

/// Comprehensive explainable report for the dashboard & profile safety score.
class SafetyScoreReport {
  const SafetyScoreReport({
    required this.score,
    required this.category,
    required this.categoryLabel,
    required this.factors,
    required this.calculatedAt,
  });

  final int score; // [0 .. 100]
  final SafetyCategory category;
  final String categoryLabel;
  final List<SafetyScoreFactor> factors;
  final DateTime calculatedAt;
}

/// Explainable Safety Score Engine (Phase 22).
///
/// Implements transparent, deterministic multi-factor scoring:
/// - Base baseline: 100 points
/// - Night hours (22:00 - 05:00): -15 points
/// - Low battery (< 20%): -15 points; Moderate (< 40%): -5 points
/// - High risk crime / incident zone: -20 points
/// - Severe weather / low visibility: -10 points
/// - Unresolved safety incidents nearby: -10 points
class SafetyScoreCalculator {
  const SafetyScoreCalculator();

  SafetyScoreReport calculateScore({
    DateTime? currentTime,
    int batteryPercent = 100,
    bool isInHighRiskZone = false,
    bool isSevereWeather = false,
    int recentIncidentsNearby = 0,
    bool hasEmergencyContactsConfigured = true,
  }) {
    final now = currentTime ?? DateTime.now();
    int currentScore = 100;
    final List<SafetyScoreFactor> factors = [];

    // 1. Time of day factor
    final hour = now.hour;
    final isNight = hour >= 22 || hour < 5;
    if (isNight) {
      currentScore -= 15;
      factors.add(
        const SafetyScoreFactor(
          name: 'Night Hours',
          impactScore: -15,
          explanation: 'Travelling during late night hours (10 PM - 5 AM)',
          isPositive: false,
        ),
      );
    } else {
      factors.add(
        const SafetyScoreFactor(
          name: 'Daylight Visibility',
          impactScore: 0,
          explanation: 'Optimal daytime visibility and transit activity',
          isPositive: true,
        ),
      );
    }

    // 2. Battery telemetry factor
    if (batteryPercent < 20) {
      currentScore -= 15;
      factors.add(
        SafetyScoreFactor(
          name: 'Critical Battery',
          impactScore: -15,
          explanation: 'Battery at $batteryPercent% poses communication disruption risk',
          isPositive: false,
        ),
      );
    } else if (batteryPercent < 40) {
      currentScore -= 5;
      factors.add(
        SafetyScoreFactor(
          name: 'Moderate Battery',
          impactScore: -5,
          explanation: 'Battery at $batteryPercent%',
          isPositive: false,
        ),
      );
    } else {
      factors.add(
        SafetyScoreFactor(
          name: 'Healthy Battery',
          impactScore: 0,
          explanation: 'Battery at $batteryPercent% ensures sustained guardian monitoring',
          isPositive: true,
        ),
      );
    }

    // 3. Location / Crime Zone Factor
    if (isInHighRiskZone) {
      currentScore -= 20;
      factors.add(
        const SafetyScoreFactor(
          name: 'High Risk Area',
          impactScore: -20,
          explanation: 'Current location is inside a historically elevated incident zone',
          isPositive: false,
        ),
      );
    }

    // 4. Weather severity factor
    if (isSevereWeather) {
      currentScore -= 10;
      factors.add(
        const SafetyScoreFactor(
          name: 'Severe Weather',
          impactScore: -10,
          explanation: 'Heavy rain, storm, or low visibility alert in your area',
          isPositive: false,
        ),
      );
    }

    // 5. Recent incidents nearby
    if (recentIncidentsNearby > 0) {
      currentScore -= 10;
      factors.add(
        SafetyScoreFactor(
          name: 'Nearby Activity',
          impactScore: -10,
          explanation: '$recentIncidentsNearby safety alert(s) reported in 1 km radius',
          isPositive: false,
        ),
      );
    }

    // 6. Trusted contacts readiness bonus / penalty
    if (!hasEmergencyContactsConfigured) {
      currentScore -= 10;
      factors.add(
        const SafetyScoreFactor(
          name: 'No Trusted Contacts',
          impactScore: -10,
          explanation: 'No emergency contacts registered for automatic SOS escalation',
          isPositive: false,
        ),
      );
    }

    final finalScore = currentScore.clamp(0, 100);

    SafetyCategory category;
    String categoryLabel;
    if (finalScore >= 85) {
      category = SafetyCategory.excellent;
      categoryLabel = 'Excellent';
    } else if (finalScore >= 70) {
      category = SafetyCategory.good;
      categoryLabel = 'Good';
    } else if (finalScore >= 50) {
      category = SafetyCategory.moderate;
      categoryLabel = 'Moderate';
    } else {
      category = SafetyCategory.low;
      categoryLabel = 'Low';
    }

    return SafetyScoreReport(
      score: finalScore,
      category: category,
      categoryLabel: categoryLabel,
      factors: factors,
      calculatedAt: now,
    );
  }
}
