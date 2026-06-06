
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database/db_helper.dart';
import 'home_page.dart';
import 'onboarding.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FitnessAgentApp());
}

class FitnessAgentApp extends StatelessWidget {
  const FitnessAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '铁匠铺',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange, brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardTheme: const CardTheme(color: Color(0xFF1E1E1E), elevation: 4),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1E1E1E)),
        useMaterial3: true,
      ),
      routes: {
        '/home': (context) => const HomePage(),
      },
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final hasOnboarded = prefs.getBool('has_onboarded') ?? false;
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => hasOnboarded ? const HomePage() : const OnboardingFlow(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center, size: 80, color: Colors.deepOrange),
            const SizedBox(height: 20),
            const Text(
              '铁匠铺',
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.deepOrange),
            ),
            const SizedBox(height: 8),
            const Text(
              '锻造更强版本的自己',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: Colors.deepOrange),
          ],
        ),
      ),
    );
  }
}

// ========== 身体数据页 ==========
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

// ========== 训练地点管理页 ==========
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
