import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category.dart';
import 'app_database_provider.dart';

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final dao = ref.watch(categoryDaoProvider);
  return dao.getAll();
});

final categoryByIdProvider = FutureProvider.family<Category?, int>((ref, id) async {
  final dao = ref.watch(categoryDaoProvider);
  return dao.getById(id);
});
