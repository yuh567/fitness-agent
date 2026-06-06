import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models.dart';

/// 数据库帮助类
/// 管理「铁匠铺」健身App的SQLite数据库，版本2
class DBHelper {
  static final DBHelper instance = DBHelper._privateConstructor();
  static Database? _database;

  DBHelper._privateConstructor();

  factory DBHelper() => instance;

  /// 获取数据库实例（单例）
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// 初始化数据库
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'fitness_agent.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// 首次创建数据库
  Future<void> _onCreate(Database db, int version) async {
    await _createV2Schema(db);
    await _insertSeedData(db);
  }

  /// 数据库升级
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _upgradeToV2(db);
    }
  }

  /// 安全添加列：若列已存在则忽略错误
  Future<void> _safeAddColumn(
      Database db, String table, String column, String type) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    } catch (e) {
      // 列已存在或表结构异常，忽略错误以兼容不同历史版本
    }
  }

  /// 从V1升级到V2
  /// 策略：扩展现有表 + 创建新表，保留已有数据
  Future<void> _upgradeToV2(Database db) async {
    // 扩展现有表：user_profile
    await _safeAddColumn(db, 'user_profile', 'experience_level', 'TEXT');
    await _safeAddColumn(db, 'user_profile', 'training_days_per_week', 'INTEGER');
    await _safeAddColumn(db, 'user_profile', 'preferred_duration', 'INTEGER');

    // 扩展现有表：training_plans
    await _safeAddColumn(db, 'training_plans', 'total_exercises', 'INTEGER');
    await _safeAddColumn(db, 'training_plans', 'estimated_duration', 'INTEGER');
    await _safeAddColumn(db, 'training_plans', 'calories_burned', 'INTEGER');
    await _safeAddColumn(db, 'training_plans', 'notes', 'TEXT');
    await _safeAddColumn(db, 'training_plans', 'generated_by_ai', 'INTEGER');

    // 扩展现有表：workout_logs
    await _safeAddColumn(db, 'workout_logs', 'actual_weight', 'REAL');
    await _safeAddColumn(db, 'workout_logs', 'actual_sets', 'INTEGER');
    await _safeAddColumn(db, 'workout_logs', 'actual_reps_json', 'TEXT');
    await _safeAddColumn(db, 'workout_logs', 'rest_taken', 'INTEGER');
    await _safeAddColumn(db, 'workout_logs', 'calories_estimated', 'INTEGER');
    await _safeAddColumn(db, 'workout_logs', 'feeling_notes', 'TEXT');

    // 创建新表：用户器材
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_equipment (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        equipment_type TEXT,
        name TEXT,
        is_available INTEGER,
        max_weight REAL,
        notes TEXT
      )
    ''');

    // 创建新表：健身目标
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fitness_goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_type TEXT,
        target_value REAL,
        current_value REAL,
        deadline TEXT,
        priority INTEGER,
        created_at TEXT
      )
    ''');

    // 创建新表：训练历史
    await db.execute('''
      CREATE TABLE IF NOT EXISTS training_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        has_gym_experience INTEGER,
        years_experience REAL,
        previous_routine TEXT,
        max_lifts_json TEXT,
        injuries TEXT,
        created_at TEXT
      )
    ''');

    // 创建新表：每日状态
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_status (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        status TEXT,
        energy_level INTEGER,
        sleep_hours REAL,
        notes TEXT
      )
    ''');

    // 创建新表：卡路里记录
    await db.execute('''
      CREATE TABLE IF NOT EXISTS calorie_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        type TEXT,
        category TEXT,
        amount INTEGER,
        notes TEXT
      )
    ''');
  }

  /// 创建V2完整Schema（全新安装时使用）
  Future<void> _createV2Schema(Database db) async {
    // 用户档案表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_profile (
        id INTEGER PRIMARY KEY,
        name TEXT,
        gender TEXT,
        age INTEGER,
        height REAL,
        weight REAL,
        body_fat REAL,
        goal TEXT,
        experience_level TEXT,
        training_days_per_week INTEGER,
        preferred_duration INTEGER,
        created_at TEXT
      )
    ''');

    // 训练环境表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS environments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        description TEXT,
        created_at TEXT
      )
    ''');

    // 动作表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        category TEXT,
        muscle_group TEXT,
        equipment TEXT,
        difficulty TEXT,
        instructions TEXT,
        created_at TEXT
      )
    ''');

    // 训练计划表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS training_plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        description TEXT,
        level TEXT,
        frequency INTEGER,
        total_exercises INTEGER,
        estimated_duration INTEGER,
        calories_burned INTEGER,
        notes TEXT,
        generated_by_ai INTEGER,
        created_at TEXT
      )
    ''');

    // 训练记录表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workout_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id INTEGER,
        exercise_id INTEGER,
        date TEXT,
        completed INTEGER,
        actual_weight REAL,
        actual_sets INTEGER,
        actual_reps_json TEXT,
        rest_taken INTEGER,
        calories_estimated INTEGER,
        feeling_notes TEXT,
        created_at TEXT
      )
    ''');

    // 身体指标表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS body_metrics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        weight REAL,
        body_fat REAL,
        muscle_mass REAL,
        notes TEXT,
        created_at TEXT
      )
    ''');

    // 缺勤记录表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS absence_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_date TEXT,
        end_date TEXT,
        reason TEXT,
        created_at TEXT
      )
    ''');

    // 用户器材表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_equipment (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        equipment_type TEXT,
        name TEXT,
        is_available INTEGER,
        max_weight REAL,
        notes TEXT
      )
    ''');

    // 健身目标表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fitness_goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_type TEXT,
        target_value REAL,
        current_value REAL,
        deadline TEXT,
        priority INTEGER,
        created_at TEXT
      )
    ''');

    // 训练历史表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS training_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        has_gym_experience INTEGER,
        years_experience REAL,
        previous_routine TEXT,
        max_lifts_json TEXT,
        injuries TEXT,
        created_at TEXT
      )
    ''');

    // 每日状态表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_status (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        status TEXT,
        energy_level INTEGER,
        sleep_hours REAL,
        notes TEXT
      )
    ''');

    // 卡路里记录表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS calorie_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        type TEXT,
        category TEXT,
        amount INTEGER,
        notes TEXT
      )
    ''');
  }

  /// 插入种子数据
  /// 使用 ConflictAlgorithm.ignore 保留现有数据（升级场景）
  Future<void> _insertSeedData(Database db) async {
    final now = DateTime.now().toIso8601String();

    // 训练环境种子数据
    final environments = [
      {'name': '健身房', 'description': '商业健身房，器械齐全', 'created_at': now},
      {'name': '家庭健身', 'description': '家中训练，空间有限', 'created_at': now},
      {'name': '户外', 'description': '公园或户外场地', 'created_at': now},
    ];
    for (final env in environments) {
      await db.insert('environments', env,
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    // 动作种子数据
    final exercises = [
      {
        'name': '深蹲',
        'category': '力量',
        'muscle_group': '腿部',
        'equipment': '杠铃',
        'difficulty': '中级',
        'instructions': '双脚与肩同宽，下蹲至大腿平行地面，保持背部挺直',
        'created_at': now
      },
      {
        'name': '卧推',
        'category': '力量',
        'muscle_group': '胸部',
        'equipment': '杠铃',
        'difficulty': '中级',
        'instructions': '平躺卧推凳，控制杠铃下降至胸部后推起',
        'created_at': now
      },
      {
        'name': '硬拉',
        'category': '力量',
        'muscle_group': '背部',
        'equipment': '杠铃',
        'difficulty': '高级',
        'instructions': '保持背部挺直，拉起杠铃至身体直立，髋部前推',
        'created_at': now
      },
      {
        'name': '哑铃弯举',
        'category': '力量',
        'muscle_group': '手臂',
        'equipment': '哑铃',
        'difficulty': '初级',
        'instructions': '上臂固定，弯曲前臂举起哑铃，控制下放',
        'created_at': now
      },
      {
        'name': '俯卧撑',
        'category': '力量',
        'muscle_group': '胸部',
        'equipment': '自重',
        'difficulty': '初级',
        'instructions': '双手撑地，身体保持直线，下降至胸部接近地面后推起',
        'created_at': now
      },
      {
        'name': '引体向上',
        'category': '力量',
        'muscle_group': '背部',
        'equipment': '单杠',
        'difficulty': '中级',
        'instructions': '双手握杠，拉起身体至下巴过杠，控制下放',
        'created_at': now
      },
      {
        'name': '平板支撑',
        'category': '核心',
        'muscle_group': '腹部',
        'equipment': '自重',
        'difficulty': '初级',
        'instructions': '前臂撑地，身体保持一条直线，收紧核心',
        'created_at': now
      },
      {
        'name': '弓步蹲',
        'category': '力量',
        'muscle_group': '腿部',
        'equipment': '哑铃',
        'difficulty': '初级',
        'instructions': '单脚向前迈出，下蹲至双膝约90度，交替进行',
        'created_at': now
      },
      {
        'name': '肩推',
        'category': '力量',
        'muscle_group': '肩部',
        'equipment': '哑铃',
        'difficulty': '中级',
        'instructions': '坐姿或站姿，将哑铃从肩部推至头顶',
        'created_at': now
      },
      {
        'name': '划船',
        'category': '力量',
        'muscle_group': '背部',
        'equipment': '哑铃',
        'difficulty': '初级',
        'instructions': '单膝跪凳，拉起哑铃至髋部，挤压背部肌肉',
        'created_at': now
      },
    ];
    for (final ex in exercises) {
      await db.insert('exercises', ex,
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // ==================== UserProfile CRUD ====================

  /// 插入或替换用户档案
  Future<int> insertUserProfile(UserProfile profile) async {
    final db = await database;
    return await db.insert('user_profile', profile.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// 查询用户档案（通常仅有一条）
  Future<UserProfile?> getUserProfile() async {
    final db = await database;
    final maps = await db.query('user_profile', limit: 1);
    if (maps.isNotEmpty) {
      return UserProfile.fromMap(maps.first);
    }
    return null;
  }

  /// 更新用户档案
  Future<int> updateUserProfile(UserProfile profile) async {
    final db = await database;
    return await db.update('user_profile', profile.toMap(),
        where: 'id = ?', whereArgs: [profile.id]);
  }

  // ==================== UserEquipment CRUD ====================

  /// 插入用户器材
  Future<int> insertUserEquipment(UserEquipment equipment) async {
    final db = await database;
    return await db.insert('user_equipment', equipment.toMap());
  }

  /// 查询所有用户器材
  Future<List<UserEquipment>> getAllUserEquipment() async {
    final db = await database;
    final maps = await db.query('user_equipment');
    return maps.map((e) => UserEquipment.fromMap(e)).toList();
  }

  /// 根据ID查询用户器材
  Future<UserEquipment?> getUserEquipmentById(int id) async {
    final db = await database;
    final maps =
        await db.query('user_equipment', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return UserEquipment.fromMap(maps.first);
    return null;
  }

  /// 更新用户器材
  Future<int> updateUserEquipment(UserEquipment equipment) async {
    final db = await database;
    return await db.update('user_equipment', equipment.toMap(),
        where: 'id = ?', whereArgs: [equipment.id]);
  }

  /// 删除用户器材
  Future<int> deleteUserEquipment(int id) async {
    final db = await database;
    return await db.delete('user_equipment',
        where: 'id = ?', whereArgs: [id]);
  }

  // ==================== FitnessGoal CRUD ====================

  /// 插入健身目标
  Future<int> insertFitnessGoal(FitnessGoal goal) async {
    final db = await database;
    return await db.insert('fitness_goals', goal.toMap());
  }

  /// 查询所有健身目标（按优先级降序）
  Future<List<FitnessGoal>> getAllFitnessGoals() async {
    final db = await database;
    final maps = await db.query('fitness_goals', orderBy: 'priority DESC');
    return maps.map((e) => FitnessGoal.fromMap(e)).toList();
  }

  /// 根据ID查询健身目标
  Future<FitnessGoal?> getFitnessGoalById(int id) async {
    final db = await database;
    final maps =
        await db.query('fitness_goals', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return FitnessGoal.fromMap(maps.first);
    return null;
  }

  /// 更新健身目标
  Future<int> updateFitnessGoal(FitnessGoal goal) async {
    final db = await database;
    return await db.update('fitness_goals', goal.toMap(),
        where: 'id = ?', whereArgs: [goal.id]);
  }

  /// 删除健身目标
  Future<int> deleteFitnessGoal(int id) async {
    final db = await database;
    return await db.delete('fitness_goals',
        where: 'id = ?', whereArgs: [id]);
  }

  // ==================== TrainingHistory CRUD ====================

  /// 插入训练历史
  Future<int> insertTrainingHistory(TrainingHistory history) async {
    final db = await database;
    return await db.insert('training_history', history.toMap());
  }

  /// 查询训练历史（通常仅有一条）
  Future<TrainingHistory?> getTrainingHistory() async {
    final db = await database;
    final maps = await db.query('training_history', limit: 1);
    if (maps.isNotEmpty) return TrainingHistory.fromMap(maps.first);
    return null;
  }

  /// 更新训练历史
  Future<int> updateTrainingHistory(TrainingHistory history) async {
    final db = await database;
    return await db.update('training_history', history.toMap(),
        where: 'id = ?', whereArgs: [history.id]);
  }

  // ==================== Exercise CRUD ====================

  /// 插入动作
  Future<int> insertExercise(Exercise exercise) async {
    final db = await database;
    return await db.insert('exercises', exercise.toMap());
  }

  /// 查询所有动作
  Future<List<Exercise>> getAllExercises() async {
    final db = await database;
    final maps = await db.query('exercises');
    return maps.map((e) => Exercise.fromMap(e)).toList();
  }

  /// 根据ID查询动作
  Future<Exercise?> getExerciseById(int id) async {
    final db = await database;
    final maps =
        await db.query('exercises', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return Exercise.fromMap(maps.first);
    return null;
  }

  /// 更新动作
  Future<int> updateExercise(Exercise exercise) async {
    final db = await database;
    return await db.update('exercises', exercise.toMap(),
        where: 'id = ?', whereArgs: [exercise.id]);
  }

  /// 删除动作
  Future<int> deleteExercise(int id) async {
    final db = await database;
    return await db.delete('exercises', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== WorkoutPlan CRUD ====================

  /// 插入训练计划
  Future<int> insertWorkoutPlan(WorkoutPlan plan) async {
    final db = await database;
    return await db.insert('training_plans', plan.toMap());
  }

  /// 查询所有训练计划
  Future<List<WorkoutPlan>> getAllWorkoutPlans() async {
    final db = await database;
    final maps = await db.query('training_plans');
    return maps.map((e) => WorkoutPlan.fromMap(e)).toList();
  }

  /// 根据ID查询训练计划
  Future<WorkoutPlan?> getWorkoutPlanById(int id) async {
    final db = await database;
    final maps =
        await db.query('training_plans', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return WorkoutPlan.fromMap(maps.first);
    return null;
  }

  /// 更新训练计划
  Future<int> updateWorkoutPlan(WorkoutPlan plan) async {
    final db = await database;
    return await db.update('training_plans', plan.toMap(),
        where: 'id = ?', whereArgs: [plan.id]);
  }

  /// 删除训练计划
  Future<int> deleteWorkoutPlan(int id) async {
    final db = await database;
    return await db.delete('training_plans',
        where: 'id = ?', whereArgs: [id]);
  }

  // ==================== WorkoutLog CRUD ====================

  /// 插入训练记录
  Future<int> insertWorkoutLog(WorkoutLog log) async {
    final db = await database;
    return await db.insert('workout_logs', log.toMap());
  }

  /// 查询所有训练记录（按日期降序）
  Future<List<WorkoutLog>> getAllWorkoutLogs() async {
    final db = await database;
    final maps = await db.query('workout_logs', orderBy: 'date DESC');
    return maps.map((e) => WorkoutLog.fromMap(e)).toList();
  }

  /// 根据日期查询训练记录
  Future<List<WorkoutLog>> getWorkoutLogsByDate(String date) async {
    final db = await database;
    final maps = await db.query('workout_logs',
        where: 'date = ?', whereArgs: [date]);
    return maps.map((e) => WorkoutLog.fromMap(e)).toList();
  }

  /// 根据ID查询训练记录
  Future<WorkoutLog?> getWorkoutLogById(int id) async {
    final db = await database;
    final maps =
        await db.query('workout_logs', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return WorkoutLog.fromMap(maps.first);
    return null;
  }

  /// 更新训练记录
  Future<int> updateWorkoutLog(WorkoutLog log) async {
    final db = await database;
    return await db.update('workout_logs', log.toMap(),
        where: 'id = ?', whereArgs: [log.id]);
  }

  /// 删除训练记录
  Future<int> deleteWorkoutLog(int id) async {
    final db = await database;
    return await db.delete('workout_logs',
        where: 'id = ?', whereArgs: [id]);
  }

  // ==================== BodyMetrics CRUD ====================

  /// 插入身体指标
  Future<int> insertBodyMetrics(BodyMetrics metrics) async {
    final db = await database;
    return await db.insert('body_metrics', metrics.toMap());
  }

  /// 查询所有身体指标（按日期降序）
  Future<List<BodyMetrics>> getAllBodyMetrics() async {
    final db = await database;
    final maps = await db.query('body_metrics', orderBy: 'date DESC');
    return maps.map((e) => BodyMetrics.fromMap(e)).toList();
  }

  /// 根据ID查询身体指标
  Future<BodyMetrics?> getBodyMetricsById(int id) async {
    final db = await database;
    final maps =
        await db.query('body_metrics', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return BodyMetrics.fromMap(maps.first);
    return null;
  }

  /// 更新身体指标
  Future<int> updateBodyMetrics(BodyMetrics metrics) async {
    final db = await database;
    return await db.update('body_metrics', metrics.toMap(),
        where: 'id = ?', whereArgs: [metrics.id]);
  }

  /// 删除身体指标
  Future<int> deleteBodyMetrics(int id) async {
    final db = await database;
    return await db.delete('body_metrics',
        where: 'id = ?', whereArgs: [id]);
  }

  // ==================== DailyStatus CRUD ====================

  /// 插入每日状态
  Future<int> insertDailyStatus(DailyStatus status) async {
    final db = await database;
    return await db.insert('daily_status', status.toMap());
  }

  /// 查询所有每日状态（按日期降序）
  Future<List<DailyStatus>> getAllDailyStatus() async {
    final db = await database;
    final maps = await db.query('daily_status', orderBy: 'date DESC');
    return maps.map((e) => DailyStatus.fromMap(e)).toList();
  }

  /// 根据日期查询每日状态
  Future<DailyStatus?> getDailyStatusByDate(String date) async {
    final db = await database;
    final maps = await db.query('daily_status',
        where: 'date = ?', whereArgs: [date]);
    if (maps.isNotEmpty) return DailyStatus.fromMap(maps.first);
    return null;
  }

  /// 更新每日状态
  Future<int> updateDailyStatus(DailyStatus status) async {
    final db = await database;
    return await db.update('daily_status', status.toMap(),
        where: 'id = ?', whereArgs: [status.id]);
  }

  /// 删除每日状态
  Future<int> deleteDailyStatus(int id) async {
    final db = await database;
    return await db.delete('daily_status',
        where: 'id = ?', whereArgs: [id]);
  }

  // ==================== CalorieRecord CRUD ====================

  /// 插入卡路里记录
  Future<int> insertCalorieRecord(CalorieRecord record) async {
    final db = await database;
    return await db.insert('calorie_records', record.toMap());
  }

  /// 查询所有卡路里记录（按日期降序）
  Future<List<CalorieRecord>> getAllCalorieRecords() async {
    final db = await database;
    final maps = await db.query('calorie_records', orderBy: 'date DESC');
    return maps.map((e) => CalorieRecord.fromMap(e)).toList();
  }

  /// 根据日期查询卡路里记录
  Future<List<CalorieRecord>> getCalorieRecordsByDate(String date) async {
    final db = await database;
    final maps = await db.query('calorie_records',
        where: 'date = ?', whereArgs: [date]);
    return maps.map((e) => CalorieRecord.fromMap(e)).toList();
  }

  /// 根据ID查询卡路里记录
  Future<CalorieRecord?> getCalorieRecordById(int id) async {
    final db = await database;
    final maps = await db.query('calorie_records',
        where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return CalorieRecord.fromMap(maps.first);
    return null;
  }

  /// 更新卡路里记录
  Future<int> updateCalorieRecord(CalorieRecord record) async {
    final db = await database;
    return await db.update('calorie_records', record.toMap(),
        where: 'id = ?', whereArgs: [record.id]);
  }

  /// 删除卡路里记录
  Future<int> deleteCalorieRecord(int id) async {
    final db = await database;
    return await db.delete('calorie_records',
        where: 'id = ?', whereArgs: [id]);
  }

  // ==================== Environment CRUD ====================

  /// 插入训练环境
  Future<int> insertEnvironment(Environment env) async {
    final db = await database;
    return await db.insert('environments', env.toMap());
  }

  /// 查询所有训练环境
  Future<List<Environment>> getAllEnvironments() async {
    final db = await database;
    final maps = await db.query('environments');
    return maps.map((e) => Environment.fromMap(e)).toList();
  }

  /// 根据ID查询训练环境
  Future<Environment?> getEnvironmentById(int id) async {
    final db = await database;
    final maps =
        await db.query('environments', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return Environment.fromMap(maps.first);
    return null;
  }

  /// 更新训练环境
  Future<int> updateEnvironment(Environment env) async {
    final db = await database;
    return await db.update('environments', env.toMap(),
        where: 'id = ?', whereArgs: [env.id]);
  }

  /// 删除训练环境
  Future<int> deleteEnvironment(int id) async {
    final db = await database;
    return await db.delete('environments',
        where: 'id = ?', whereArgs: [id]);
  }

  // ==================== 通用方法 ====================

  /// 通用插入
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data);
  }

  /// 通用查询
  Future<List<Map<String, dynamic>>> query(String table, {String? where, List<dynamic>? whereArgs, String? orderBy}) async {
    final db = await database;
    return await db.query(table, where: where, whereArgs: whereArgs, orderBy: orderBy);
  }

  /// 通用更新
  Future<int> update(String table, Map<String, dynamic> data, String where, List<dynamic> whereArgs) async {
    final db = await database;
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }

  /// 通用删除
  Future<int> delete(String table, String where, List<dynamic> whereArgs) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  /// 执行原始SQL
  Future<void> rawQuery(String sql) async {
    final db = await database;
    await db.execute(sql);
  }

  /// 关闭数据库连接
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
