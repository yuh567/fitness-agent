import 'package:intl/intl.dart';

// ========== 日期工具 ==========
String formatDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

String getWeekdayName(int weekday) {
  const names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  if (weekday < 1 || weekday > 7) return '未知';
  return names[weekday - 1];
}

DateTime getWeekStart(DateTime date) {
  final weekday = date.weekday;
  return date.subtract(Duration(days: weekday - 1));
}

// ========== 健身计算工具 ==========
/// Epley公式估算1RM
double calculateOneRM(double weight, int reps) {
  if (reps <= 0) return 0;
  if (reps == 1) return weight;
  return weight * (1 + reps / 30.0);
}

/// 计算训练容量
double calculateVolume(double weight, int sets, int reps) {
  return weight * sets * reps;
}

/// 估算消耗卡路里
int estimateCaloriesBurned(double bodyWeight, int durationMinutes, String intensity) {
  final lower = intensity.toLowerCase();
  double met;
  if (lower == 'low' || lower == '轻松' || lower == '低') {
    met = 3.0;
  } else if (lower == 'moderate' || lower == '中等' || lower == '中') {
    met = 5.0;
  } else if (lower == 'high' || lower == '高强度' || lower == '高') {
    met = 8.0;
  } else {
    met = 5.0;
  }
  return (met * bodyWeight * durationMinutes / 60.0).round();
}

// ========== 重量格式化 ==========
String formatWeight(double weight) {
  if (weight == weight.roundToDouble()) {
    return '${weight.toInt()}kg';
  }
  return '${weight.toStringAsFixed(1)}kg';
}

// ========== 训练等级计算 ==========
String calculateExperienceLevel(int years, double totalVolume) {
  if (years < 1) return '新手铁匠';
  if (years < 2) return '学徒铁匠';
  if (years < 4) return '熟手铁匠';
  if (years < 6) return '资深铁匠';
  if (totalVolume > 1000000) return '传奇铁匠';
  return '大师铁匠';
}

// ========== 目标进度计算 ==========
double calculateGoalProgress(double current, double target, String goalType) {
  if (target == 0) return 0.0;
  double progress;
  if (goalType == 'weight_loss') {
    // 减脂：当前值应低于目标值（起始体重），进度 = (起始 - 当前) / (起始 - 目标)
    // 简化处理：假设 current 是已减重量，target 是目标减重量
    progress = current / target;
  } else {
    progress = current / target;
  }
  return progress.clamp(0.0, 1.0);
}

// ========== 字符串工具 ==========
String getGoalTypeName(String type) {
  switch (type) {
    case 'weight_loss':
      return '减脂';
    case 'muscle_gain':
      return '增肌';
    case 'strength':
      return '增力';
    case 'endurance':
      return '耐力';
    case 'maintenance':
      return '维持';
    default:
      return '未知';
  }
}

String getSplitName(String split) {
  switch (split) {
    case 'push':
      return '推日';
    case 'pull':
      return '拉日';
    case 'legs':
      return '腿日';
    case 'upper':
      return '上肢日';
    case 'lower':
      return '下肢日';
    case 'full':
      return '全身日';
    case 'rest':
      return '休息日';
    default:
      return split;
  }
}

String getMuscleName(String muscle) {
  switch (muscle) {
    case '胸大肌':
      return '胸大肌';
    case '胸大肌上部':
      return '上胸';
    case '胸大肌下部':
      return '下胸';
    case '背阔肌':
      return '背阔肌';
    case '竖脊肌':
      return '竖脊肌';
    case '斜方肌':
      return '斜方肌';
    case '肱二头肌':
      return '肱二头肌';
    case '肱三头肌':
      return '肱三头肌';
    case '肱肌/肱桡肌':
      return '肱肌';
    case '三角肌前束':
      return '三角肌前束';
    case '三角肌中束':
      return '三角肌中束';
    case '三角肌后束':
      return '三角肌后束';
    case '股四头肌':
      return '股四头肌';
    case '腘绳肌':
      return '腘绳肌';
    case '臀大肌':
      return '臀大肌';
    case '小腿腓肠肌':
      return '腓肠肌';
    case '小腿比目鱼肌':
      return '比目鱼肌';
    case '腹直肌':
      return '腹直肌';
    case '腹直肌上部':
      return '上腹';
    case '腹直肌下部':
      return '下腹';
    case '腹斜肌':
      return '腹斜肌';
    case '腹横肌':
      return '腹横肌';
    case '全身':
      return '全身';
    case '心肺/下肢':
      return '心肺/下肢';
    case '心肺/全身':
      return '心肺/全身';
    case '心肺/背腿':
      return '心肺/背腿';
    case '握力/斜方肌':
      return '握力/斜方肌';
    case '全身爆发力':
      return '全身爆发力';
    case '全身/心肺':
      return '全身/心肺';
    case '小腿/心肺':
      return '小腿/心肺';
    case '全身稳定':
      return '全身稳定';
    default:
      return muscle;
  }
}
