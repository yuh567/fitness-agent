import 'package:flutter/material.dart';
import 'dart:async';
import 'database/db_helper.dart';
import 'models.dart';
// import 'package:wakelock/wakelock.dart'; // 如需亮屏功能请取消注释并添加依赖

class WorkoutPage extends StatefulWidget {
  final Map<String, dynamic> plan;
  final List<Map<String, dynamic>> exercises;

  const WorkoutPage({
    super.key,
    required this.plan,
    required this.exercises,
  });

  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> with TickerProviderStateMixin {
  late final List<ExerciseRecord> _records;
  int _currentExerciseIndex = 0;

  // 全局计时器
  late DateTime _workoutStartTime;
  Timer? _workoutTimer;
  int _elapsedSeconds = 0;

  // 休息计时器
  Timer? _restTimer;
  int _restSecondsRemaining = 0;
  int _restTotalSeconds = 0;
  bool _isResting = false;

  // 重量编辑
  final Map<int, TextEditingController> _weightControllers = {};

  // 实际次数输入
  final Map<int, Map<int, TextEditingController>> _repsControllers = {};
  final Map<int, Map<int, FocusNode>> _repsFocusNodes = {};

  // RPE
  double _currentRpe = 7;

  // 动画
  late AnimationController _restAnimationController;

  // 上次使用重量缓存
  Map<int, double> _lastUsedWeights = {};

  DBHelper get _db => DBHelper();

  ExerciseRecord get _currentRecord => _records[_currentExerciseIndex];

  int get _totalSetsAcrossAll {
    return _records.fold(0, (sum, r) => sum + r.sets.length);
  }

  int get _completedSetsAcrossAll {
    return _records.fold(0, (sum, r) => sum + r.sets.where((s) => s.completed).length);
  }

  @override
  void initState() {
    super.initState();
    _workoutStartTime = DateTime.now();
    _records = widget.exercises.map((e) {
      final ex = Exercise.fromMap(e);
      final sets = List.generate(
        ex.targetSets,
        (i) => WorkoutSet(setNumber: i + 1, targetReps: ex.targetReps),
      );
      return ExerciseRecord(exercise: ex, sets: sets, weight: ex.targetWeight);
    }).toList();

    for (var i = 0; i < _records.length; i++) {
      _weightControllers[i] = TextEditingController(
        text: _records[i].weight.toStringAsFixed(1).replaceAll('.0', ''),
      );
      _repsControllers[i] = {};
      _repsFocusNodes[i] = {};
      for (var j = 0; j < _records[i].sets.length; j++) {
        _repsControllers[i]![j] = TextEditingController();
        _repsFocusNodes[i]![j] = FocusNode();
      }
    }

    _restAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _startWorkoutTimer();
    _loadLastUsedWeights();
    // _enableWakelock();
  }

  Future<void> _loadLastUsedWeights() async {
    for (var record in _records) {
      final logs = await _db.query(
        'workout_logs',
        where: 'exercise_id = ?',
        whereArgs: [record.exercise.id],
        orderBy: 'completed_at DESC',
      );
      if (logs.isNotEmpty) {
        final w = (logs.first['weight'] as num?)?.toDouble();
        if (w != null && w > 0) {
          setState(() {
            _lastUsedWeights[record.exercise.id] = w;
          });
        }
      }
    }
  }

  // void _enableWakelock() {
  //   try {
  //     Wakelock.enable();
  //   } catch (_) {}
  // }

  // void _disableWakelock() {
  //   try {
  //     Wakelock.disable();
  //   } catch (_) {}
  // }

  void _startWorkoutTimer() {
    _workoutTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds++;
      });
    });
  }

  String get _elapsedTimeText {
    final m = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _startRest(int seconds) {
    _restTotalSeconds = seconds;
    _restSecondsRemaining = seconds;
    _isResting = true;
    _restAnimationController.duration = Duration(seconds: seconds);
    _restAnimationController.reset();
    _restAnimationController.forward();

    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_restSecondsRemaining <= 1) {
        _restTimer?.cancel();
        setState(() {
          _isResting = false;
          _restSecondsRemaining = 0;
        });
        // 休息结束可添加提示音
      } else {
        setState(() {
          _restSecondsRemaining--;
        });
      }
    });
    setState(() {});
  }

  void _adjustRest(int delta) {
    setState(() {
      _restSecondsRemaining = (_restSecondsRemaining + delta).clamp(5, 600);
      _restTotalSeconds = _restTotalSeconds + delta;
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    setState(() {
      _isResting = false;
      _restSecondsRemaining = 0;
    });
  }

  void _changeWeight(double delta) {
    final record = _currentRecord;
    final newWeight = ((record.weight + delta) * 2).round() / 2;
    if (newWeight < 0) return;
    setState(() {
      record.weight = newWeight;
      _weightControllers[_currentExerciseIndex]?.text =
          newWeight.toStringAsFixed(1).replaceAll('.0', '');
    });
  }

  void _setWeightFromController() {
    final text = _weightControllers[_currentExerciseIndex]?.text ?? '';
    final val = double.tryParse(text);
    if (val != null && val >= 0) {
      setState(() {
        _currentRecord.weight = val;
      });
    }
  }

  void _completeSet(int setIndex) {
    final record = _currentRecord;
    final set = record.sets[setIndex];
    final repsText = _repsControllers[_currentExerciseIndex]?[setIndex]?.text ?? '';
    final reps = int.tryParse(repsText);

    if (reps == null || reps < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效次数'), duration: Duration(seconds: 1)),
      );
      return;
    }

    setState(() {
      set.actualReps = reps;
      set.completed = true;
    });

    // 自动开始休息（如果还有下一组）
    final hasNextIncomplete = record.sets.any((s) => !s.completed);
    if (hasNextIncomplete) {
      _startRest(record.exercise.defaultRestSeconds);
    } else {
      // 本动作全部完成，显示RPE
      _showRpeDialog();
    }
  }

  void _showRpeDialog() {
    _currentRpe = 7;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${_currentRecord.exercise.name} 已完成',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text('主观疲劳度 RPE（1-10）', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('${_currentRpe.toInt()}', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Slider(
                          value: _currentRpe,
                          min: 1,
                          max: 10,
                          divisions: 9,
                          activeColor: Colors.deepOrange,
                          inactiveColor: Colors.grey[800],
                          label: '${_currentRpe.toInt()}',
                          onChanged: (v) => setModalState(() => _currentRpe = v),
                        ),
                        Text(
                          _rpeText(_currentRpe),
                          style: const TextStyle(color: Colors.deepOrange, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _saveExerciseLog();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('确认并保存', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  String _rpeText(double rpe) {
    final v = rpe.toInt();
    if (v <= 4) return '太轻松，下次加重';
    if (v <= 7) return '刚好，保持进步';
    if (v <= 9) return '有挑战，不错';
    return '力竭，注意恢复';
  }

  Future<void> _saveExerciseLog() async {
    final record = _currentRecord;
    final repsList = record.sets.map((s) => s.actualReps ?? 0).join(',');
    final avgRpe = _currentRpe;

    await _db.insert('workout_logs', {
      'plan_id': widget.plan['id'],
      'exercise_id': record.exercise.id,
      'location_id': widget.plan['location_id'],
      'weight': record.weight,
      'sets': record.sets.length,
      'reps': repsList,
      'rpe': avgRpe,
      'notes': '',
      'completed_at': DateTime.now().toIso8601String(),
    });

    if (_currentExerciseIndex < _records.length - 1) {
      setState(() {
        _currentExerciseIndex++;
      });
    } else {
      _finishWorkout();
    }
  }

  void _finishWorkout() async {
    _workoutTimer?.cancel();
    _restTimer?.cancel();
    // _disableWakelock();

    await _db.update('training_plans', {'status': 'completed'}, 'id = ?', [widget.plan['id']]);

    final summary = _buildSummary();
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _WorkoutSummaryDialog(summary: summary),
    );
  }

  WorkoutSummary _buildSummary() {
    int totalSets = 0;
    int completedSets = 0;
    double totalVolume = 0;
    double totalRpe = 0;
    int rpeCount = 0;

    for (var record in _records) {
      for (var set in record.sets) {
        totalSets++;
        if (set.completed) {
          completedSets++;
          totalVolume += record.weight * (set.actualReps ?? 0);
        }
      }
    }

    // 从数据库读取本次RPE（简化：使用当前记忆值或默认值）
    // 实际项目中应查询本次plan的logs
    final avgRpe = rpeCount > 0 ? totalRpe / rpeCount : 7.0;
    final duration = Duration(seconds: _elapsedSeconds);
    final minutes = duration.inMinutes;
    final estimatedCalories = (minutes * 8).clamp(50, 2000);

    return WorkoutSummary(
      totalDuration: duration,
      totalVolume: totalVolume,
      completedExercises: _records.where((r) => r.sets.every((s) => s.completed)).length,
      totalSets: completedSets,
      averageRpe: avgRpe,
      estimatedCalories: estimatedCalories,
    );
  }

  void _goToPreviousExercise() {
    if (_currentExerciseIndex > 0) {
      setState(() => _currentExerciseIndex--);
    }
  }

  void _goToNextExercise() {
    if (_currentExerciseIndex < _records.length - 1) {
      setState(() => _currentExerciseIndex++);
    }
  }

  void _showPauseOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('暂停训练', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.pause_circle, color: Colors.orange),
                title: const Text('今天不舒服，暂停训练', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pauseAndSave('暂停');
                },
              ),
              ListTile(
                leading: const Icon(Icons.sick, color: Colors.red),
                title: const Text('标记今天生病', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _markAbsence('生病');
                },
              ),
              ListTile(
                leading: const Icon(Icons.bedtime, color: Colors.blue),
                title: const Text('标记今天休息', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _markAbsence('休息');
                },
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消', style: TextStyle(color: Colors.grey)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pauseAndSave(String reason) async {
    _workoutTimer?.cancel();
    _restTimer?.cancel();
    // _disableWakelock();
    await _db.update('training_plans', {'status': 'paused'}, 'id = ?', [widget.plan['id']]);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('训练已$reason')));
    }
  }

  void _markAbsence(String reason) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    await _db.insert('absence_records', {
      'date': today,
      'reason': reason,
      'planned_day_type': widget.plan['day_type'] ?? 'push',
      'auto_flag': 0,
    });
    await _db.update('training_plans', {'status': 'absent'}, 'id = ?', [widget.plan['id']]);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已标记：$reason')));
    }
  }

  @override
  void dispose() {
    _workoutTimer?.cancel();
    _restTimer?.cancel();
    _restAnimationController.dispose();
    for (var c in _weightControllers.values) {
      c.dispose();
    }
    for (var map in _repsControllers.values) {
      for (var c in map.values) {
        c.dispose();
      }
    }
    for (var map in _repsFocusNodes.values) {
      for (var n in map.values) {
        n.dispose();
      }
    }
    // _disableWakelock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        title: const Text('铁匠铺 · 训练中', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.redAccent),
          onPressed: _showPauseOptions,
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopStats(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildExerciseCard(),
                      const SizedBox(height: 16),
                      _buildWeightSelector(),
                      const SizedBox(height: 16),
                      _buildSetsList(),
                      const SizedBox(height: 100), // 底部栏空间
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isResting) _buildRestOverlay(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopStats() {
    return Container(
      color: const Color(0xFF1E1E1E),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              const Text('训练时长', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text(_elapsedTimeText, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
            ],
          ),
          Container(width: 1, height: 36, color: Colors.grey[800]),
          Column(
            children: [
              const Text('动作进度', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text(
                '动作 ${_currentExerciseIndex + 1} / ${_records.length}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          Container(width: 1, height: 36, color: Colors.grey[800]),
          Column(
            children: [
              const Text('总组数', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text(
                '$_completedSetsAcrossAll / $_totalSetsAcrossAll',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard() {
    final ex = _currentRecord.exercise;
    return Card(
      color: const Color(0xFF1E1E1E),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ex.name,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    ex.targetMuscle,
                    style: const TextStyle(fontSize: 12, color: Colors.deepOrange, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildExpandableDescription(ex.description),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.format_list_numbered, size: 18, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  '目标：${ex.targetSets} 组 × ${ex.targetReps} 次',
                  style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                ),
              ],
            ),
            if (ex.adjustmentNote != null && ex.adjustmentNote!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.auto_graph, size: 16, color: Colors.green[400]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ex.adjustmentNote!,
                      style: TextStyle(fontSize: 12, color: Colors.green[400]),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableDescription(String description) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text('动作说明', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        iconColor: Colors.deepOrange,
        collapsedIconColor: Colors.grey[600],
        children: [
          Text(
            description,
            style: TextStyle(fontSize: 14, color: Colors.grey[300], height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightSelector() {
    final record = _currentRecord;
    final lastWeight = _lastUsedWeights[record.exercise.id];

    return Card(
      color: const Color(0xFF1E1E1E),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('重量设置', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildBigButton(
                  icon: Icons.remove,
                  onPressed: () => _changeWeight(-2.5),
                  color: Colors.grey[800]!,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: TextField(
                        controller: _weightControllers[_currentExerciseIndex],
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          hintText: '0',
                          hintStyle: TextStyle(color: Colors.grey),
                          suffixText: 'kg',
                          suffixStyle: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        onSubmitted: (_) => _setWeightFromController(),
                        onTapOutside: (_) => _setWeightFromController(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _buildBigButton(
                  icon: Icons.add,
                  onPressed: () => _changeWeight(2.5),
                  color: Colors.deepOrange,
                ),
              ],
            ),
            if (lastWeight != null) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('上次使用：${lastWeight.toStringAsFixed(1).replaceAll('.0', '')}kg', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBigButton({required IconData icon, required VoidCallback onPressed, required Color color}) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildSetsList() {
    final record = _currentRecord;
    return Card(
      color: const Color(0xFF1E1E1E),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('组数记录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(
                  '${record.sets.where((s) => s.completed).length} / ${record.sets.length} 组完成',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(record.sets.length, (i) => _buildSetRow(i)),
          ],
        ),
      ),
    );
  }

  Widget _buildSetRow(int index) {
    final set = _currentRecord.sets[index];
    final isCompleted = set.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFF1A2E1A) : const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: isCompleted
            ? Border.all(color: Colors.green.withOpacity(0.3))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isCompleted ? Colors.green.withOpacity(0.2) : Colors.grey[800],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.green, size: 20)
                  : Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text('目标 ${set.targetReps} 次', style: TextStyle(fontSize: 14, color: Colors.grey[400])),
          ),
          Expanded(
            flex: 3,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _repsControllers[_currentExerciseIndex]?[index],
                focusNode: _repsFocusNodes[_currentExerciseIndex]?[index],
                enabled: !isCompleted,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: '__',
                  hintStyle: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 72,
            height: 48,
            child: ElevatedButton(
              onPressed: isCompleted ? null : () => _completeSet(index),
              style: ElevatedButton.styleFrom(
                backgroundColor: isCompleted ? Colors.green.withOpacity(0.2) : Colors.deepOrange,
                foregroundColor: isCompleted ? Colors.green : Colors.white,
                disabledBackgroundColor: Colors.green.withOpacity(0.15),
                disabledForegroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: EdgeInsets.zero,
              ),
              child: isCompleted
                  ? const Text('完成', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))
                  : const Text('完成', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestOverlay() {
    final progress = _restTotalSeconds > 0 ? _restSecondsRemaining / _restTotalSeconds : 0.0;

    return Container(
      color: const Color(0xFF121212).withOpacity(0.95),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('组间休息', style: TextStyle(fontSize: 18, color: Colors.grey)),
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 12,
                      backgroundColor: Colors.grey[800],
                      valueColor: const AlwaysStoppedAnimation(Colors.deepOrange),
                    ),
                    Center(
                      child: Text(
                        '$_restSecondsRemaining',
                        style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '秒',
                style: TextStyle(fontSize: 18, color: Colors.grey[500]),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildRestButton(
                    label: '-15秒',
                    onPressed: () => _adjustRest(-15),
                  ),
                  const SizedBox(width: 16),
                  _buildRestButton(
                    label: '+15秒',
                    onPressed: () => _adjustRest(15),
                  ),
                  const SizedBox(width: 16),
                  _buildRestButton(
                    label: '跳过休息',
                    onPressed: _skipRest,
                    color: Colors.redAccent,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRestButton({required String label, required VoidCallback onPressed, Color? color}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? const Color(0xFF2A2A2A),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildBottomBar() {
    final bool hasPrev = _currentExerciseIndex > 0;
    final bool hasNext = _currentExerciseIndex < _records.length - 1;

    return Container(
      color: const Color(0xFF1E1E1E),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildBottomActionButton(
                    label: '上一个',
                    onPressed: hasPrev ? _goToPreviousExercise : null,
                    color: Colors.grey[700]!,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _finishWorkout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                      ),
                      child: const Text(
                        '完成训练',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBottomActionButton(
                    label: '下一个',
                    onPressed: hasNext ? _goToNextExercise : null,
                    color: Colors.grey[700]!,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _showPauseOptions,
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                child: const Text('暂停 / 生病报备', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionButton({required String label, required VoidCallback? onPressed, required Color color}) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[800],
          disabledForegroundColor: Colors.grey[600],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: EdgeInsets.zero,
        ),
        child: Text(label, style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}

class _WorkoutSummaryDialog extends StatelessWidget {
  final WorkoutSummary summary;

  const _WorkoutSummaryDialog({required this.summary});

  @override
  Widget build(BuildContext context) {
    final m = summary.totalDuration.inMinutes;
    final s = summary.totalDuration.inSeconds % 60;
    final timeText = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_fire_department, size: 48, color: Colors.deepOrange),
            const SizedBox(height: 12),
            const Text(
              '今日锻造完成！',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 24),
            _buildStatRow('总时长', timeText, Icons.timer),
            _buildStatRow('总容量', '${summary.totalVolume.toStringAsFixed(1)} kg·次', Icons.fitness_center),
            _buildStatRow('完成动作', '${summary.completedExercises} 个', Icons.sports_gymnastics),
            _buildStatRow('总组数', '${summary.totalSets} 组', Icons.format_list_numbered),
            _buildStatRow('平均RPE', summary.averageRpe.toStringAsFixed(1), Icons.speed),
            _buildStatRow('估算消耗', '${summary.estimatedCalories} kcal', Icons.local_fire_department),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // 可扩展：跳转到训练详情页
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepOrange,
                      side: const BorderSide(color: Colors.deepOrange),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('查看详情'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('返回首页'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[400])),
          ),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }
}
