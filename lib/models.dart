import 'dart:convert';

/// 用户档案模型
/// 对应表: user_profile
class UserProfile {
  final int? id;
  final String? name;
  final String? gender;
  final int? age;
  final double? height;
  final double? weight;
  final double? bodyFat;
  final String? goal;
  final String? experienceLevel;
  final int? trainingDaysPerWeek;
  final int? preferredDuration;
  final String? createdAt;

  const UserProfile({
    this.id,
    this.name,
    this.gender,
    this.age,
    this.height,
    this.weight,
    this.bodyFat,
    this.goal,
    this.experienceLevel,
    this.trainingDaysPerWeek,
    this.preferredDuration,
    this.createdAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as int?,
      name: map['name'] as String?,
      gender: map['gender'] as String?,
      age: map['age'] as int?,
      height: (map['height'] as num?)?.toDouble(),
      weight: (map['weight'] as num?)?.toDouble(),
      bodyFat: (map['body_fat'] as num?)?.toDouble(),
      goal: map['goal'] as String?,
      experienceLevel: map['experience_level'] as String?,
      trainingDaysPerWeek: map['training_days_per_week'] as int?,
      preferredDuration: map['preferred_duration'] as int?,
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'gender': gender,
      'age': age,
      'height': height,
      'weight': weight,
      'body_fat': bodyFat,
      'goal': goal,
      'experience_level': experienceLevel,
      'training_days_per_week': trainingDaysPerWeek,
      'preferred_duration': preferredDuration,
      'created_at': createdAt,
    };
  }
}

/// 用户器材模型
/// 对应表: user_equipment
class UserEquipment {
  final int? id;
  final String? equipmentType;
  final String? name;
  final bool? isAvailable;
  final double? maxWeight;
  final String? notes;

  const UserEquipment({
    this.id,
    this.equipmentType,
    this.name,
    this.isAvailable,
    this.maxWeight,
    this.notes,
  });

  factory UserEquipment.fromMap(Map<String, dynamic> map) {
    return UserEquipment(
      id: map['id'] as int?,
      equipmentType: map['equipment_type'] as String?,
      name: map['name'] as String?,
      isAvailable: (map['is_available'] as int?) == 1,
      maxWeight: (map['max_weight'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'equipment_type': equipmentType,
      'name': name,
      'is_available': isAvailable == true
          ? 1
          : (isAvailable == false ? 0 : null),
      'max_weight': maxWeight,
      'notes': notes,
    };
  }
}

/// 健身目标模型
/// 对应表: fitness_goals
class FitnessGoal {
  final int? id;
  final String? goalType;
  final double? targetValue;
  final double? currentValue;
  final String? deadline;
  final int? priority;
  final String? createdAt;

  const FitnessGoal({
    this.id,
    this.goalType,
    this.targetValue,
    this.currentValue,
    this.deadline,
    this.priority,
    this.createdAt,
  });

  factory FitnessGoal.fromMap(Map<String, dynamic> map) {
    return FitnessGoal(
      id: map['id'] as int?,
      goalType: map['goal_type'] as String?,
      targetValue: (map['target_value'] as num?)?.toDouble(),
      currentValue: (map['current_value'] as num?)?.toDouble(),
      deadline: map['deadline'] as String?,
      priority: map['priority'] as int?,
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'goal_type': goalType,
      'target_value': targetValue,
      'current_value': currentValue,
      'deadline': deadline,
      'priority': priority,
      'created_at': createdAt,
    };
  }
}

/// 健身目标模型（SettingsPage使用的简化版本）
class FitnessGoals {
  String type;
  double targetValue;
  double? currentValue;
  String? unit;
  String? deadline;

  FitnessGoals({
    required this.type,
    required this.targetValue,
    this.currentValue,
    this.unit,
    this.deadline,
  });

  factory FitnessGoals.fromJson(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return FitnessGoals(
      type: map['type'] as String? ?? 'muscle_gain',
      targetValue: (map['targetValue'] as num?)?.toDouble() ?? 0,
      currentValue: (map['currentValue'] as num?)?.toDouble(),
      unit: map['unit'] as String?,
      deadline: map['deadline'] as String?,
    );
  }

  String toJson() {
    return jsonEncode({
      'type': type,
      'targetValue': targetValue,
      'currentValue': currentValue,
      'unit': unit,
      'deadline': deadline,
    });
  }
}

/// 训练历史模型
/// 对应表: training_history
class TrainingHistory {
  final int? id;
  final bool? hasGymExperience;
  final double? yearsExperience;
  final String? previousRoutine;
  final Map<String, dynamic>? maxLiftsJson;
  final String? injuries;
  final String? createdAt;

  // 以下字段用于AI分析，不存储在数据库中
  final int? totalWorkouts;
  final double? totalVolume;
  final int? years;

  const TrainingHistory({
    this.id,
    this.hasGymExperience,
    this.yearsExperience,
    this.previousRoutine,
    this.maxLiftsJson,
    this.injuries,
    this.createdAt,
    this.totalWorkouts,
    this.totalVolume,
    this.years,
  });

  factory TrainingHistory.fromMap(Map<String, dynamic> map) {
    return TrainingHistory(
      id: map['id'] as int?,
      hasGymExperience: (map['has_gym_experience'] as int?) == 1,
      yearsExperience: (map['years_experience'] as num?)?.toDouble(),
      previousRoutine: map['previous_routine'] as String?,
      maxLiftsJson: map['max_lifts_json'] != null
          ? jsonDecode(map['max_lifts_json'] as String) as Map<String, dynamic>
          : null,
      injuries: map['injuries'] as String?,
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'has_gym_experience': hasGymExperience == true
          ? 1
          : (hasGymExperience == false ? 0 : null),
      'years_experience': yearsExperience,
      'previous_routine': previousRoutine,
      'max_lifts_json': maxLiftsJson != null ? jsonEncode(maxLiftsJson) : null,
      'injuries': injuries,
      'created_at': createdAt,
    };
  }
}

/// 动作模型
/// 对应表: exercises
class Exercise {
  final int? id;
  final String? name;
  final String? targetMuscle;
  final String? equipmentType;
  final int? difficulty;
  final String? description;
  final String? svgData;
  final String? localVideoPath;
  final String? alternativeIds;
  final double? defaultWeight;
  final int? defaultSets;
  final int? defaultReps;
  final int? restSeconds;

  const Exercise({
    this.id,
    this.name,
    this.targetMuscle,
    this.equipmentType,
    this.difficulty,
    this.description,
    this.svgData,
    this.localVideoPath,
    this.alternativeIds,
    this.defaultWeight,
    this.defaultSets,
    this.defaultReps,
    this.restSeconds,
  });

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'] as int?,
      name: map['name'] as String?,
      targetMuscle: map['target_muscle'] as String?,
      equipmentType: map['equipment_type'] as String?,
      difficulty: (map['difficulty'] as num?)?.toInt(),
      description: map['description'] as String?,
      svgData: map['svg_data'] as String?,
      localVideoPath: map['local_video_path'] as String?,
      alternativeIds: map['alternative_ids'] as String?,
      defaultWeight: (map['default_weight'] as num?)?.toDouble(),
      defaultSets: (map['default_sets'] as num?)?.toInt(),
      defaultReps: (map['default_reps'] as num?)?.toInt(),
      restSeconds: (map['rest_seconds'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'target_muscle': targetMuscle,
      'equipment_type': equipmentType,
      'difficulty': difficulty,
      'description': description,
      'svg_data': svgData,
      'local_video_path': localVideoPath,
      'alternative_ids': alternativeIds,
      'default_weight': defaultWeight,
      'default_sets': defaultSets,
      'default_reps': defaultReps,
      'rest_seconds': restSeconds,
    };
  }

  /// 获取目标组数（别名）
  int get targetSets => defaultSets ?? 3;

  /// 获取目标次数（别名）
  int get targetReps => defaultReps ?? 10;

  /// 获取目标重量（别名）
  double get targetWeight => defaultWeight ?? 0;

  /// 获取默认休息秒数（别名）
  int get defaultRestSeconds => restSeconds ?? 90;
}

/// 训练计划模型
/// 对应表: training_plans
class WorkoutPlan {
  final int? id;
  final String? date;
  final String? dayType;
  final int? locationId;
  final String? exercises;
  final String? status;
  final int? totalExercises;
  final int? estimatedDuration;
  final int? caloriesBurned;
  final String? notes;
  final bool? generatedByAi;
  final String? createdAt;

  const WorkoutPlan({
    this.id,
    this.date,
    this.dayType,
    this.locationId,
    this.exercises,
    this.status,
    this.totalExercises,
    this.estimatedDuration,
    this.caloriesBurned,
    this.notes,
    this.generatedByAi,
    this.createdAt,
  });

  factory WorkoutPlan.fromMap(Map<String, dynamic> map) {
    return WorkoutPlan(
      id: map['id'] as int?,
      date: map['date'] as String?,
      dayType: map['day_type'] as String?,
      locationId: map['location_id'] as int?,
      exercises: map['exercises'] as String?,
      status: map['status'] as String?,
      totalExercises: map['total_exercises'] as int?,
      estimatedDuration: map['estimated_duration'] as int?,
      caloriesBurned: map['calories_burned'] as int?,
      notes: map['notes'] as String?,
      generatedByAi: (map['generated_by_ai'] as int?) == 1,
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'day_type': dayType,
      'location_id': locationId,
      'exercises': exercises,
      'status': status,
      'total_exercises': totalExercises,
      'estimated_duration': estimatedDuration,
      'calories_burned': caloriesBurned,
      'notes': notes,
      'generated_by_ai': generatedByAi == true
          ? 1
          : (generatedByAi == false ? 0 : null),
      'created_at': createdAt,
    };
  }
}

/// 训练记录模型
/// 对应表: workout_logs
class WorkoutLog {
  final int? id;
  final int? planId;
  final int? exerciseId;
  final String? date;
  final bool? completed;
  final double? actualWeight;
  final int? actualSets;
  final List<dynamic>? actualRepsJson;
  final int? restTaken;
  final int? caloriesEstimated;
  final String? feelingNotes;
  final String? createdAt;

  const WorkoutLog({
    this.id,
    this.planId,
    this.exerciseId,
    this.date,
    this.completed,
    this.actualWeight,
    this.actualSets,
    this.actualRepsJson,
    this.restTaken,
    this.caloriesEstimated,
    this.feelingNotes,
    this.createdAt,
  });

  factory WorkoutLog.fromMap(Map<String, dynamic> map) {
    return WorkoutLog(
      id: map['id'] as int?,
      planId: map['plan_id'] as int?,
      exerciseId: map['exercise_id'] as int?,
      date: map['date'] as String?,
      completed: (map['completed'] as int?) == 1,
      actualWeight: (map['actual_weight'] as num?)?.toDouble(),
      actualSets: map['actual_sets'] as int?,
      actualRepsJson: map['actual_reps_json'] != null
          ? jsonDecode(map['actual_reps_json'] as String) as List<dynamic>
          : null,
      restTaken: map['rest_taken'] as int?,
      caloriesEstimated: map['calories_estimated'] as int?,
      feelingNotes: map['feeling_notes'] as String?,
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'plan_id': planId,
      'exercise_id': exerciseId,
      'date': date,
      'completed': completed == true
          ? 1
          : (completed == false ? 0 : null),
      'actual_weight': actualWeight,
      'actual_sets': actualSets,
      'actual_reps_json': actualRepsJson != null
          ? jsonEncode(actualRepsJson)
          : null,
      'rest_taken': restTaken,
      'calories_estimated': caloriesEstimated,
      'feeling_notes': feelingNotes,
      'created_at': createdAt,
    };
  }
}

/// 身体指标模型
/// 对应表: body_metrics
class BodyMetrics {
  final int? id;
  final String? date;
  final double? weight;
  final double? bodyFat;
  final double? muscleMass;
  final String? notes;
  final String? createdAt;

  const BodyMetrics({
    this.id,
    this.date,
    this.weight,
    this.bodyFat,
    this.muscleMass,
    this.notes,
    this.createdAt,
  });

  factory BodyMetrics.fromMap(Map<String, dynamic> map) {
    return BodyMetrics(
      id: map['id'] as int?,
      date: map['date'] as String?,
      weight: (map['weight'] as num?)?.toDouble(),
      bodyFat: (map['body_fat'] as num?)?.toDouble(),
      muscleMass: (map['muscle_mass'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'weight': weight,
      'body_fat': bodyFat,
      'muscle_mass': muscleMass,
      'notes': notes,
      'created_at': createdAt,
    };
  }
}

/// 每日状态模型
/// 对应表: daily_status
class DailyStatus {
  final int? id;
  final String? date;
  final String? status;
  final int? energyLevel;
  final double? sleepHours;
  final String? notes;

  const DailyStatus({
    this.id,
    this.date,
    this.status,
    this.energyLevel,
    this.sleepHours,
    this.notes,
  });

  factory DailyStatus.fromMap(Map<String, dynamic> map) {
    return DailyStatus(
      id: map['id'] as int?,
      date: map['date'] as String?,
      status: map['status'] as String?,
      energyLevel: map['energy_level'] as int?,
      sleepHours: (map['sleep_hours'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'status': status,
      'energy_level': energyLevel,
      'sleep_hours': sleepHours,
      'notes': notes,
    };
  }
}

/// 卡路里记录模型
/// 对应表: calorie_records
class CalorieRecord {
  final int? id;
  final String? date;
  final String? type;
  final String? category;
  final int? amount;
  final String? notes;

  const CalorieRecord({
    this.id,
    this.date,
    this.type,
    this.category,
    this.amount,
    this.notes,
  });

  factory CalorieRecord.fromMap(Map<String, dynamic> map) {
    return CalorieRecord(
      id: map['id'] as int?,
      date: map['date'] as String?,
      type: map['type'] as String?,
      category: map['category'] as String?,
      amount: map['amount'] as int?,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'type': type,
      'category': category,
      'amount': amount,
      'notes': notes,
    };
  }
}

/// 训练环境模型
/// 对应表: environments
class Environment {
  final int? id;
  final String? name;
  final String? description;
  final String? createdAt;

  const Environment({
    this.id,
    this.name,
    this.description,
    this.createdAt,
  });

  factory Environment.fromMap(Map<String, dynamic> map) {
    return Environment(
      id: map['id'] as int?,
      name: map['name'] as String?,
      description: map['description'] as String?,
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'created_at': createdAt,
    };
  }
}

// ========== 训练执行辅助模型 ==========

/// 单组训练数据
class WorkoutSet {
  final int setNumber;
  final int? targetReps;
  int? actualReps;
  bool completed;
  double? rpe;

  WorkoutSet({
    required this.setNumber,
    this.targetReps,
    this.actualReps,
    this.completed = false,
    this.rpe,
  });
}

/// 单个动作的训练记录
class ExerciseRecord {
  final Exercise exercise;
  final List<WorkoutSet> sets;
  double? weight;

  ExerciseRecord({
    required this.exercise,
    required this.sets,
    this.weight,
  });
}

/// 训练完成统计摘要
class WorkoutSummary {
  final Duration totalDuration;
  final double totalVolume;
  final int completedExercises;
  final int totalSets;
  final double averageRpe;
  final int estimatedCalories;

  WorkoutSummary({
    required this.totalDuration,
    required this.totalVolume,
    required this.completedExercises,
    required this.totalSets,
    required this.averageRpe,
    required this.estimatedCalories,
  });
}
