import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../services/model_catalog.dart';
import 'widgets/model_card.dart';

class ModelsScreen extends StatelessWidget {
  const ModelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.models)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: ModelCatalog.all.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) =>
            ModelCard(model: ModelCatalog.all[index], showDeleteAction: true),
      ),
    );
  }
}
