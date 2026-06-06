# 健身App进化计划 v2.0

## 目标
将当前基础版健身App进化为具备完整onboarding、AI方案生成、增强训练UI的专业级健身应用。

## 新App名称
**「铁匠铺」** - 寓意：像铁匠锻造钢铁一样锻造身体，有趣、有力量感、中文特色。

## 文件结构
```
lib/
  main.dart              - 入口、主题、路由、App名称
  database/db_helper.dart - 扩展数据库Schema
  models.dart            - 数据模型类
  onboarding.dart        - 首次引导流程（5步）
  home_page.dart         - 主页/今日计划/日历
  workout_page.dart      - 增强训练执行页
  plan_engine.dart       - AI计划引擎（本地+Kimi）
  kimi_service.dart      - Kimi API服务
  settings_page.dart     - 设置/个人中心
  utils.dart             - 工具函数
```

## 数据库Schema扩展

### 新表/扩展表
1. **user_profile** (扩展)
   - id, name, gender, age, height, weight, body_fat, goal, experience_level, training_days_per_week, preferred_duration, created_at

2. **user_equipment** (新)
   - id, equipment_type, name, is_available, max_weight, notes

3. **fitness_goals** (新)
   - id, goal_type, target_value, deadline, priority, created_at

4. **training_history** (新)
   - id, has_gym_experience, years_experience, previous_routine, max_lifts_json, injuries, created_at

5. **training_plans** (扩展)
   - 增加: total_exercises, estimated_duration, calories_burned, notes, generated_by_ai

6. **workout_logs** (扩展)
   - 增加: actual_weight, actual_sets, actual_reps_json, rpe, rest_taken, calories_estimated, feeling_notes

7. **daily_status** (新)
   - id, date, status (rest/sick/travel/motivated), energy_level, sleep_hours, notes

8. **calorie_records** (新)
   - id, date, type (intake/burn), category, amount, notes

## 模块分工

### Agent 1: 数据库 + 模型层
- 扩展 db_helper.dart: 新表创建、数据迁移、种子数据
- 编写 models.dart: 所有数据模型类

### Agent 2: Onboarding流程
- 编写 onboarding.dart: 5步引导页
  - Step 1: 欢迎页 + 基本信息（姓名、性别、年龄、身高、体重、体脂）
  - Step 2: 运动历史（是否有健身房经验、年限、以往训练方式、最大重量、伤病史）
  - Step 3: 器材清单（勾选可用器材：杠铃、哑铃、器械、自重等）
  - Step 4: 健身目标（增肌/减脂/力量/耐力/健康，目标体重/体脂，时间期限）
  - Step 5: 计划预览 + 确认
- 使用 PageView + 进度指示器

### Agent 3: 主页 + 计划引擎
- 编写 home_page.dart: 
  - 今日计划卡片（显示所有动作、预计时间、卡路里）
  - 本周训练日历（显示已完成/待完成/休息）
  - 快速操作：开始训练、记录身体数据、查看历史、调整计划
  - 训练地点选择器
- 编写 plan_engine.dart:
  - 基于用户档案生成个性化计划
  - 支持Push/Pull/Legs/Upper/Lower/Full Body分化
  - 根据目标调整容量和强度
  - 生病/休息自动调整
  - 卡路里估算

### Agent 4: 训练执行页
- 编写 workout_page.dart:
  - 显示当前动作详情（名称、目标肌群、组数、次数、建议重量）
  - 重量选择器（可调整实际使用重量）
  - 每组记录（实际次数输入）
  - 组间休息计时器（可自定义时长）
  - RPE评分
  - 动作切换
  - 训练完成总结（总容量、总时间、卡路里、平均RPE）
  - 中途暂停/放弃处理
  - 生病/休息日报备按钮

### Agent 5: 设置 + 服务层
- 编写 settings_page.dart:
  - 个人资料编辑
  - 训练偏好设置
  - 器材管理
  - 目标管理
  - API Key设置
  - 数据备份/导出
- 编写 kimi_service.dart:
  - 请求AI生成/调整计划
  - 请求AI分析训练数据
- 编写 utils.dart:
  - 日期工具
  - 卡路里计算
  - 重量格式化

## 接口约定

### 主入口 (main.dart)
```dart
// 检查是否首次启动
final prefs = await SharedPreferences.getInstance();
final hasOnboarded = prefs.getBool('has_onboarded') ?? false;
home: hasOnboarded ? const HomePage() : const OnboardingFlow(),
```

### 数据库版本升级
```dart
version: 2,
onCreate: _createDB,
onUpgrade: _onUpgrade,
```

### 计划引擎接口
```dart
class PlanEngine {
  Future<WorkoutPlan?> generateTodayPlan(int locationId, DateTime date);
  Future<WorkoutPlan?> generateCustomPlan(UserProfile profile, FitnessGoals goals);
  Future<void> adjustForAbsence(DateTime date, String reason);
  Future<void> checkAndMarkRestDays();
}
```

### 训练页接口
```dart
class WorkoutPage extends StatefulWidget {
  final WorkoutPlan plan;
  final List<Exercise> exercises;
  final UserProfile profile;
}
```

## 主题设计
- 主色：深炭灰背景 + 活力橙强调色
- 中文标题字体加粗
- 卡片式布局
- 圆角12px
- 暗色主题（护眼，适合健身房环境）

## 编译检查清单
- [ ] 所有import路径正确
- [ ] 无未使用变量
- [ ] 字符串引号正确（无多行字符串问题）
- [ ] 类型安全
- [ ] flutter build apk --release 通过
