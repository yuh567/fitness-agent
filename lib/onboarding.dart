import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database/db_helper.dart';
import 'models.dart';

// ============================================================
// 数据模型：收集所有 Onboarding 步骤的数据
// ============================================================
class OnboardingData {
  // Step 1: 基本信息
  String nickname = '';
  String gender = ''; // '男' / '女'
  int? age;
  double? height;
  double? weight;
  double? bodyFat;

  // Step 2: 运动历史
  bool? hasGymExperience;
  String trainingYears = ''; // '0-1年' / '1-3年' / '3-5年' / '5年以上'
  String pastTrainingStyle = ''; // '从未系统训练' / '自己瞎练' / '跟过教练' / '跟过计划APP'
  List<String> injuries = []; // '无', '肩', '腰', '膝', '腕', '其他'
  Map<String, double?> maxWeights = {
    '深蹲': null,
    '卧推': null,
    '硬拉': null,
    '推举': null,
  };

  // Step 3: 器材清单
  List<String> equipment = [];

  // Step 4: 健身目标
  String mainGoal = ''; // '增肌' / '减脂' / '增力' / '耐力' / '综合健康'
  double? targetWeight;
  double? targetBodyFat;
  int weeklyTrainingDays = 3;
  int sessionDuration = 60; // 30, 45, 60, 90
  String goalDeadline = ''; // '1个月' / '3个月' / '6个月' / '1年'
}

// ============================================================
// 主入口：OnboardingFlow
// ============================================================
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final PageController _pageController = PageController();
  final OnboardingData _data = OnboardingData();
  int _currentPage = 0;
  final int _totalPages = 5;

  final List<String> _stepTitles = [
    '基本信息',
    '运动背景',
    '装备清单',
    '健身目标',
    '方案确认',
  ];

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  Future<void> _finishOnboarding() async {
    // 保存到 SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_onboarded', true);
    await prefs.setString('user_nickname', _data.nickname);
    await prefs.setString('user_gender', _data.gender);
    await prefs.setInt('user_age', _data.age ?? 0);
    await prefs.setDouble('user_height', _data.height ?? 0);
    await prefs.setDouble('user_weight', _data.weight ?? 0);
    await prefs.setDouble('user_body_fat', _data.bodyFat ?? 0);
    await prefs.setString('main_goal', _data.mainGoal);
    await prefs.setInt('weekly_training_days', _data.weeklyTrainingDays);
    await prefs.setInt('session_duration', _data.sessionDuration);

    // 保存到数据库
    final db = DBHelper();
    await db.insert('user_profile', {
      'nickname': _data.nickname,
      'gender': _data.gender,
      'age': _data.age,
      'height': _data.height,
      'weight': _data.weight,
      'body_fat': _data.bodyFat,
      'created_at': DateTime.now().toIso8601String(),
    });

    await db.insert('training_history', {
      'has_gym_experience': _data.hasGymExperience == true ? 1 : 0,
      'training_years': _data.trainingYears,
      'past_training_style': _data.pastTrainingStyle,
      'injuries': _data.injuries.join(','),
      'max_squat': _data.maxWeights['深蹲'],
      'max_bench': _data.maxWeights['卧推'],
      'max_deadlift': _data.maxWeights['硬拉'],
      'max_press': _data.maxWeights['推举'],
      'created_at': DateTime.now().toIso8601String(),
    });

    await db.insert('user_equipment', {
      'equipment': _data.equipment.join(','),
      'created_at': DateTime.now().toIso8601String(),
    });

    await db.insert('fitness_goals', {
      'main_goal': _data.mainGoal,
      'target_weight': _data.targetWeight,
      'target_body_fat': _data.targetBodyFat,
      'weekly_training_days': _data.weeklyTrainingDays,
      'session_duration': _data.sessionDuration,
      'goal_deadline': _data.goalDeadline,
      'created_at': DateTime.now().toIso8601String(),
    });

    // 跳转到主页
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          children: [
            // 顶部进度指示器
            _buildProgressIndicator(),
            const SizedBox(height: 8),
            Text(
              _stepTitles[_currentPage],
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            // PageView 内容区
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                physics: const ClampingScrollPhysics(),
                children: [
                  Step1WelcomePage(data: _data),
                  Step2HistoryPage(data: _data),
                  Step3EquipmentPage(data: _data),
                  Step4GoalsPage(data: _data),
                  Step5PreviewPage(data: _data),
                ],
              ),
            ),
            // 底部导航按钮
            _buildBottomNavigation(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_totalPages, (index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 6),
            width: _currentPage == index ? 24 : 10,
            height: 10,
            decoration: BoxDecoration(
              color: _currentPage == index
                  ? Colors.deepOrange
                  : Colors.white24,
              borderRadius: BorderRadius.circular(5),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // 上一步按钮
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _prevPage,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('上一步', style: TextStyle(fontSize: 16)),
              ),
            ),
          if (_currentPage > 0) const SizedBox(width: 12),
          // 下一步 / 开始锻造 按钮
          Expanded(
            flex: _currentPage > 0 ? 1 : 2,
            child: ElevatedButton(
              onPressed: _currentPage == _totalPages - 1
                  ? _finishOnboarding
                  : _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: Text(
                _currentPage == _totalPages - 1 ? '开始锻造' : '下一步',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 可复用组件
// ============================================================

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SubTitle extends StatelessWidget {
  final String text;
  const _SubTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white60,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _CardContainer extends StatelessWidget {
  final Widget child;
  const _CardContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: child,
    );
  }
}

class _DarkInputField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextInputType keyboardType;
  final Function(String) onChanged;
  final String? Function(String?)? validator;
  final TextEditingController? controller;

  const _DarkInputField({
    required this.label,
    this.hint,
    this.keyboardType = TextInputType.text,
    required this.onChanged,
    this.validator,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        onChanged: onChanged,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white60),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white30),
          filled: true,
          fillColor: const Color(0xFF2A2A2A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.deepOrange, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class _SingleChoiceChips extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final Function(String) onSelected;
  final WrapAlignment alignment;

  const _SingleChoiceChips({
    required this.options,
    required this.selected,
    required this.onSelected,
    this.alignment = WrapAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: alignment,
      children: options.map((opt) {
        final isSelected = selected == opt;
        return ChoiceChip(
          label: Text(opt),
          selected: isSelected,
          onSelected: (_) => onSelected(opt),
          selectedColor: Colors.deepOrange,
          backgroundColor: const Color(0xFF2A2A2A),
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isSelected ? Colors.deepOrange : Colors.white24,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MultiChoiceChips extends StatelessWidget {
  final List<String> options;
  final List<String> selected;
  final Function(String, bool) onSelectionChanged;

  const _MultiChoiceChips({
    required this.options,
    required this.selected,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((opt) {
        final isSelected = selected.contains(opt);
        return FilterChip(
          label: Text(opt),
          selected: isSelected,
          onSelected: (val) => onSelectionChanged(opt, val),
          selectedColor: Colors.deepOrange.withOpacity(0.9),
          backgroundColor: const Color(0xFF2A2A2A),
          checkmarkColor: Colors.white,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isSelected ? Colors.deepOrange : Colors.white24,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ============================================================
// Step 1: 欢迎页 + 基本信息
// ============================================================
class Step1WelcomePage extends StatefulWidget {
  final OnboardingData data;
  const Step1WelcomePage({super.key, required this.data});

  @override
  State<Step1WelcomePage> createState() => _Step1WelcomePageState();
}

class _Step1WelcomePageState extends State<Step1WelcomePage> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fitness_center,
                  color: Colors.deepOrange,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Center(
              child: Text(
                '欢迎来到铁匠铺',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                '锻造更强版本的自己',
                style: TextStyle(
                  color: Colors.deepOrange,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 32),
            const _SectionTitle('填写你的基本信息'),
            _DarkInputField(
              label: '昵称',
              hint: '请输入你的昵称',
              onChanged: (v) => widget.data.nickname = v.trim(),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? '昵称不能为空' : null,
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                '性别',
                style: TextStyle(color: Colors.white60, fontSize: 14),
              ),
            ),
            _SingleChoiceChips(
              options: const ['男', '女'],
              selected: widget.data.gender.isEmpty ? null : widget.data.gender,
              onSelected: (v) {
                setState(() => widget.data.gender = v);
              },
            ),
            const SizedBox(height: 16),
            _DarkInputField(
              label: '年龄',
              hint: '例如：25',
              keyboardType: TextInputType.number,
              onChanged: (v) => widget.data.age = int.tryParse(v),
              validator: (v) {
                if (v == null || v.isEmpty) return '年龄不能为空';
                final age = int.tryParse(v);
                if (age == null || age < 10 || age > 100) return '请输入有效年龄';
                return null;
              },
            ),
            _DarkInputField(
              label: '身高 (cm)',
              hint: '例如：175',
              keyboardType: TextInputType.number,
              onChanged: (v) => widget.data.height = double.tryParse(v),
              validator: (v) {
                if (v == null || v.isEmpty) return '身高不能为空';
                final h = double.tryParse(v);
                if (h == null || h < 100 || h > 250) return '请输入有效身高';
                return null;
              },
            ),
            _DarkInputField(
              label: '体重 (kg)',
              hint: '例如：70',
              keyboardType: TextInputType.number,
              onChanged: (v) => widget.data.weight = double.tryParse(v),
              validator: (v) {
                if (v == null || v.isEmpty) return '体重不能为空';
                final w = double.tryParse(v);
                if (w == null || w < 30 || w > 200) return '请输入有效体重';
                return null;
              },
            ),
            _DarkInputField(
              label: '体脂率 (%)',
              hint: '例如：18（可选填）',
              keyboardType: TextInputType.number,
              onChanged: (v) => widget.data.bodyFat = double.tryParse(v),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Step 2: 运动历史
// ============================================================
class Step2HistoryPage extends StatefulWidget {
  final OnboardingData data;
  const Step2HistoryPage({super.key, required this.data});

  @override
  State<Step2HistoryPage> createState() => _Step2HistoryPageState();
}

class _Step2HistoryPageState extends State<Step2HistoryPage> {
  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const _SectionTitle('你的运动背景'),
          const _SubTitle('让我们了解你的训练经历，为你量身定制计划'),
          const SizedBox(height: 8),

          // 问题1
          _buildQuestionCard(
            '是否有健身房经验？',
            _SingleChoiceChips(
              options: const ['是', '否'],
              selected: d.hasGymExperience == null
                  ? null
                  : (d.hasGymExperience! ? '是' : '否'),
              onSelected: (v) {
                setState(() => d.hasGymExperience = v == '是');
              },
            ),
          ),

          // 问题2
          _buildQuestionCard(
            '训练年限',
            _SingleChoiceChips(
              options: const ['0-1年', '1-3年', '3-5年', '5年以上'],
              selected: d.trainingYears.isEmpty ? null : d.trainingYears,
              onSelected: (v) {
                setState(() => d.trainingYears = v);
              },
            ),
          ),

          // 问题3
          _buildQuestionCard(
            '以往训练方式',
            _SingleChoiceChips(
              options: const [
                '从未系统训练',
                '自己瞎练',
                '跟过教练',
                '跟过计划APP'
              ],
              selected:
                  d.pastTrainingStyle.isEmpty ? null : d.pastTrainingStyle,
              onSelected: (v) {
                setState(() => d.pastTrainingStyle = v);
              },
            ),
          ),

          // 问题4
          _buildQuestionCard(
            '主要伤病史（多选）',
            _MultiChoiceChips(
              options: const ['无', '肩', '腰', '膝', '腕', '其他'],
              selected: d.injuries,
              onSelectionChanged: (opt, selected) {
                setState(() {
                  if (opt == '无') {
                    if (selected) {
                      d.injuries = ['无'];
                    } else {
                      d.injuries.remove('无');
                    }
                  } else {
                    d.injuries.remove('无');
                    if (selected) {
                      d.injuries.add(opt);
                    } else {
                      d.injuries.remove(opt);
                    }
                  }
                });
              },
            ),
          ),

          // 问题5
          _buildQuestionCard(
            '各动作最大重量（kg，可选填）',
            Column(
              children: d.maxWeights.keys.map((exercise) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 60,
                        child: Text(
                          exercise,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextFormField(
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          onChanged: (v) {
                            d.maxWeights[exercise] = double.tryParse(v);
                          },
                          decoration: InputDecoration(
                            hintText: '最大重量',
                            hintStyle:
                                const TextStyle(color: Colors.white30),
                            filled: true,
                            fillColor: const Color(0xFF2A2A2A),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: Colors.deepOrange, width: 1),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            suffixText: 'kg',
                            suffixStyle:
                                const TextStyle(color: Colors.white60),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(String question, Widget answerWidget) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _CardContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            answerWidget,
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Step 3: 器材清单
// ============================================================
class Step3EquipmentPage extends StatefulWidget {
  final OnboardingData data;
  const Step3EquipmentPage({super.key, required this.data});

  @override
  State<Step3EquipmentPage> createState() => _Step3EquipmentPageState();
}

class _Step3EquipmentPageState extends State<Step3EquipmentPage> {
  final List<Map<String, dynamic>> _equipmentList = [
    {'name': '健身房会员卡', 'icon': Icons.sports_gymnastics, 'hasEquipment': true},
    {'name': '哑铃套装', 'icon': Icons.fitness_center, 'hasEquipment': false},
    {'name': '杠铃+卧推凳', 'icon': Icons.table_bar, 'hasEquipment': false},
    {'name': '弹力带', 'icon': Icons.linear_scale, 'hasEquipment': false},
    {'name': '壶铃', 'icon': Icons.circle, 'hasEquipment': false},
    {'name': '单杠/引体向上架', 'icon': Icons.horizontal_rule, 'hasEquipment': false},
    {'name': '瑜伽垫', 'icon': Icons.square_foot, 'hasEquipment': false},
    {'name': '跑步机/椭圆机', 'icon': Icons.directions_run, 'hasEquipment': false},
    {'name': '仅自重（无器械）', 'icon': Icons.person, 'hasEquipment': false},
  ];

  @override
  void initState() {
    super.initState();
    // 同步已有选择
    for (var item in _equipmentList) {
      if (widget.data.equipment.contains(item['name'])) {
        item['selected'] = true;
      } else {
        item['selected'] = false;
      }
    }
  }

  void _toggleEquipment(int index) {
    setState(() {
      final item = _equipmentList[index];
      final name = item['name'] as String;
      final selected = !(item['selected'] as bool? ?? false);
      item['selected'] = selected;

      if (name == '仅自重（无器械）') {
        if (selected) {
          // 选择自重时，取消其他所有
          for (var i = 0; i < _equipmentList.length; i++) {
            if (i != index) {
              _equipmentList[i]['selected'] = false;
            }
          }
          widget.data.equipment = [name];
        } else {
          widget.data.equipment.remove(name);
        }
      } else {
        // 选择其他时，取消自重
        final bodyweightIndex = _equipmentList.indexWhere(
            (e) => e['name'] == '仅自重（无器械）');
        if (bodyweightIndex >= 0) {
          _equipmentList[bodyweightIndex]['selected'] = false;
          widget.data.equipment.remove('仅自重（无器械）');
        }

        if (selected) {
          if (!widget.data.equipment.contains(name)) {
            widget.data.equipment.add(name);
          }
        } else {
          widget.data.equipment.remove(name);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const _SectionTitle('你有哪些装备？'),
          const _SubTitle('选择你当前可用的训练器材'),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _equipmentList.length,
            itemBuilder: (context, index) {
              final item = _equipmentList[index];
              final selected = item['selected'] as bool? ?? false;
              return GestureDetector(
                onTap: () => _toggleEquipment(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.deepOrange.withOpacity(0.15)
                        : const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? Colors.deepOrange : Colors.white10,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        color: selected ? Colors.deepOrange : Colors.white60,
                        size: 36,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item['name'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontSize: 14,
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (selected)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.deepOrange,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ============================================================
// Step 4: 健身目标
// ============================================================
class Step4GoalsPage extends StatefulWidget {
  final OnboardingData data;
  const Step4GoalsPage({super.key, required this.data});

  @override
  State<Step4GoalsPage> createState() => _Step4GoalsPageState();
}

class _Step4GoalsPageState extends State<Step4GoalsPage> {
  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const _SectionTitle('你想锻造什么样的身体？'),
          const _SubTitle('设定清晰的目标，让每一次训练都有方向'),
          const SizedBox(height: 8),

          // 主目标
          _buildQuestionCard(
            '主目标',
            _SingleChoiceChips(
              options: const ['增肌', '减脂', '增力', '耐力', '综合健康'],
              selected: d.mainGoal.isEmpty ? null : d.mainGoal,
              onSelected: (v) => setState(() => d.mainGoal = v),
            ),
          ),

          // 目标体重 & 目标体脂
          _buildQuestionCard(
            '目标数据',
            Column(
              children: [
                _DarkInputField(
                  label: '目标体重 (kg)',
                  hint: '例如：65',
                  keyboardType: TextInputType.number,
                  onChanged: (v) => d.targetWeight = double.tryParse(v),
                ),
                _DarkInputField(
                  label: '目标体脂率 (%)',
                  hint: '例如：15',
                  keyboardType: TextInputType.number,
                  onChanged: (v) => d.targetBodyFat = double.tryParse(v),
                ),
              ],
            ),
          ),

          // 每周训练天数
          _buildQuestionCard(
            '每周可训练天数：${d.weeklyTrainingDays} 天',
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.deepOrange,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.deepOrange,
                overlayColor: Colors.deepOrange.withOpacity(0.2),
                valueIndicatorColor: Colors.deepOrange,
                valueIndicatorTextStyle: const TextStyle(color: Colors.white),
              ),
              child: Slider(
                value: d.weeklyTrainingDays.toDouble(),
                min: 1,
                max: 7,
                divisions: 6,
                label: '${d.weeklyTrainingDays}天',
                onChanged: (v) {
                  setState(() => d.weeklyTrainingDays = v.round());
                },
              ),
            ),
          ),

          // 每次训练时长
          _buildQuestionCard(
            '每次训练偏好时长',
            _SingleChoiceChips(
              options: const ['30分钟', '45分钟', '60分钟', '90分钟'],
              selected: d.sessionDuration == 30
                  ? '30分钟'
                  : d.sessionDuration == 45
                      ? '45分钟'
                      : d.sessionDuration == 60
                          ? '60分钟'
                          : d.sessionDuration == 90
                              ? '90分钟'
                              : null,
              onSelected: (v) {
                setState(() {
                  d.sessionDuration = int.parse(v.replaceAll('分钟', ''));
                });
              },
            ),
          ),

          // 目标期限
          _buildQuestionCard(
            '目标期限',
            _SingleChoiceChips(
              options: const ['1个月', '3个月', '6个月', '1年'],
              selected: d.goalDeadline.isEmpty ? null : d.goalDeadline,
              onSelected: (v) => setState(() => d.goalDeadline = v),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(String question, Widget answerWidget) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _CardContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            answerWidget,
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Step 5: 计划预览 + 确认
// ============================================================
class Step5PreviewPage extends StatelessWidget {
  final OnboardingData data;
  const Step5PreviewPage({super.key, required this.data});

  String _getSplitType() {
    final days = data.weeklyTrainingDays;
    if (days <= 2) return '全身训练（Full Body）';
    if (days == 3) return 'Push / Pull / Legs';
    if (days == 4) return '上肢 / 下肢分化';
    if (days == 5) return 'Push / Pull / Legs / 上肢 / 下肢';
    if (days >= 6) return '高频率分化训练';
    return '综合训练计划';
  }

  int _getEstimatedExercises() {
    final duration = data.sessionDuration;
    if (duration <= 30) return 4;
    if (duration <= 45) return 5;
    if (duration <= 60) return 6;
    return 8;
  }

  String _getEstimatedTime() {
    return data.goalDeadline.isEmpty ? '3个月' : data.goalDeadline;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const _SectionTitle('你的专属方案已生成'),
          const _SubTitle('根据你的信息，我们为你定制了以下训练框架'),
          const SizedBox(height: 8),

          // 计划摘要卡片
          _CardContainer(
            child: Column(
              children: [
                _buildSummaryRow(
                  icon: Icons.calendar_today,
                  label: '训练分化',
                  value: _getSplitType(),
                ),
                const Divider(color: Colors.white12, height: 24),
                _buildSummaryRow(
                  icon: Icons.repeat,
                  label: '每周训练',
                  value: '${data.weeklyTrainingDays} 天',
                ),
                const Divider(color: Colors.white12, height: 24),
                _buildSummaryRow(
                  icon: Icons.fitness_center,
                  label: '每次动作数',
                  value: '约 ${_getEstimatedExercises()} 个',
                ),
                const Divider(color: Colors.white12, height: 24),
                _buildSummaryRow(
                  icon: Icons.timer,
                  label: '单次时长',
                  value: '${data.sessionDuration} 分钟',
                ),
                const Divider(color: Colors.white12, height: 24),
                _buildSummaryRow(
                  icon: Icons.flag,
                  label: '预计达成目标',
                  value: _getEstimatedTime(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 用户信息摘要
          _CardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '你的档案摘要',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildInfoText('昵称', data.nickname),
                _buildInfoText('性别', data.gender),
                _buildInfoText('身高', '${data.height?.toStringAsFixed(0) ?? '-'} cm'),
                _buildInfoText('体重', '${data.weight?.toStringAsFixed(1) ?? '-'} kg'),
                _buildInfoText('主目标', data.mainGoal),
                _buildInfoText(
                  '可用器材',
                  data.equipment.isEmpty ? '未选择' : data.equipment.join('、'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 提示文字
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.deepOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.deepOrange.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.deepOrange, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '点击「开始锻造」保存你的档案并开启训练之旅。计划会根据你的进度自动调整。',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.deepOrange.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.deepOrange, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            '$label：',
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
