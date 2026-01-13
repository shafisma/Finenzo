import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../database/database.dart';
import '../../providers/profile_provider.dart';
import 'package:intl/intl.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final profileId = Provider.of<ProfileProvider>(context).currentProfileId;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Analytics'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Categories'),
              Tab(text: 'Daily Trend'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Pie Chart Tab
            FutureBuilder<List<Map<String, dynamic>>>(
              future: db.getCategoryExpenses(profileId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('No data'));
                
                final data = snapshot.data!;
                
                return Column(
                  children: [
                    const SizedBox(height: 20),
                    Expanded(
                      child: PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback: (FlTouchEvent event, pieTouchResponse) {
                              setState(() {
                                if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                                  _touchedIndex = -1;
                                  return;
                                }
                                _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                              });
                            },
                          ),
                          sectionsSpace: 0,
                          centerSpaceRadius: 40,
                          sections: List.generate(data.length, (i) {
                            final item = data[i];
                            final isTouched = i == _touchedIndex;
                            final fontSize = isTouched ? 25.0 : 16.0;
                            final radius = isTouched ? 60.0 : 50.0;
                            return PieChartSectionData(
                              color: Color(item['color']),
                              value: item['amount'],
                              title: '${item['name']}\n${item['amount']}',
                              radius: radius,
                              titleStyle: TextStyle(
                                fontSize: fontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),
            
            // Bar Chart Tab
             FutureBuilder<List<Map<String, dynamic>>>(
              future: db.getDailyExpenses(profileId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('No data'));
                
                final data = snapshot.data!;
                // Take last 7 days for visibility
                final displayedData = data.length > 7 ? data.sublist(data.length - 7) : data;
                
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: BarChart(
                    BarChartData(
                      titlesData: FlTitlesData(
                         show: true,
                         bottomTitles: AxisTitles(
                             sideTitles: SideTitles(
                                 showTitles: true,
                                 getTitlesWidget: (double value, TitleMeta meta) {
                                     final index = value.toInt();
                                     if (index >= 0 && index < displayedData.length) {
                                         final date = displayedData[index]['date'] as DateTime;
                                         return SideTitleWidget(
                                             axisSide: meta.axisSide,
                                             child: Text(DateFormat('dd/MM').format(date), style: const TextStyle(fontSize: 10)),
                                         );
                                     }
                                     return const Text('');
                                 }
                             )
                         )
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: displayedData.asMap().entries.map((e) {
                          return BarChartGroupData(
                              x: e.key,
                              barRods: [
                                  BarChartRodData(
                                      toY: e.value['amount'],
                                      color: Colors.deepPurple,
                                      width: 15,
                                  )
                              ]
                          );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
