
import 'package:flutter/material.dart';
import 'dart:convert';
import 'database/db_helper.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FitnessAgentApp());
}

class FitnessAgentApp extends StatelessWidget {
  const FitnessAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fitness Agent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange, brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardTheme: const CardTheme(color: Color(0xFF1E1E1E), elevation: 4),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1E1E1E)),
      ),
      home: const HomePage(),
    );
  }
}

// ========== 服务层 ==========
class PlanEngine {
  final db = DBHelper();

  Future<Map<String, dynamic>?> generateTodayPlan(int locationId, DateTime date) async {
    final envList = await db.query('environments', where: 'id = ?', whereArgs: [locationId]);
    if (envList.isEmpty) return null;
    final env = envList.first;
    final equipment = List<String>.from(jsonDecode(env['equipment_list']));
    final defaultWeights = Map<String, dynamic>.from(jsonDecode(env['default_weights']));

    final dayType = _getDayType(date);
    if (dayType == 'rest') return {'day_type': 'rest', 'message': '今日休息'};

    final allExercises = await db.query('exercises');
    final candidates = allExercises.where((e) {
      final target = e['target_muscle'] as String;
      return _matchesDayType(target, dayType) && equipment.contains(e['equipment_type']);
    }).toList();

    if (candidates.isEmpty) return {'day_type': dayType, 'message': '当前地点无可用器械完成训练'};

    final selected = _selectExercises(candidates, dayType);
    final adjusted = await _applyProgression(selected, defaultWeights, date);

    final plan = {
      'date': date.toIso8601String().split('T')[0],
      'day_type': dayType,
      'location_id': locationId,
      'exercises': jsonEncode(adjusted),
      'status': 'pending',
    };
    await db.insert('training_plans', plan);
    return plan;
  }

  String _getDayType(DateTime date) {
    final weekday = date.weekday;
    switch (weekday) {
      case 1: case 5: return 'push';
      case 2: case 6: return 'pull';
      case 3: case 7: return 'legs';
      case 4: return 'rest';
      default: return 'push';
    }
  }

  bool _matchesDayType(String muscle, String dayType) {
    final push = ['胸大肌', '胸大肌上部', '胸大肌下部', '三角肌前束', '三角肌中束', '肱三头肌'];
    final pull = ['背阔肌', '竖脊肌', '斜方肌', '肱二头肌', '肱肌/肱桡肌', '三角肌后束'];
    final legs = ['股四头肌', '腘绳肌', '臀大肌', '小腿腓肠肌', '小腿比目鱼肌'];
    if (dayType == 'push') return push.any((m) => muscle.contains(m));
    if (dayType == 'pull') return pull.any((m) => muscle.contains(m));
    if (dayType == 'legs') return legs.any((m) => muscle.contains(m));
    return false;
  }

  List<Map<String, dynamic>> _selectExercises(List<Map<String, dynamic>> candidates, String dayType) {
    candidates.sort((a, b) => (b['difficulty'] as int).compareTo(a['difficulty'] as int));
    final main = candidates.first;
    final others = candidates.where((c) => c['id'] != main['id']).take(2).toList();
    return [main, ...others];
  }

  Future<List<Map<String, dynamic>>> _applyProgression(
    List<Map<String, dynamic>> exercises,
    Map<String, dynamic> defaultWeights,
    DateTime date,
  ) async {
    final results = <Map<String, dynamic>>[];
    for (var ex in exercises) {
      final name = ex['name'] as String;
      final baseWeight = defaultWeights[name] ?? ex['default_weight'];
      double targetWeight = (baseWeight as num).toDouble();
      int targetSets = ex['default_sets'] as int;
      int targetReps = ex['default_reps'] as int;
      String adjustmentNote = '初始重量';

      final logs = await db.query('workout_logs', where: 'exercise_id = ?', whereArgs: [ex['id']], orderBy: 'completed_at DESC');
      if (logs.length >= 2) {
        final last1 = logs[0];
        final last2 = logs[1];
        final rpe1 = (last1['rpe'] as num?)?.toDouble() ?? 8.0;
        final rpe2 = (last2['rpe'] as num?)?.toDouble() ?? 8.0;
        final weight1 = (last1['weight'] as num).toDouble();
        if (rpe1 <= 6.0 && rpe2 <= 6.0) {
          targetWeight = weight1 * 1.05;
          adjustmentNote = '连续轻松，重量 +5%';
        } else if (rpe1 >= 9.0 || rpe2 >= 9.0) {
          targetWeight = weight1 * 0.95;
          adjustmentNote = '接近力竭，重量 -5%';
        } else {
          targetWeight = weight1 * 1.025;
          adjustmentNote = '渐进超负荷 +2.5%';
        }
        if (logs.length >= 4) {
          final recent4 = logs.take(4).toList();
          final failures = recent4.where((l) {
            final repsDone = (l['reps'] as String).split(',').map(int.parse).toList();
            final target = ex['default_reps'] as int;
            return repsDone.any((r) => r < target * 0.8);
          }).length;
          if (failures >= 3) {
            targetWeight = weight1 * 0.85;
            targetSets = (targetSets * 0.8).round();
            adjustmentNote = '平台期 Deload：重量-15%，组数-20%';
          }
        }
      }

      final absences = await db.query('absence_records', where: 'date > ? AND auto_flag = 1', whereArgs: [date.subtract(const Duration(days: 7)).toIso8601String().split('T')[0]]);
      if (absences.length >= 2) {
        targetWeight = targetWeight * 0.90;
        adjustmentNote += ' | 近期请假，保守起步 -10%';
      }

      results.add({
        ...ex,
        'target_weight': ((targetWeight * 2).round() / 2).toDouble(),
        'target_sets': targetSets,
        'target_reps': targetReps,
        'adjustment_note': adjustmentNote,
      });
    }
    return results;
  }

  Future<void> checkAbsence(DateTime today) async {
    final yesterday = today.subtract(const Duration(days: 1));
    final yStr = yesterday.toIso8601String().split('T')[0];
    final plans = await db.query('training_plans', where: 'date = ?', whereArgs: [yStr]);
    if (plans.isNotEmpty && plans.first['status'] != 'completed') {
      final existing = await db.query('absence_records', where: 'date = ?', whereArgs: [yStr]);
      if (existing.isEmpty) {
        await db.insert('absence_records', {
          'date': yStr,
          'reason': '未训练',
          'planned_day_type': plans.first['day_type'],
          'auto_flag': 1,
        });
      }
    }
  }
}

class KimiApiService {
  static const String _baseUrl = 'https://api.moonshot.cn/v1/chat/completions';

  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('kimi_api_key');
  }

  Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kimi_api_key', key);
  }

  Future<Map<String, dynamic>?> requestDeepAdjustment() async {
    final key = await getApiKey();
    if (key == null || key.isEmpty) {
      throw Exception('未设置 API Key，请先在设置页填入');
    }
    final db = DBHelper();
    final logs = await db.query('workout_logs', orderBy: 'completed_at DESC');
    final metrics = await db.query('body_metrics', orderBy: 'date DESC');
    final absences = await db.query('absence_records', orderBy: 'date DESC');

    final prompt = '''
你是一位专业健身教练和运动科学专家。用户正在使用本地健身App，以下是他的最近训练数据摘要，请给出下周期（4周）的训练计划调整建议，以JSON格式返回。

最近训练记录：${logs.take(20).toList()}
最近身体数据：${metrics.take(10).toList()}
请假记录：${absences.take(10).toList()}

要求：
1. 分析训练频率、容量、RPE趋势
2. 识别平台期或过度训练信号
3. 建议新的训练分化
4. 给出每个部位主项、组数、次数、RPE范围
5. 如有请假记录，建议恢复策略

返回JSON格式：{"analysis":"...","new_split":"...","weeks":[...],"deload_needed":false,"notes":"..."}
''';

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $key',
      },
      body: jsonEncode({
        'model': 'moonshot-v1-8k',
        'messages': [
          {'role': 'system', 'content': '你是专业健身教练，精通NSCA和ACSM标准。'},
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.3,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];
      return jsonDecode(content);
    } else {
      throw Exception('API错误: ${response.statusCode}');
    }
  }
}

// ========== 页面 ==========
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final db = DBHelper();
  final engine = PlanEngine();
  final kimi = KimiApiService();
  Map<String, dynamic>? todayPlan;
  List<Map<String, dynamic>> environments = [];
  int? selectedEnvId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final envs = await db.query('environments');
    final defaultEnv = envs.firstWhere((e) => e['is_default'] == 1, orElse: () => envs.isNotEmpty ? envs.first : {});
    if (mounted) {
      setState(() {
        environments = envs;
        if (defaultEnv.isNotEmpty) selectedEnvId = defaultEnv['id'] as int;
      });
    }
    if (selectedEnvId != null) await _generatePlan();
  }

  Future<void> _generatePlan() async {
    if (selectedEnvId == null) return;
    await engine.checkAbsence(DateTime.now());
    final plan = await engine.generateTodayPlan(selectedEnvId!, DateTime.now());
    if (mounted) setState(() => todayPlan = plan);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fitness Agent', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEnvSelector(),
            const SizedBox(height: 20),
            if (todayPlan != null) _buildPlanCard(),
            const SizedBox(height: 20),
            _buildQuickActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildEnvSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('今日训练地点', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: environments.map((env) {
                final isSelected = env['id'] == selectedEnvId;
                return ChoiceChip(
                  label: Text(env['name']),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => selectedEnvId = env['id'] as int);
                    _generatePlan();
                  },
                  selectedColor: Colors.deepOrange,
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            if (selectedEnvId != null)
              Text(
                '可用器械: ${environments.firstWhere((e) => e['id'] == selectedEnvId, orElse: () => {'equipment_list': '[]'})['equipment_list']}',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard() {
    if (todayPlan!['day_type'] == 'rest') {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.bedtime, size: 48, color: Colors.blue[300]),
                const SizedBox(height: 10),
                const Text('今日休息', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Text('恢复也是训练的一部分', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      );
    }

    final exercises = List<Map<String, dynamic>>.from(jsonDecode(todayPlan!['exercises']));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${todayPlan!['day_type'].toString().toUpperCase()} 日',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('开始训练'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => WorkoutPage(plan: todayPlan!, exercises: exercises)),
                  ).then((_) => _generatePlan()),
                ),
              ],
            ),
            const Divider(),
            ...exercises.map((ex) => ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.deepOrange.withOpacity(0.2),
                child: Text('${ex['target_muscle'].toString().substring(0,1)}'),
              ),
              title: Text(ex['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${ex['target_sets']}组 × ${ex['target_reps']}次 @ ${ex['target_weight']}kg
${ex['adjustment_note']}'),
              isThreeLine: true,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        _ActionCard(
          icon: Icons.fitness_center,
          label: '身体数据',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BodyMetricsPage())),
        ),
        _ActionCard(
          icon: Icons.trending_up,
          label: '训练历史',
          onTap: () {},
        ),
        _ActionCard(
          icon: Icons.psychology,
          label: '请求教练调整',
          color: Colors.purple,
          onTap: () async {
            try {
              final result = await kimi.requestDeepAdjustment();
              if (result != null && mounted) {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('教练建议'),
                    content: SingleChildScrollView(child: Text(result['analysis'] ?? '暂无分析')),
                    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('收到'))],
                  ),
                );
              }
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('错误: $e')));
            }
          },
        ),
        _ActionCard(
          icon: Icons.location_on,
          label: '管理地点',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EnvManagePage())),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.label, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color ?? Colors.deepOrange),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class WorkoutPage extends StatefulWidget {
  final Map<String, dynamic> plan;
  final List<Map<String, dynamic>> exercises;
  const WorkoutPage({super.key, required this.plan, required this.exercises});

  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> {
  int currentIndex = 0;
  int currentSet = 1;
  bool isResting = false;
  int restSeconds = 0;
  List<int> completedReps = [];
  double? currentRPE;
  Map<String, dynamic> get currentEx => widget.exercises[currentIndex];

  void _startRest(int seconds) {
    setState(() { isResting = true; restSeconds = seconds; });
    _runTimer();
  }

  void _runTimer() async {
    while (restSeconds > 0 && isResting) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => restSeconds--);
    }
    if (mounted) setState(() => isResting = false);
  }

  void _nextSet() {
    if (currentSet < (currentEx['target_sets'] as int)) {
      setState(() { currentSet++; completedReps = []; currentRPE = null; });
      _startRest(currentEx['rest_seconds'] as int);
    } else {
      _showFeedback();
    }
  }

  void _showFeedback() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${currentEx['name']} 已完成', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Text('这次感觉如何？（RPE 1-10）'),
                Slider(
                  value: currentRPE ?? 7,
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: 'RPE ${(currentRPE ?? 7).toInt()}',
                  onChanged: (v) => setModalState(() => currentRPE = v),
                ),
                Text(
                  (currentRPE ?? 7) <= 6 ? '轻松，下次加重' :
                  (currentRPE ?? 7) >= 9 ? '力竭，下次减重' : '刚好，线性进步',
                  style: const TextStyle(color: Colors.deepOrange),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    await _saveLog();
                    Navigator.pop(ctx);
                    if (currentIndex < widget.exercises.length - 1) {
                      setState(() { currentIndex++; currentSet = 1; completedReps = []; currentRPE = null; });
                    } else {
                      _finishWorkout();
                    }
                  },
                  child: const Text('确认并继续'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveLog() async {
    final db = DBHelper();
    await db.insert('workout_logs', {
      'plan_id': widget.plan['id'],
      'exercise_id': currentEx['id'],
      'location_id': widget.plan['location_id'],
      'weight': currentEx['target_weight'],
      'sets': currentEx['target_sets'],
      'reps': completedReps.join(','),
      'rpe': currentRPE ?? 7,
      'notes': '',
      'completed_at': DateTime.now().toIso8601String(),
    });
  }

  void _finishWorkout() async {
    final db = DBHelper();
    await db.update('training_plans', {'status': 'completed'}, 'id = ?', [widget.plan['id']]);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('训练完成！已自动调整下次计划')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('训练中 - ${currentEx['name']}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(currentEx['name'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(currentEx['description'], style: TextStyle(color: Colors.grey[300])),
                    const SizedBox(height: 10),
                    Container(
                      height: 120,
                      color: Colors.grey[900],
                      child: Center(
                        child: currentEx['svg_data'] != null && currentEx['svg_data'].toString().isNotEmpty
                          ? Text('SVG示意图区域
（实际接入flutter_svg显示）', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500]))
                          : const Text('无示意图'),
                      ),
                    ),
                    if (currentEx['local_video_path'] != null && currentEx['local_video_path'].toString().isNotEmpty)
                      TextButton.icon(
                        icon: const Icon(Icons.play_circle),
                        label: const Text('播放本地教学视频'),
                        onPressed: () {},
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (isResting) ...[
              Center(
                child: Column(
                  children: [
                    const Text('组间休息', style: TextStyle(fontSize: 16)),
                    Text('$restSeconds', style: const TextStyle(fontSize: 72, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                    ElevatedButton(
                      onPressed: () => setState(() => isResting = false),
                      child: const Text('跳过休息'),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Text('第 $currentSet / ${currentEx['target_sets']} 组', style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 10),
              Text('目标：${currentEx['target_reps']} 次 @ ${currentEx['target_weight']} kg', style: const TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '实际完成次数', border: OutlineInputBorder()),
                      onChanged: (v) { if (v.isNotEmpty) completedReps.add(int.tryParse(v) ?? 0); },
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _nextSet,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24)),
                    child: const Text('完成'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => _startRest(currentEx['rest_seconds'] as int),
                child: const Text('暂停休息（手动）'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class BodyMetricsPage extends StatefulWidget {
  const BodyMetricsPage({super.key});
  @override
  State<BodyMetricsPage> createState() => _BodyMetricsPageState();
}

class _BodyMetricsPageState extends State<BodyMetricsPage> {
  final db = DBHelper();
  final weightCtrl = TextEditingController();
  final fatCtrl = TextEditingController();
  final chestCtrl = TextEditingController();
  final armCtrl = TextEditingController();
  final waistCtrl = TextEditingController();
  final thighCtrl = TextEditingController();
  final hrCtrl = TextEditingController();
  final notesCtrl = TextEditingController();

  Future<void> _save() async {
    await db.insert('body_metrics', {
      'date': DateTime.now().toIso8601String().split('T')[0],
      'weight': double.tryParse(weightCtrl.text) ?? 0,
      'body_fat': double.tryParse(fatCtrl.text) ?? 0,
      'chest': double.tryParse(chestCtrl.text) ?? 0,
      'arm': double.tryParse(armCtrl.text) ?? 0,
      'waist': double.tryParse(waistCtrl.text) ?? 0,
      'thigh': double.tryParse(thighCtrl.text) ?? 0,
      'resting_hr': int.tryParse(hrCtrl.text) ?? 0,
      'notes': notesCtrl.text,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('记录已保存')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('身体数据')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: weightCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '体重 (kg)')),
            TextField(controller: fatCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '体脂率 (%)')),
            TextField(controller: chestCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '胸围 (cm)')),
            TextField(controller: armCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '臂围 (cm)')),
            TextField(controller: waistCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '腰围 (cm)')),
            TextField(controller: thighCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '腿围 (cm)')),
            TextField(controller: hrCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '静息心率 (bpm)')),
            TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: '备注（睡眠、饮食等）')),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _save, child: const Text('保存记录')),
          ],
        ),
      ),
    );
  }
}

class EnvManagePage extends StatefulWidget {
  const EnvManagePage({super.key});
  @override
  State<EnvManagePage> createState() => _EnvManagePageState();
}

class _EnvManagePageState extends State<EnvManagePage> {
  final db = DBHelper();
  List<Map<String, dynamic>> envs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await db.query('environments');
    setState(() => envs = data);
  }

  Future<void> _addEnv() async {
    await db.insert('environments', {
      'name': '新地点',
      'location_type': 'custom',
      'equipment_list': '["bodyweight"]',
      'default_weights': '{}',
      'is_default': 0,
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('训练地点管理')),
      body: ListView.builder(
        itemCount: envs.length,
        itemBuilder: (_, i) => ListTile(
          title: Text(envs[i]['name']),
          subtitle: Text('器械: ${envs[i]['equipment_list']}'),
          trailing: IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EnvEditPage(env: envs[i]))).then((_) => _load()),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(onPressed: _addEnv, child: const Icon(Icons.add)),
    );
  }
}

class EnvEditPage extends StatefulWidget {
  final Map<String, dynamic> env;
  const EnvEditPage({super.key, required this.env});
  @override
  State<EnvEditPage> createState() => _EnvEditPageState();
}

class _EnvEditPageState extends State<EnvEditPage> {
  late TextEditingController nameCtrl;
  late TextEditingController equipCtrl;
  late TextEditingController weightsCtrl;
  final db = DBHelper();

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.env['name']);
    equipCtrl = TextEditingController(text: widget.env['equipment_list']);
    weightsCtrl = TextEditingController(text: widget.env['default_weights']);
  }

  Future<void> _save() async {
    await db.update('environments', {
      'name': nameCtrl.text,
      'equipment_list': equipCtrl.text,
      'default_weights': weightsCtrl.text,
    }, 'id = ?', [widget.env['id']]);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('编辑地点')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '地点名称')),
            TextField(controller: equipCtrl, decoration: const InputDecoration(labelText: '器械列表 (JSON数组)')),
            TextField(controller: weightsCtrl, decoration: const InputDecoration(labelText: '默认重量 (JSON对象)'), maxLines: 5),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _save, child: const Text('保存')),
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final apiKeyCtrl = TextEditingController();
  final kimi = KimiApiService();

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final key = await kimi.getApiKey();
    if (key != null) apiKeyCtrl.text = key;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kimi API Key', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text('用于"请求教练调整"功能，在 platform.moonshot.cn 获取', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 10),
            TextField(
              controller: apiKeyCtrl,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'sk-...', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                await kimi.setApiKey(apiKeyCtrl.text);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('API Key 已保存')));
              },
              child: const Text('保存'),
            ),
            const Divider(height: 40),
            const Text('数据备份', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('导出数据库'),
              subtitle: const Text('将 fitness.db 导出到手机存储'),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}
