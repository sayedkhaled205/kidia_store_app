import 'package:flutter/material.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('البحث')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'ابحث عن منتج',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            SizedBox(height: 32),
            Icon(Icons.manage_search, size: 60),
            SizedBox(height: 12),
            Text('اكتب اسم المنتج الذي تبحث عنه'),
          ],
        ),
      ),
    );
  }
}
