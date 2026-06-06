import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'database/db_helper.dart';
import 'kimi_service.dart';
import 'utils.dart';
import 'models.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _db = DBHelper();
  final _kimi = KimiApiService();
  final _apiKeyCtrl = TextEditingController();

  UserProfile? _profile;
  bool _isLoading = false;

  // 训练偏好
  int _trainingDays = 4;
  int _trainingDuration = 60;
  int _restDuration = 90;
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);

  // 器材
  List<UserEquipment> _equipmentList = [];

  // 目标
  FitnessGoals? _goals;

  // AI
  String? _lastAiAdjustTime;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    await _loadProfile();
    await _loadPreferences();
    await _loadEquipment();
    await _loadGoals();
    await _loadApiKey();
    await _loadLastAiTime();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadProfile() async {
    final rows = await _db.query('user_profile');
    if (rows.isNotEmpty) {
      _profile = UserProfile.fromMap(rows.first);
    } else {
      _profile = UserProfile(name: '铁匠');
    }
  }

  Future<void> _saveProfile() async {
    if (_profile == null) return;
    final map = _profile!.toMap();
    final rows = await _db.query('user_profile');
    if (rows.isNotEmpty) {
      await _db.update('user_profile', map, 'id = ?', [rows.first['id']]);
    } else {
      map['created_at'] = DateTime.now().toIso8601String();
      await _db.insert('user_profile', map);
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _trainingDays = prefs.getInt('training_days') ?? 4;
      _trainingDuration = prefs.getInt('training_duration') ?? 60;
      _restDuration = prefs.getInt('rest_duration') ?? 90;
      _reminderEnabled = prefs.getBool('reminder_enabled') ?? false;
      final hour = prefs.getInt('reminder_hour') ?? 20;
      final minute = prefs.getInt('reminder_minute') ?? 0;
      _reminderTime = TimeOfDay(hour: hour, minute: minute);
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('training_days', _trainingDays);
    await prefs.setInt('training_duration', _trainingDuration);
    await prefs.setInt('rest_duration', _restDuration);
    await prefs.setBool('reminder_enabled', _reminderEnabled);
    await prefs.setInt('reminder_hour', _reminderTime.hour);
    await prefs.setInt('reminder_minute', _reminderTime.minute);
  }

  Future<void> _loadEquipment() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('user_equipment_list');
    if (jsonStr != null && jsonStr.isNotEmpty) {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      _equipmentList = list.map((e) => UserEquipment.fromMap(e as Map<String, dynamic>)).toList();
    } else {
      _equipmentList = [];
    }
  }

  Future<void> _saveEquipment() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _equipmentList.map((e) => e.toMap()).toList();
    await prefs.setString('user_equipment_list', jsonEncode(list));
  }

  Future<void> _loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('fitness_goals');
    if (jsonStr != null && jsonStr.isNotEmpty) {
      _goals = FitnessGoals.fromJson(jsonStr);
    } else {
      _goals = FitnessGoals(type: 'muscle_gain', targetValue: 0);
    }
  }

  Future<void> _saveGoals() async {
    if (_goals == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fitness_goals', _goals!.toJson());
    // 同步到 user_profile 的 goal 字段
    if (_profile != null) {
      final updatedProfile = UserProfile(
        id: _profile!.id,
        name: _profile!.name,
        gender: _profile!.gender,
        age: _profile!.age,
        height: _profile!.height,
        weight: _profile!.weight,
        bodyFat: _profile!.bodyFat,
        goal: getGoalTypeName(_goals!.type),
        experienceLevel: _profile!.experienceLevel,
        trainingDaysPerWeek: _profile!.trainingDaysPerWeek,
        preferredDuration: _profile!.preferredDuration,
        createdAt: _profile!.createdAt,
      );
      _profile = updatedProfile;
      await _saveProfile();
    }
  }

  Future<void> _loadApiKey() async {
    final key = await _kimi.getApiKey();
    if (key != null) _apiKeyCtrl.text = key;
  }

  Future<void> _loadLastAiTime() async {
    final prefs = await SharedPreferences.getInstance();
    _lastAiAdjustTime = prefs.getString('last_ai_adjust_time');
  }

  Future<void> _setLastAiTime() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toIso8601String();
    await prefs.setString('last_ai_adjust_time', now);
    setState(() => _lastAiAdjustTime = now);
  }

  // ========== 构建 UI ==========
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('设置', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepOrange)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileCard(),
            const SizedBox(height: 16),
            _buildTrainingPreferences(),
            const SizedBox(height: 16),
            _buildEquipmentManager(),
            const SizedBox(height: 16),
            _buildGoalManager(),
            const SizedBox(height: 16),
            _buildAiSettings(),
            const SizedBox(height: 16),
            _buildDataManagement(),
            const SizedBox(height: 32),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final level = calculateExperienceLevel(
      _profile?.experienceLevel != null ? int.tryParse(_profile!.experienceLevel!) ?? 0 : 0,
      0,
    );
    return Card(
      color: const Color(0xFF1E1E1E),
      elevation: 4,
      child: InkWell(
        onTap: _showEditProfileDialog,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.deepOrange.withOpacity(0.2),
                child: const Icon(Icons.person, size: 32, color: Colors.deepOrange),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _profile?.name ?? '铁匠',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '训练等级：$level',
                      style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '身高 ${_profile?.height?.toStringAsFixed(1) ?? '--'}cm · 体重 ${_profile?.weight?.toStringAsFixed(1) ?? '--'}kg · 体脂 ${_profile?.bodyFat?.toStringAsFixed(1) ?? '--'}%',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.edit, color: Colors.deepOrange),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _profile?.name ?? '铁匠');
    final heightCtrl = TextEditingController(text: _profile?.height?.toString() ?? '');
    final weightCtrl = TextEditingController(text: _profile?.weight?.toString() ?? '');
    final fatCtrl = TextEditingController(text: _profile?.bodyFat?.toString() ?? '');
    final goalCtrl = TextEditingController(text: _profile?.goal ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('编辑个人资料', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: _inputDeco('昵称'), style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              TextField(controller: heightCtrl, decoration: _inputDeco('身高 (cm)'), keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              TextField(controller: weightCtrl, decoration: _inputDeco('体重 (kg)'), keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              TextField(controller: fatCtrl, decoration: _inputDeco('体脂率 (%)'), keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              TextField(controller: goalCtrl, decoration: _inputDeco('目标描述'), style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
            onPressed: () async {
              final updatedProfile = UserProfile(
                id: _profile?.id,
                name: nameCtrl.text.isEmpty ? null : nameCtrl.text,
                gender: _profile?.gender,
                age: _profile?.age,
                height: double.tryParse(heightCtrl.text),
                weight: double.tryParse(weightCtrl.text),
                bodyFat: double.tryParse(fatCtrl.text),
                goal: goalCtrl.text.isEmpty ? null : goalCtrl.text,
                experienceLevel: _profile?.experienceLevel,
                trainingDaysPerWeek: _profile?.trainingDaysPerWeek,
                preferredDuration: _profile?.preferredDuration,
                createdAt: _profile?.createdAt,
              );
              _profile = updatedProfile;
              await _saveProfile();
              if (mounted) {
                setState(() {});
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('个人资料已保存')));
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingPreferences() {
    return Card(
      color: const Color(0xFF1E1E1E),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('训练偏好设置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('每周训练天数', style: TextStyle(color: Colors.grey[300])),
                Text('$_trainingDays 天', style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
              ],
            ),
            Slider(
              value: _trainingDays.toDouble(),
              min: 1,
              max: 7,
              divisions: 6,
              label: '$_trainingDays',
              activeColor: Colors.deepOrange,
              onChanged: (v) => setState(() => _trainingDays = v.round()),
              onChangeEnd: (_) => _savePreferences(),
            ),
            const Divider(color: Color(0xFF333333)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('每次训练时长', style: TextStyle(color: Colors.grey[300])),
                Text('$_trainingDuration 分钟', style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
              ],
            ),
            Slider(
              value: _trainingDuration.toDouble(),
              min: 15,
              max: 150,
              divisions: 9,
              label: '$_trainingDuration',
              activeColor: Colors.deepOrange,
              onChanged: (v) => setState(() => _trainingDuration = (v / 15).round() * 15),
              onChangeEnd: (_) => _savePreferences(),
            ),
            const Divider(color: Color(0xFF333333)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('默认组间休息', style: TextStyle(color: Colors.grey[300])),
                Text('$_restDuration 秒', style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
              ],
            ),
            Slider(
              value: _restDuration.toDouble(),
              min: 30,
              max: 300,
              divisions: 9,
              label: '$_restDuration',
              activeColor: Colors.deepOrange,
              onChanged: (v) => setState(() => _restDuration = (v / 30).round() * 30),
              onChangeEnd: (_) => _savePreferences(),
            ),
            const Divider(color: Color(0xFF333333)),
            SwitchListTile(
              title: Text('训练提醒', style: TextStyle(color: Colors.grey[300])),
              subtitle: Text(_reminderEnabled ? '每天 ${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}' : '未开启', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              value: _reminderEnabled,
              activeColor: Colors.deepOrange,
              onChanged: (v) async {
                setState(() => _reminderEnabled = v);
                if (v) {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _reminderTime,
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.dark(primary: Colors.deepOrange),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) setState(() => _reminderTime = picked);
                }
                await _savePreferences();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentManager() {
    return Card(
      color: const Color(0xFF1E1E1E),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('器材管理', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.deepOrange),
                  onPressed: _showAddEquipmentDialog,
                ),
              ],
            ),
            if (_equipmentList.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(child: Text('暂无器材，点击 + 添加', style: TextStyle(color: Colors.grey[500]))),
              )
            else
              ..._equipmentList.map((e) => ListTile(
                dense: true,
                leading: const Icon(Icons.fitness_center, color: Colors.deepOrange, size: 20),
                title: Text(e.name ?? '', style: const TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: Text('${e.equipmentType} · 最大 ${e.maxWeight != null ? formatWeight(e.maxWeight!) : '无限制'}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  onPressed: () async {
                    setState(() => _equipmentList.remove(e));
                    await _saveEquipment();
                  },
                ),
              )),
          ],
        ),
      ),
    );
  }

  void _showAddEquipmentDialog() {
    final nameCtrl = TextEditingController();
    final weightCtrl = TextEditingController();
    String selectedType = 'gym';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('添加器材', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: _inputDeco('器材名称'), style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  dropdownColor: const Color(0xFF2A2A2A),
                  decoration: _inputDeco('器材类型'),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: 'gym', child: Text('健身房器械', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 'dumbbell', child: Text('哑铃', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 'bodyweight', child: Text('自重', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 'band', child: Text('弹力带', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 'kettlebell', child: Text('壶铃', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 'other', child: Text('其他', style: TextStyle(color: Colors.white))),
                  ],
                  onChanged: (v) => setModalState(() => selectedType = v!),
                ),
                const SizedBox(height: 8),
                TextField(controller: weightCtrl, decoration: _inputDeco('最大重量 (kg，可选)'), keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
              onPressed: () async {
                if (nameCtrl.text.isEmpty) return;
                final eq = UserEquipment(
                  name: nameCtrl.text,
                  equipmentType: selectedType,
                  maxWeight: double.tryParse(weightCtrl.text),
                );
                setState(() => _equipmentList.add(eq));
                await _saveEquipment();
                if (mounted) Navigator.pop(ctx);
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalManager() {
    final goal = _goals;
    final progress = goal != null && goal.targetValue > 0
        ? calculateGoalProgress(goal.currentValue ?? 0, goal.targetValue, goal.type)
        : 0.0;

    return Card(
      color: const Color(0xFF1E1E1E),
      elevation: 4,
      child: InkWell(
        onTap: _showEditGoalDialog,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('目标管理', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  const Icon(Icons.edit, color: Colors.deepOrange, size: 18),
                ],
              ),
              const SizedBox(height: 12),
              if (goal == null || goal.targetValue == 0)
                Text('尚未设置目标，点击编辑', style: TextStyle(color: Colors.grey[500]))
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${getGoalTypeName(goal.type)} · ${goal.targetValue}${goal.unit ?? ''}',
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ),
                    if (goal.deadline != null)
                      Text('期限：${goal.deadline}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[800],
                  valueColor: const AlwaysStoppedAnimation(Colors.deepOrange),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 6),
                Text('完成进度：${(progress * 100).toStringAsFixed(1)}%', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showEditGoalDialog() {
    final goal = _goals ?? FitnessGoals(type: 'muscle_gain', targetValue: 0);
    String selectedType = goal.type;
    final targetCtrl = TextEditingController(text: goal.targetValue > 0 ? goal.targetValue.toString() : '');
    final currentCtrl = TextEditingController(text: goal.currentValue != null ? goal.currentValue.toString() : '');
    final unitCtrl = TextEditingController(text: goal.unit ?? '');
    final deadlineCtrl = TextEditingController(text: goal.deadline ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('编辑目标', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedType,
                  dropdownColor: const Color(0xFF2A2A2A),
                  decoration: _inputDeco('目标类型'),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: 'muscle_gain', child: Text('增肌', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 'weight_loss', child: Text('减脂', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 'strength', child: Text('增力', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 'endurance', child: Text('耐力', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 'maintenance', child: Text('维持', style: TextStyle(color: Colors.white))),
                  ],
                  onChanged: (v) => setModalState(() => selectedType = v!),
                ),
                const SizedBox(height: 8),
                TextField(controller: targetCtrl, decoration: _inputDeco('目标数值'), keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 8),
                TextField(controller: currentCtrl, decoration: _inputDeco('当前数值（可选）'), keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 8),
                TextField(controller: unitCtrl, decoration: _inputDeco('单位（如 kg, %, cm）'), style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 8),
                TextField(controller: deadlineCtrl, decoration: _inputDeco('期限（如 2026-12-31）'), style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
              onPressed: () async {
                _goals = FitnessGoals(
                  type: selectedType,
                  targetValue: double.tryParse(targetCtrl.text) ?? 0,
                  currentValue: double.tryParse(currentCtrl.text),
                  unit: unitCtrl.text.isEmpty ? null : unitCtrl.text,
                  deadline: deadlineCtrl.text.isEmpty ? null : deadlineCtrl.text,
                );
                await _saveGoals();
                if (mounted) {
                  setState(() {});
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('目标已保存')));
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiSettings() {
    return Card(
      color: const Color(0xFF1E1E1E),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI 教练设置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            TextField(
              controller: _apiKeyCtrl,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Kimi API Key',
                labelStyle: TextStyle(color: Colors.grey[400]),
                hintText: 'sk-...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[700]!)),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.deepOrange)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.save, color: Colors.deepOrange),
                  onPressed: () async {
                    await _kimi.setApiKey(_apiKeyCtrl.text);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('API Key 已保存')));
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('在 platform.moonshot.cn 获取 API Key', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
                icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.auto_fix_high),
                label: const Text('请求AI重新生成计划'),
                onPressed: _isLoading ? null : () async {
                  setState(() => _isLoading = true);
                  try {
                    final db = DBHelper();
                    final logs = await db.query('workout_logs', orderBy: 'completed_at DESC');
                    final metrics = await db.query('body_metrics', orderBy: 'date DESC');
                    final history = TrainingHistory(
                      totalWorkouts: logs.length,
                      totalVolume: logs.fold<double>(0, (sum, l) => sum + ((l['weight'] as num?)?.toDouble() ?? 0) * (l['sets'] as int? ?? 0)),
                      years: 1,
                    );
                    final result = await _kimi.requestPlanGeneration(
                      _profile ?? UserProfile(name: '铁匠'),
                      _goals ?? FitnessGoals(type: 'muscle_gain', targetValue: 0),
                      history,
                      _equipmentList,
                    );
                    await _setLastAiTime();
                    if (mounted && result != null) {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          backgroundColor: const Color(0xFF1E1E1E),
                          title: const Text('AI 计划生成结果', style: TextStyle(color: Colors.white)),
                          content: SingleChildScrollView(child: Text(result.toString(), style: const TextStyle(color: Colors.white70))),
                          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭'))],
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('错误: $e')));
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.analytics),
                label: const Text('AI分析我的训练数据'),
                onPressed: _isLoading ? null : () async {
                  setState(() => _isLoading = true);
                  try {
                    final db = DBHelper();
                    final logs = await db.query('workout_logs', orderBy: 'completed_at DESC');
                    final metrics = await db.query('body_metrics', orderBy: 'date DESC');
                    final logModels = logs.take(20).map((l) => WorkoutLog.fromMap(l)).toList();
                    final metricModels = metrics.take(10).map((m) => BodyMetrics.fromMap(m)).toList();
                    final result = await _kimi.requestTrainingAnalysis(logModels, metricModels, []);
                    await _setLastAiTime();
                    if (mounted && result != null) {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          backgroundColor: const Color(0xFF1E1E1E),
                          title: const Text('AI 训练分析', style: TextStyle(color: Colors.white)),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('分析摘要', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                                Text(result['analysis']?.toString() ?? '无', style: const TextStyle(color: Colors.white70)),
                                const SizedBox(height: 12),
                                Text('趋势', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                                Text(result['trends']?.toString() ?? '无', style: const TextStyle(color: Colors.white70)),
                                const SizedBox(height: 12),
                                Text('建议', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                                ...(result['recommendations'] as List<dynamic>? ?? []).map((r) => Text('• $r', style: const TextStyle(color: Colors.white70))),
                              ],
                            ),
                          ),
                          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('收到'))],
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('错误: $e')));
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                },
              ),
            ),
            if (_lastAiAdjustTime != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('上次AI调整：$_lastAiAdjustTime', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataManagement() {
    return Card(
      color: const Color(0xFF1E1E1E),
      elevation: 4,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.download, color: Colors.deepOrange),
            title: const Text('导出训练数据', style: TextStyle(color: Colors.white)),
            subtitle: Text('导出为 JSON 格式', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            onTap: _exportData,
          ),
          const Divider(color: Color(0xFF333333), height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
            title: const Text('清除所有数据', style: TextStyle(color: Colors.white)),
            subtitle: Text('此操作不可恢复', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            onTap: _showClearDataDialog,
          ),
          const Divider(color: Color(0xFF333333), height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.blueAccent),
            title: const Text('关于铁匠铺', style: TextStyle(color: Colors.white)),
            onTap: _showAboutDialog,
          ),
        ],
      ),
    );
  }

  Future<void> _exportData() async {
    setState(() => _isLoading = true);
    try {
      final db = DBHelper();
      final data = {
        'export_time': DateTime.now().toIso8601String(),
        'user_profile': await db.query('user_profile'),
        'workout_logs': await db.query('workout_logs', orderBy: 'completed_at DESC'),
        'body_metrics': await db.query('body_metrics', orderBy: 'date DESC'),
        'training_plans': await db.query('training_plans', orderBy: 'date DESC'),
        'absence_records': await db.query('absence_records', orderBy: 'date DESC'),
        'environments': await db.query('environments'),
      };
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text('训练数据导出', style: TextStyle(color: Colors.white)),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(child: Text(jsonStr, style: const TextStyle(color: Colors.white70, fontSize: 12))),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('确认清除所有数据？', style: TextStyle(color: Colors.white)),
        content: const Text('这将删除所有训练记录、身体数据、计划和设置。此操作不可恢复。', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                final db = DBHelper();
                await db.rawQuery('DELETE FROM workout_logs');
                await db.rawQuery('DELETE FROM body_metrics');
                await db.rawQuery('DELETE FROM training_plans');
                await db.rawQuery('DELETE FROM absence_records');
                await db.rawQuery('DELETE FROM user_profile');
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                await _loadAll();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('所有数据已清除')));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('清除失败: $e')));
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('确认清除'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('关于铁匠铺', style: TextStyle(color: Colors.white)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('铁匠铺是一款本地智能健身App，结合AI教练与渐进超负荷算法，帮助你科学锻造身体。', style: TextStyle(color: Colors.white70)),
            SizedBox(height: 12),
            Text('主题：深炭灰 + 活力橙', style: TextStyle(color: Colors.white70, fontSize: 12)),
            Text('数据库：SQLite（本地存储）', style: TextStyle(color: Colors.white70, fontSize: 12)),
            Text('AI引擎：Kimi (Moonshot AI)', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭'))],
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Column(
        children: [
          Text('铁匠铺 v2.0', style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('锻造更强的自己', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[400]),
      border: const OutlineInputBorder(),
      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[700]!)),
      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.deepOrange)),
    );
  }
}
