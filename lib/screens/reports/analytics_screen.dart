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

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  int _touchedIndex = -1;
  String _selectedPeriod = 'Month'; // Week, Month, Year
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    _tabController.addListener(() {
        if (!_tabController.indexIsChanging) {
           setState(() {
             switch (_tabController.index) {
               case 0: _selectedPeriod = 'Week'; break;
               case 1: _selectedPeriod = 'Month'; break;
               case 2: _selectedPeriod = 'Year'; break;
             }
           });
        }
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final profileId = Provider.of<ProfileProvider>(context).currentProfileId;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Analytics'),
            centerTitle: true,
            automaticallyImplyLeading: false, 
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  // Period Selector
                  Container(
                    height: 45,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        color: theme.colorScheme.primary,
                      ),
                      labelColor: theme.colorScheme.onPrimary,
                      unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: 'Week'),
                        Tab(text: 'Month'),
                        Tab(text: 'Year'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Total Spend Card
                  _buildTotalSpend(context, db, profileId),
                  
                  const SizedBox(height: 24),
                  
                  // Charts
                  Align(alignment: Alignment.centerLeft, child: Text('Spending Breakdown', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
                  const SizedBox(height: 16),
                  
                  Container(
                    height: 350,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                       color: theme.colorScheme.surfaceContainerLow,
                       borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        Text('By Category', style: theme.textTheme.labelLarge),
                        Expanded(child: _buildPieChart(context, db, profileId)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  
                  Container(
                    height: 300,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                       color: theme.colorScheme.surfaceContainerLow,
                       borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        Text('Trend', style: theme.textTheme.labelLarge),
                        const SizedBox(height: 20),
                        Expanded(child: _buildBarChart(context, db, profileId)),
                      ],
                    ),
                  ),
                   const SizedBox(height: 80),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTotalSpend(BuildContext context, AppDatabase db, int profileId) {
     return FutureBuilder<List<Map<String, dynamic>>>(
        future: db.getCategoryExpenses(profileId),
        builder: (context, snapshot) {
           final double total = (snapshot.data ?? []).fold(0, (sum, item) => sum + (item['amount'] as double));
           return Column(
             children: [
               Text('Total Spent ($_selectedPeriod)', style: Theme.of(context).textTheme.bodyLarge),
               Text(
                 '৳${NumberFormat.compact().format(total)}', 
                 style: Theme.of(context).textTheme.displayMedium?.copyWith(
                   fontWeight: FontWeight.bold, 
                   color: Theme.of(context).colorScheme.primary
                 )
               ),
             ],
           );
        }
     );
  }

  Widget _buildPieChart(BuildContext context, AppDatabase db, int profileId) {
      return FutureBuilder<List<Map<String, dynamic>>>(
              future: db.getCategoryExpenses(profileId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('No data'));
                
                final data = snapshot.data!;
                
                return PieChart(
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
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: List.generate(data.length, (i) {
                            final item = data[i];
                            final isTouched = i == _touchedIndex;
                            final fontSize = isTouched ? 18.0 : 14.0;
                            final radius = isTouched ? 110.0 : 100.0;
                            return PieChartSectionData(
                              color: Color(item['color']),
                              value: item['amount'],
                              title: '${item['name']}\n${(item['amount'] as double).toStringAsFixed(0)}',
                              radius: radius,
                              titleStyle: TextStyle(
                                fontSize: fontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: const [Shadow(color: Colors.black26, blurRadius: 2)]
                              ),
                            );
                          }),
                        ),
                      );
              });
  }
  
  Widget _buildBarChart(BuildContext context, AppDatabase db, int profileId) {
     return FutureBuilder<List<Map<String, dynamic>>>(
              future: db.getDailyExpenses(profileId),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('No data'));
                
                final data = snapshot.data!; 
                // Simple hack for handling 'Week', 'Month' filtering visual only
                // In real app, query would change.
                
                return BarChart(
                  BarChartData(
                    barGroups: data.asMap().entries.map((e) {
                      final index = e.key;
                      final item = e.value;
                      final amount = item['amount'] as double;
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: amount,
                            color: Theme.of(context).colorScheme.primary,
                            width: 16,
                            borderRadius: BorderRadius.circular(4)
                          )
                        ]
                      );
                    }).toList(),
                    titlesData: const FlTitlesData(
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                  )
                );
              }
     );
  }
}