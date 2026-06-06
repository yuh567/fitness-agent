import 'package:flutter/material.dart';
import 'dart:convert';
import 'database/db_helper.dart';
import 'models.dart';
import 'utils.dart';
import 'plan_engine.dart';
import 'workout_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 铁匠铺主页
/// 深炭灰背景 + 活力橙强调色，所有UI文字使用中文
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final db = DBHelper.instance;
  final engine = PlanEngine();

  UserProfile? userProfile;
  List<Environment> environments = [];
  int? selectedEnvId;
  Map<String, dynamic>? todayPlan;
  List<Map<String, dynamic>> weekStatus = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    // 加载用户资料
    final profile = await db.getUserProfile();

    // 加载环境
    final envs = await db.getAllEnvironments();
    int? defaultEnvId;
    if (envs.isNotEmpty) {
      final database = await db.database;
      final envMaps = await database.query('environments');
      for (var em in envMaps) {
        if (em['is_default'] == 1) {
          defaultEnvId = em['id'] as int?;
          break;
        }
      }
      defaultEnvId ??= envs.first.id;
    }

    // 加载今日计划
    Map<String, dynamic>? plan;
    if (defaultEnvId != null) {
      await engine.checkAbsence(DateTime.now());
      plan = await _loadTodayPlan(defaultEnvId);
    }

    // 加载本周状态
    final weekStart = getWeekStart(DateTime.now());
    final week = await engine.getWeekPlanStatus(weekStart);

    if (mounted) {
      setState(() {
        userProfile = profile;
        environments = envs;
        selectedEnvId = defaultEnvId;
        todayPlan = plan;
        weekStatus = week;
        isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _loadTodayPlan(int locationId) async {
    final database = await db.database;
    final today = formatDate(DateTime.now());
    final plans = await database.query(
      'training_plans',
      where: 'date = ?',
      whereArgs: [today],
    );
    if (plans.isNotEmpty) {
      return plans.first;
    }
    return null;
  }

  Future<void> _generateTodayPlan() async {
    if (selectedEnvId == null) return;
    setState(() => isLoading = true);
    final plan = await engine.generateTodayPlan(selectedEnvId!, DateTime.now());
    final weekStart = getWeekStart(DateTime.now());
    final week = await engine.getWeekPlanStatus(weekStart);
    if (mounted) {
      setState(() {
        todayPlan = plan;
        weekStatus = week;
        isLoading = false;
      });
    }
  }

  void _startWorkout() {
    if (todayPlan == null) return;
    List<Map<String, dynamic>> exercises = [];
    try {
      final jsonStr = todayPlan!['exercises'] as String? ?? '[]';
      exercises = List<Map<String, dynamic>>.from(jsonDecode(jsonStr));
    } catch (_) {}

    if (exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('今日无训练动作')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutPage(plan: todayPlan!, exercises: exercises),
      ),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildTodayPlanCard(),
              const SizedBox(height: 24),
              _buildWeekCalendar(),
              const SizedBox(height: 24),
              _buildQuickActions(),
              const SizedBox(height: 24),
              _buildEnvSelector(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// 顶部欢迎语 + 日期
  Widget _buildHeader() {
    final name = userProfile?.name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '铁匠，今天想锻造哪里？',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${formatDate(DateTime.now())} ${getWeekdayName(DateTime.now().weekday)}',
          style: TextStyle(fontSize: 14, color: Colors.grey[400]),
        ),
        if (name != null && name.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '欢迎回来，$name',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.deepOrange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  /// 今日计划卡片（核心区域）
  Widget _buildTodayPlanCard() {
    if (isLoading) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.deepOrange),
        ),
      );
    }

    if (todayPlan == null) {
      return _buildNoPlanCard();
    }

    final dayType = todayPlan!['day_type'] as String? ?? 'rest';
    final status = todayPlan!['status'] as String? ?? 'pending';

    if (dayType == 'rest' || status == 'rest') {
      return _buildRestCard();
    }

    final exercisesJson = todayPlan!['exercises'] as String? ?? '[]';
    List<Map<String, dynamic>> exercises = [];
    try {
      exercises = List<Map<String, dynamic>>.from(jsonDecode(exercisesJson));
    } catch (_) {}

    final totalExercises = (todayPlan!['total_exercises'] as num?)?.toInt() ?? exercises.length;
    final duration = (todayPlan!['estimated_duration'] as num?)?.toInt() ?? 45;
    final calories = (todayPlan!['calories_burned'] as num?)?.toInt() ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      getSplitName(dayType),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalExercises 个动作 · 约 $duration 分钟 · $calories 千卡',
                      style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                    ),
                  ],
                ),
                if (status == 'completed')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 16),
                        SizedBox(width: 4),
                        Text('已完成', style: TextStyle(color: Colors.green, fontSize: 12)),
                      ],
                    ),
                  ),
              ],
            ),
            const Divider(height: 24, color: Colors.white24),
            ...exercises.map((ex) => _buildExerciseRow(ex)),
            const SizedBox(height: 16),
            if (status != 'completed')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startWorkout,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text(
                    '开始锻造',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 单个动作行
  Widget _buildExerciseRow(Map<String, dynamic> ex) {
    final name = ex['name'] as String? ?? '未知动作';
    final muscle = ex['muscle_group'] as String? ?? ex['target_muscle'] as String? ?? '全身';
    final sets = (ex['target_sets'] as num?)?.toInt() ??
                 (ex['default_sets'] as num?)?.toInt() ?? 3;
    final reps = (ex['target_reps'] as num?)?.toInt() ??
                 (ex['default_reps'] as num?)?.toInt() ?? 10;
    final weight = (ex['target_weight'] as num?)?.toDouble() ??
                   (ex['default_weight'] as num?)?.toDouble() ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.deepOrange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              getMuscleName(muscle),
              style: const TextStyle(
                fontSize: 11,
                color: Colors.deepOrange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$sets组 × $reps次 @ ${formatWeight(weight)}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 无计划卡片
  Widget _buildNoPlanCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.calendar_today, size: 48, color: Colors.grey[600]),
            const SizedBox(height: 12),
            const Text(
              '今日暂无计划',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '让AI教练为你生成今日锻造计划',
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _generateTodayPlan,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('生成今日计划', style: TextStyle(fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 休息日卡片
  Widget _buildRestCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.nightlight_round, size: 48, color: Colors.blue[300]),
            const SizedBox(height: 12),
            const Text(
              '今日休息，肌肉在生长',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '恢复也是训练的一部分。建议进行轻度拉伸或散步。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildSuggestionChip('轻度拉伸', Icons.self_improvement),
                _buildSuggestionChip('散步 30分钟', Icons.directions_walk),
                _buildSuggestionChip('泡沫轴放松', Icons.spa),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String label, IconData icon) {
    return Chip(
      avatar: Icon(icon, size: 16, color: Colors.blue[300]),
      label: Text(label, style: TextStyle(fontSize: 12, color: Colors.blue[100])),
      backgroundColor: Colors.blue.withOpacity(0.1),
      side: BorderSide.none,
    );
  }

  /// 本周训练日历（横向7天）
  Widget _buildWeekCalendar() {
    final weekStart = getWeekStart(DateTime.now());
    final todayStr = formatDate(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '本周训练',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 7,
            itemBuilder: (_, i) {
              final date = weekStart.add(Duration(days: i));
              final dateStr = formatDate(date);
              final isToday = dateStr == todayStr;

              final status = weekStatus.firstWhere(
                (s) => s['date'] == dateStr,
                orElse: () => {
                  'status': 'none',
                  'label': '无',
                  'icon': 'none',
                  'color': 'grey',
                },
              );

              final color = _getStatusColor(status['color'] as String?);
              final iconData = _getStatusIconData(status['icon'] as String?);

              return Container(
                width: 72,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: isToday
                      ? Border.all(color: Colors.deepOrange, width: 2)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${date.month}/${date.day}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      getWeekdayName(date.weekday),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isToday ? Colors.deepOrange : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Icon(iconData, size: 18, color: color),
                    const SizedBox(height: 2),
                    Text(
                      status['label'] as String? ?? '',
                      style: TextStyle(fontSize: 10, color: color),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String? colorName) {
    switch (colorName) {
      case 'green':
        return Colors.green;
      case 'orange':
        return Colors.orange;
      case 'blue':
        return Colors.blue[300]!;
      case 'red':
        return Colors.red[300]!;
      default:
        return Colors.grey[500]!;
    }
  }

  IconData _getStatusIconData(String? iconName) {
    switch (iconName) {
      case 'check':
        return Icons.check_circle;
      case 'pending':
        return Icons.hourglass_empty;
      case 'rest':
        return Icons.nightlight_round;
      case 'sick':
        return Icons.sick;
      default:
        return Icons.circle_outlined;
    }
  }

  /// 快速操作网格（2×2卡片）
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '快速操作',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.7,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildActionCard('身体数据', Icons.fitness_center, Colors.deepOrange, () {}),
            _buildActionCard('训练历史', Icons.trending_up, Colors.deepOrange, () {}),
            _buildActionCard('调整计划', Icons.psychology, Colors.purple, () {}),
            _buildActionCard('管理地点', Icons.location_on, Colors.deepOrange, () {}),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 训练地点选择器（Wrap + ChoiceChip）
  Widget _buildEnvSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '训练地点',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: environments.map((env) {
            final isSelected = env.id == selectedEnvId;
            return ChoiceChip(
              label: Text(env.name ?? '未知'),
              selected: isSelected,
              onSelected: (_) {
                setState(() => selectedEnvId = env.id);
                _generateTodayPlan();
              },
              selectedColor: Colors.deepOrange,
              backgroundColor: const Color(0xFF1E1E1E),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[300],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              checkmarkColor: Colors.white,
            );
          }).toList(),
        ),
      ],
    );
  }
}
