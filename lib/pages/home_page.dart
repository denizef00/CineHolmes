import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../home_main.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Arama barı
          TextField(
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? const Color(0xFF1E1E2C) : Colors.grey.shade200,
              hintText: 'Film veya dizi ara...',
              hintStyle: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
              prefixIcon: Icon(Icons.search, color: isDark ? Colors.white70 : Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Film kutucukları
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.8,
              children: List.generate(6, (index) {
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2C) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black54 : Colors.black12,
                        blurRadius: 4,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.movie,
                        size: 48,
                        color: isDark ? Colors.deepPurpleAccent.shade100 : Colors.deepPurple,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Film ${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
