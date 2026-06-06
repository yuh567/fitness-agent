import 'dart:convert';
import 'database/db_helper.dart';
import 'models.dart';
import 'utils.dart';

/// AI计划引擎：根据用户档案、历史记录和可用器材生成每日训练计划
class PlanEngine {
  final db = DBHelper.instance;
  bool _schemaChecked = false;

  /// 确保数据库Schema包含计划引擎所需的扩展列
  Future<void> _ensureSchema() async {
    if (_schemaChecked) return;
    final database = await db.database;

    // 为 training_plans 添加缺失列
    await _safeAddColumn(database, 'training_plans', 'date', 'TEXT');
    await _safeAddColumn(database, 'training_plans', 'day_type', 'TEXT');
    await _safeAddColumn(database, 'training_plans', 'location_id', 'INTEGER');
    await _safeAddColumn(database, 'training_plans', 'exercises', 'TEXT');
    await _safeAddColumn(database, 'training_plans', 'status', 'TEXT');

    // 为 environments 添加缺失列
    await _safeAddColumn(database, 'environments', 'location_type', 'TEXT');
    await _safeAddColumn(database, 'environments', 'equipment_list', 'TEXT');
    await _safeAddColumn(database, 'environments', 'default_weights', 'TEXT');
    await _safeAddColumn(database, 'environments', 'is_default', 'INTEGER DEFAULT 0');

    // 为 exercises 添加缺失列
    await _safeAddColumn(database, 'exercises', 'target_muscle', 'TEXT');
    await _safeAddColumn(database, 'exercises', 'equipment_type', 'TEXT');
    await _safeAddColumn(database, 'exercises', 'default_weight', 'REAL');
    await _safeAddColumn(database, 'exercises', 'default_sets', 'INTEGER');
    await _safeAddColumn(database, 'exercises', 'default_reps', 'INTEGER');
    await _safeAddColumn(database, 'exercises', 'rest_seconds', 'INTEGER');

    // 为 absence_records 添加缺失列
    await _safeAddColumn(database, 'absence_records', 'auto_flag', 'INTEGER');
    await _safeAddColumn(database, 'absence_records', 'planned_day_type', 'TEXT');

    _schemaChecked = true;
  }

  Future<void> _safeAddColumn(Database database, String table, String column, String type) async {
    try {
      await database.rawQuery('ALTER TABLE $table ADD COLUMN $column $type');
    } catch (_) {}
  }

  /// 生成今日计划
  Future<Map<String, dynamic>?> generateTodayPlan(int locationId, DateTime date) async {
    await _ensureSchema();
    final database = await db.database;

    final envList = await database.query('environments', where: 'id = ?', whereArgs: [locationId]);
    if (envList.isEmpty) return null;
    final env = envList.first;

    List<String> equipment = ['自重'];
    final equipRaw = env['equipment_list'];
    if (equipRaw != null && equipRaw is String && equipRaw.isNotEmpty) {
      try {
        equipment = List<String>.from(jsonDecode(equipRaw));
      } catch (_) {}
    }

    final profile = await db.getUserProfile();
    final split = determineSplit(profile, null);
    final trainingDays = profile?.trainingDaysPerWeek ?? 4;
    final dayType = getDayTypeForSplit(split, date, trainingDays);

    if (dayType == 'rest') {
      return {
        'date': formatDate(date),
        'day_type': 'rest',
        'location_id': locationId,
        'exercises': '[]',
        'status': 'rest',
        'message': '今日休息，肌肉在生长',
        'total_exercises': 0,
        'estimated_duration': 0,
        'calories_burned': 0,
      };
    }

    if (dayType == 'cardio') {
      return {
        'date': formatDate(date),
        'day_type': 'cardio',
        'location_id': locationId,
        'exercises': '[]',
        'status': 'pending',
        'message': '有氧日',
        'total_exercises': 0,
        'estimated_duration': 30,
        'calories_burned': 200,
      };
    }

    final selected = await selectExercises(dayType, equipment, 6, db);
    if (selected.isEmpty) {
      return {
        'date': formatDate(date),
        'day_type': dayType,
        'location_id': locationId,
        'exercises': '[]',
        'status': 'pending',
        'message': '当前地点无可用器械完成训练',
        'total_exercises': 0,
        'estimated_duration': 0,
        'calories_burned': 0,
      };
    }

    final bodyWeight = profile?.weight ?? 70.0;
    final exercisesWithDetails = <Map<String, dynamic>>[];
    int totalDuration = 10;

    for (var ex in selected) {
      final exercise = Exercise.fromMap(ex);
      final weight = await calculateWeight(exercise, profile, db);
      final sets = (ex['default_sets'] as num?)?.toInt() ?? (ex['defaultSets'] as num?)?.toInt() ?? 3;
      final reps = (ex['default_reps'] as num?)?.toInt() ?? (ex['defaultReps'] as num?)?.toInt() ?? 10;
      final rest = (ex['rest_seconds'] as num?)?.toInt() ?? (ex['restSeconds'] as num?)?.toInt() ?? 60;

      totalDuration += (sets * (rest + 45)) ~/ 60;

      exercisesWithDetails.add({
        ...ex,
        'target_weight': weight,
        'target_sets': sets,
        'target_reps': reps,
        'targetSets': sets,
        'targetReps': reps,
        'targetWeight': weight,
        'defaultRestSeconds': rest,
        'adjustment_note': '基于历史记录计算',
      });
    }

    final calories = estimateCalories(exercisesWithDetails, bodyWeight, totalDuration);

    final plan = {
      'date': formatDate(date),
      'day_type': dayType,
      'location_id': locationId,
      'exercises': jsonEncode(exercisesWithDetails),
      'status': 'pending',
      'total_exercises': exercisesWithDetails.length,
      'estimated_duration': totalDuration,
      'calories_burned': calories,
      'notes': '${getSplitName(dayType)} - ${getSplitName(split)}分化',
      'generated_by_ai': 1,
    };

    await database.delete('training_plans', where: 'date = ?', whereArgs: [formatDate(date)]);
    final planId = await database.insert('training_plans', plan);
    plan['id'] = planId;
    return plan;
  }

  /// 根据用户数据决定训练分化
  /// 新手3天→Full Body, 中级4天→Upper/Lower, 高级5-6天→Push/Pull/Legs
  String determineSplit(UserProfile? profile, List<Map<String, dynamic>>? history) {
    final days = profile?.trainingDaysPerWeek ?? 4;
    final level = profile?.experienceLevel ?? 'intermediate';

    if (days <= 3 || level == 'beginner' || level == '新手' || level == '新手铁匠') {
      return 'full';
    }
    if (days == 4) {
      return 'upper_lower';
    }
    return 'push_pull_legs';
  }

  /// 根据日期和分化确定当日类型
  String getDayTypeForSplit(String split, DateTime date, int trainingDays) {
    final weekday = date.weekday; // 1=周一, 7=周日

    switch (split) {
      case 'full':
        // 3天全身：周一、三、五训练，其他休息
        if (weekday == 1 || weekday == 3 || weekday == 5) return 'full';
        return 'rest';
      case 'upper_lower':
        // 4天上/下肢：周一上肢、周二下肢、周四上肢、周五下肢
        if (weekday == 1 || weekday == 4) return 'upper';
        if (weekday == 2 || weekday == 5) return 'lower';
        return 'rest';
      case 'push_pull_legs':
        if (trainingDays >= 6) {
          // 6天 PPL：周一推、周二拉、周三腿、周四推、周五拉、周六腿、周日休息
          if (weekday == 1 || weekday == 4) return 'push';
          if (weekday == 2 || weekday == 5) return 'pull';
          if (weekday == 3 || weekday == 6) return 'legs';
          return 'rest';
        } else {
          // 5天 PPL：周一推、周二拉、周三腿、周五推、周六拉、周日休息
          if (weekday == 1) return 'push';
          if (weekday == 2) return 'pull';
          if (weekday == 3) return 'legs';
          if (weekday == 5) return 'push';
          if (weekday == 6) return 'pull';
          return 'rest';
        }
      default:
        return 'rest';
    }
  }

  /// 选择动作（根据可用器材和目标肌群）
  /// 主项2-3个复合动作 + 辅项3-5个
  Future<List<Map<String, dynamic>>> selectExercises(
    String dayType, List<String> availableEquipment, int count, DBHelper db) async {
    final database = await db.database;
    final allExercises = await database.query('exercises');

    final pushMuscles = ['胸大肌', '胸大肌上部', '胸大肌下部', '三角肌前束', '三角肌中束', '肱三头肌', '肩部', '胸部'];
    final pullMuscles = ['背阔肌', '竖脊肌', '斜方肌', '肱二头肌', '肱肌/肱桡肌', '三角肌后束', '背部', '手臂'];
    final legsMuscles = ['股四头肌', '腘绳肌', '臀大肌', '小腿腓肠肌', '小腿比目鱼肌', '腿部'];
    final cardioMuscles = ['心肺', '全身', '心肺/下肢', '心肺/全身', '心肺/背腿'];
    final coreMuscles = ['腹横肌', '腹直肌', '腹斜肌', '腹部', '核心'];

    bool matchesDayType(String? muscleGroup) {
      if (muscleGroup == null) return false;
      final mg = muscleGroup;
      switch (dayType) {
        case 'push':
          return pushMuscles.any((m) => mg.contains(m));
        case 'pull':
          return pullMuscles.any((m) => mg.contains(m));
        case 'legs':
          return legsMuscles.any((m) => mg.contains(m));
        case 'cardio':
          return cardioMuscles.any((m) => mg.contains(m));
        case 'core':
          return coreMuscles.any((m) => mg.contains(m));
        case 'upper':
          return pushMuscles.any((m) => mg.contains(m)) || pullMuscles.any((m) => mg.contains(m));
        case 'lower':
          return legsMuscles.any((m) => mg.contains(m));
        case 'full':
          return true;
        default:
          return false;
      }
    }

    bool hasEquipment(String? equipment) {
      if (equipment == null) return false;
      final eq = equipment.toLowerCase();
      if (eq == '自重' || eq == 'bodyweight') return true;
      return availableEquipment.any((ae) {
        final ael = ae.toLowerCase();
        return eq.contains(ael) || ael.contains(eq);
      });
    }

    final candidates = allExercises.where((e) {
      final muscle = e['muscle_group'] as String? ?? e['target_muscle'] as String?;
      final equip = e['equipment'] as String? ?? e['equipment_type'] as String?;
      return matchesDayType(muscle) && hasEquipment(equip);
    }).toList();

    if (candidates.isEmpty) return [];

    // 按难度降序排列，优先复合动作
    candidates.sort((a, b) {
      final diffA = (a['difficulty'] as num?)?.toInt() ?? 0;
      final diffB = (b['difficulty'] as num?)?.toInt() ?? 0;
      return diffB.compareTo(diffA);
    });

    final mainCount = count <= 5 ? 2 : 3;
    final mainExercises = candidates.take(mainCount).toList();
    final remaining = candidates.where((c) => !mainExercises.any((m) => m['id'] == c['id'])).toList();
    final accessoryCount = (count - mainCount).clamp(0, 5);
    final accessoryExercises = remaining.take(accessoryCount).toList();

    return [...mainExercises, ...accessoryExercises];
  }

  /// 计算建议重量（基于default_weights或历史记录）
  Future<double> calculateWeight(Exercise exercise, UserProfile? profile, DBHelper db) async {
    final database = await db.database;

    double defaultWeight = 20.0;
    final exMap = exercise.toMap();
    final dw = exMap['default_weight'] ?? exMap['defaultWeight'];
    if (dw != null) {
      defaultWeight = (dw as num).toDouble();
    } else {
      // 基于体重估算初始重量
      final bodyWeight = profile?.weight ?? 70.0;
      final name = exercise.name?.toLowerCase() ?? '';
      if (name.contains('深蹲') || name.contains('硬拉') || name.contains('卧推')) {
        defaultWeight = bodyWeight * 0.6;
      } else if (name.contains('哑铃') || name.contains('弯举')) {
        defaultWeight = bodyWeight * 0.15;
      } else if (name.contains('肩推') || name.contains('推举')) {
        defaultWeight = bodyWeight * 0.2;
      } else {
        defaultWeight = bodyWeight * 0.25;
      }
    }

    // 查询历史记录进行渐进超负荷
    if (exercise.id != null) {
      final logs = await database.query(
        'workout_logs',
        where: 'exercise_id = ?',
        whereArgs: [exercise.id],
        orderBy: 'date DESC',
        limit: 3,
      );

      if (logs.isNotEmpty) {
        final lastLog = logs.first;
        final lastWeight = (lastLog['actual_weight'] as num?)?.toDouble() ??
                           (lastLog['weight'] as num?)?.toDouble();
        if (lastWeight != null && lastWeight > 0) {
          defaultWeight = lastWeight * 1.025;
        }
      }
    }

    // 圆整到 0.5kg，限制在合理范围
    return ((defaultWeight * 2).round() / 2).clamp(1.0, 500.0);
  }

  /// 估算卡路里
  int estimateCalories(List<Map<String, dynamic>> exercises, double bodyWeight, int duration) {
    return estimateCaloriesBurned(bodyWeight, duration, 'moderate');
  }

  /// 处理生病
  Future<void> markSickDay(DateTime date, String reason) async {
    await _ensureSchema();
    final database = await db.database;
    await database.insert('daily_status', {
      'date': formatDate(date),
      'status': 'sick',
      'notes': reason,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// 处理休息
  Future<void> markRestDay(DateTime date) async {
    await _ensureSchema();
    final database = await db.database;
    await database.insert('daily_status', {
      'date': formatDate(date),
      'status': 'rest',
      'notes': '主动休息',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// 检查缺席并自动标记
  Future<void> checkAbsence(DateTime today) async {
    await _ensureSchema();
    final database = await db.database;
    final yesterday = today.subtract(const Duration(days: 1));
    final yStr = formatDate(yesterday);

    // 检查昨天是否有完成的训练
    final logs = await database.query(
      'workout_logs',
      where: 'date = ? AND completed = ?',
      whereArgs: [yStr, 1],
    );

    if (logs.isEmpty) {
      // 检查昨天是否有计划
      final plans = await database.query(
        'training_plans',
        where: 'date = ?',
        whereArgs: [yStr],
      );

      if (plans.isNotEmpty) {
        await database.insert('absence_records', {
          'start_date': yStr,
          'end_date': yStr,
          'reason': '未训练',
          'auto_flag': 1,
          'planned_day_type': plans.first['day_type'],
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
  }

  /// 获取本周计划状态（用于日历显示）
  Future<List<Map<String, dynamic>>> getWeekPlanStatus(DateTime weekStart) async {
    await _ensureSchema();
    final database = await db.database;
    final results = <Map<String, dynamic>>[];

    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final dateStr = formatDate(date);

      // 1. 查询每日状态（生病/主动休息优先级最高）
      final dailyStatus = await database.query(
        'daily_status',
        where: 'date = ?',
        whereArgs: [dateStr],
      );

      if (dailyStatus.isNotEmpty) {
        final status = dailyStatus.first['status'] as String?;
        results.add({
          'date': dateStr,
          'weekday': date.weekday,
          'status': status,
          'label': _statusLabel(status),
          'icon': _statusIcon(status),
          'color': _statusColor(status),
        });
        continue;
      }

      // 2. 查询训练记录（已完成）
      final logs = await database.query(
        'workout_logs',
        where: 'date = ? AND completed = ?',
        whereArgs: [dateStr, 1],
      );

      if (logs.isNotEmpty) {
        results.add({
          'date': dateStr,
          'weekday': date.weekday,
          'status': 'completed',
          'label': '已完成',
          'icon': 'check',
          'color': 'green',
        });
        continue;
      }

      // 3. 查询训练计划
      final plans = await database.query(
        'training_plans',
        where: 'date = ?',
        whereArgs: [dateStr],
      );

      if (plans.isNotEmpty) {
        final dayType = plans.first['day_type'] as String? ?? 'full';
        final planStatus = plans.first['status'] as String? ?? 'pending';
        results.add({
          'date': dateStr,
          'weekday': date.weekday,
          'status': planStatus == 'completed' ? 'completed' : 'pending',
          'day_type': dayType,
          'label': getSplitName(dayType),
          'icon': planStatus == 'completed' ? 'check' : 'pending',
          'color': planStatus == 'completed' ? 'green' : 'orange',
        });
        continue;
      }

      // 4. 默认：无计划
      results.add({
        'date': dateStr,
        'weekday': date.weekday,
        'status': 'none',
        'label': '无计划',
        'icon': 'none',
        'color': 'grey',
      });
    }

    return results;
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'sick': return '生病';
      case 'rest': return '休息';
      case 'completed': return '已完成';
      default: return '未知';
    }
  }

  String _statusIcon(String? status) {
    switch (status) {
      case 'sick': return 'sick';
      case 'rest': return 'rest';
      case 'completed': return 'check';
      default: return 'none';
    }
  }

  String _statusColor(String? status) {
    switch (status) {
      case 'sick': return 'red';
      case 'rest': return 'blue';
      case 'completed': return 'green';
      default: return 'grey';
    }
  }
}
