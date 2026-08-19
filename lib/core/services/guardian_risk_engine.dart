/// Qualitative Risk Level category.
enum RiskLevelCategory {
  low,
  moderate,
  high,
  critical,
}

/// Itemized explainable risk factor contribution.
class RiskFactorExplanation {
  const RiskFactorExplanation({
    required this.name,
    required this.percentageContribution,
    required this.description,
  });

  final String name;
  final int percentageContribution; // e.g. 15 for +15%
  final String description; // e.g. "Walking after 11 PM (+15%)"
}

/// Complete explainable risk assessment report.
class RiskAssessmentReport {
  const RiskAssessmentReport({
    required this.overallRiskPercent,
    required this.riskCategory,
    required this.factors,
    required this.timestamp,
    required this.recommendation,
  });

  final int overallRiskPercent;
  final RiskLevelCategory riskCategory;
  final List<RiskFactorExplanation> factors;
  final DateTime timestamp;
  final String recommendation;

  String get categoryLabel {
    switch (riskCategory) {
      case RiskLevelCategory.low:
        return 'LOW';
      case RiskLevelCategory.moderate:
        return 'MODERATE';
      case RiskLevelCategory.high:
        return 'HIGH';
      case RiskLevelCategory.critical:
        return 'CRITICAL';
    }
  }

  factory RiskAssessmentReport.baseline() {
    return RiskAssessmentReport(
      overallRiskPercent: 12,
      riskCategory: RiskLevelCategory.low,
      factors: const [
        RiskFactorExplanation(
          name: 'Baseline Monitoring',
          percentageContribution: 12,
          description: 'Normal daylight baseline activity (+12%)',
        ),
      ],
      timestamp: DateTime.now(),
      recommendation: 'Conditions normal. Standard passive monitoring active.',
    );
  }
}

/// Centralized Guardian Risk Engine.
///
/// Evaluates and fuses 8 distinct physical and situational signals:
/// 1. Time of day (night/late hours after 11 PM: +15%)
/// 2. Location safety score (area safety zone rating: +10% to +25%)
/// 3. Route corridor deviation (>50m off route: +25%)
/// 4. Stationary duration (>180s stationary on route: +15%)
/// 5. Kinematic motion anomaly (fall candidate/impact: +20% to +35%)
/// 6. Voice distress score (distress keyword/vocal panic: +25% to +40%)
/// 7. Battery level (<15% battery: +12%)
/// 8. Weather severity (rain/storm: +10%)
class GuardianRiskEngine {
  const GuardianRiskEngine();

  /// Calculate explainable multi-signal risk report.
  RiskAssessmentReport evaluateRisk({
    DateTime? currentTime,
    double? locationSafetyScore, // [0 .. 100], 100 = safest
    double? routeDeviationMeters, // meters off planned corridor
    int stationarySeconds = 0, // seconds standing still during trip
    bool hasMotionAnomaly = false,
    double motionAnomalyPeak = 0.0,
    bool hasVoiceDistress = false,
    String? voiceUrgency, // 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'
    int batteryPercent = 100,
    String? weatherCondition, // 'Rain', 'Storm', 'Thunderstorm', 'Clear'
    String? roadName,
  }) {
    final now = currentTime ?? DateTime.now();
    final factors = <RiskFactorExplanation>[];
    int totalRisk = 0;

    // 1. TIME OF DAY
    final hour = now.hour;
    if (hour >= 23 || hour < 4) {
      factors.add(const RiskFactorExplanation(
        name: 'Late Night Travel',
        percentageContribution: 15,
        description: 'Walking after 11 PM (+15%)',
      ));
      totalRisk += 15;
    } else if (hour >= 20 || hour < 6) {
      factors.add(const RiskFactorExplanation(
        name: 'Night Hours',
        percentageContribution: 10,
        description: 'Night time travel after 8 PM (+10%)',
      ));
      totalRisk += 10;
    }

    // 2. LOCATION SAFETY SCORE
    if (locationSafetyScore != null && locationSafetyScore < 60) {
      final penalty = locationSafetyScore < 40 ? 20 : 12;
      factors.add(RiskFactorExplanation(
        name: 'Elevated Area Risk',
        percentageContribution: penalty,
        description: 'Safety score in ${roadName ?? "area"} is ${locationSafetyScore.toStringAsFixed(0)}/100 (+$penalty%)',
      ));
      totalRisk += penalty;
    }

    // 3. ROUTE DEVIATION
    if (routeDeviationMeters != null && routeDeviationMeters > 50) {
      final penalty = routeDeviationMeters > 120 ? 25 : 15;
      factors.add(RiskFactorExplanation(
        name: 'Route Deviation',
        percentageContribution: penalty,
        description: 'Off safe route by ${routeDeviationMeters.toStringAsFixed(0)}m (+$penalty%)',
      ));
      totalRisk += penalty;
    }

    // 4. STATIONARY TOO LONG
    if (stationarySeconds > 180) {
      factors.add(RiskFactorExplanation(
        name: 'Extended Immobility',
        percentageContribution: 15,
        description: 'Stationary for ${(stationarySeconds / 60).toStringAsFixed(0)} mins during transit (+15%)',
      ));
      totalRisk += 15;
    }

    // 5. MOTION ANOMALY (From Phase 3)
    if (hasMotionAnomaly) {
      final penalty = motionAnomalyPeak > 24.0 ? 30 : 20;
      factors.add(RiskFactorExplanation(
        name: 'Kinematic Anomaly',
        percentageContribution: penalty,
        description: 'High impact movement spike recorded (+$penalty%)',
      ));
      totalRisk += penalty;
    }

    // 6. VOICE DISTRESS (From Phase 4)
    if (hasVoiceDistress) {
      final isCritical = voiceUrgency == 'CRITICAL' || voiceUrgency == 'HIGH';
      final penalty = isCritical ? 35 : 20;
      factors.add(RiskFactorExplanation(
        name: 'Voice Distress',
        percentageContribution: penalty,
        description: 'Distress phrase acoustic trigger detected (+$penalty%)',
      ));
      totalRisk += penalty;
    }

    // 7. BATTERY LEVEL
    if (batteryPercent < 15) {
      factors.add(RiskFactorExplanation(
        name: 'Critical Battery',
        percentageContribution: 12,
        description: 'Battery at $batteryPercent% (+12%)',
      ));
      totalRisk += 12;
    } else if (batteryPercent < 25) {
      factors.add(RiskFactorExplanation(
        name: 'Low Battery',
        percentageContribution: 6,
        description: 'Battery at $batteryPercent% (+6%)',
      ));
      totalRisk += 6;
    }

    // 8. WEATHER SEVERITY
    final weatherLower = weatherCondition?.toLowerCase() ?? '';
    if (weatherLower.contains('storm') || weatherLower.contains('thunder')) {
      factors.add(const RiskFactorExplanation(
        name: 'Severe Weather',
        percentageContribution: 15,
        description: 'Severe storm warning detected (+15%)',
      ));
      totalRisk += 15;
    } else if (weatherLower.contains('rain') || weatherLower.contains('drizzle')) {
      factors.add(const RiskFactorExplanation(
        name: 'Rain Warning',
        percentageContribution: 10,
        description: 'Rain detected (+10%)',
      ));
      totalRisk += 10;
    }

    // Baseline minimum if factors are clear
    if (factors.isEmpty) {
      factors.add(const RiskFactorExplanation(
        name: 'Normal Baseline',
        percentageContribution: 8,
        description: 'Passive baseline monitoring (+8%)',
      ));
      totalRisk = 8;
    }

    final finalRiskPercent = totalRisk.clamp(5, 100);

    // Classify qualitative category
    RiskLevelCategory category;
    String recommendation;

    if (finalRiskPercent >= 75) {
      category = RiskLevelCategory.critical;
      recommendation = 'Critical safety risk. Emergency verification active.';
    } else if (finalRiskPercent >= 50) {
      category = RiskLevelCategory.high;
      recommendation = 'Elevated situational risk. Stay on illuminated main roads.';
    } else if (finalRiskPercent >= 25) {
      category = RiskLevelCategory.moderate;
      recommendation = 'Moderate risk detected. Guardian Mode monitoring active.';
    } else {
      category = RiskLevelCategory.low;
      recommendation = 'Low risk. Conditions appear safe.';
    }

    return RiskAssessmentReport(
      overallRiskPercent: finalRiskPercent,
      riskCategory: category,
      factors: factors,
      timestamp: now,
      recommendation: recommendation,
    );
  }
}
