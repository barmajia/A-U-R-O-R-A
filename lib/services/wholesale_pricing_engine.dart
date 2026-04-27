import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/pricing_rule.dart';

class WholesalePricingEngine {
  static final WholesalePricingEngine _instance = WholesalePricingEngine._internal();
  factory WholesalePricingEngine() => _instance;
  WholesalePricingEngine._internal();

  Future<Directory> _getFactoryDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final factoryDir = Directory('${dir.path}/factory');
    if (!await factoryDir.exists()) {
      await factoryDir.create(recursive: true);
    }
    return factoryDir;
  }

  Future<File> _getPricingFile() async {
    final dir = await _getFactoryDir();
    return File('${dir.path}/pricing_rules.json');
  }

  Future<List<PricingRule>> getAllRules() async {
    try {
      final file = await _getPricingFile();
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.isEmpty) return [];
      final List<dynamic> jsonList = json.decode(content);
      return jsonList.map((e) => PricingRule.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveRule(PricingRule rule) async {
    final rules = await getAllRules();
    final index = rules.indexWhere((r) => r.id == rule.id);
    if (index != -1) {
      rules[index] = rule;
    } else {
      rules.add(rule);
    }
    final file = await _getPricingFile();
    await file.writeAsString(json.encode(rules.map((r) => r.toJson()).toList()));
  }

  Future<double> calculatePrice(String productId, String? sellerId, double basePrice, int quantity) async {
    final rules = await getAllRules();
    double discount = 0;
    for (var rule in rules) {
      if ((rule.productId == '*' || rule.productId == productId) &&
          (rule.sellerId == null || rule.sellerId == sellerId) &&
          rule.isValidNow()) {
        for (var tier in rule.tiers) {
          if (quantity >= tier.minQuantity && tier.discountPercent > discount) {
            discount = tier.discountPercent;
          }
        }
      }
    }
    return basePrice * (1 - discount / 100);
  }
}