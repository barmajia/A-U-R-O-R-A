import 'package:aurora/models/sale.dart';
import 'package:aurora/pages/sales/record_sale_screen.dart';
import 'package:aurora/services/supabase.dart';
import 'package:aurora/widgets/drawer.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  List<Sale> _sales = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedPeriod = '30d';

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabaseProvider = context.read<SupabaseProvider>();
      final days = int.tryParse(_selectedPeriod.replaceAll('d', '')) ?? 30;
      final startDate = DateTime.now().subtract(Duration(days: days));

      final sales = await supabaseProvider.getSales(
        startDate: startDate,
        limit: 100,
      );

      setState(() {
        _sales = sales;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load sales: $e';
        _isLoading = false;
      });
    }
  }

  void _navigateToRecordSale() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RecordSaleScreen()),
    ).then((result) {
      if (result == true) _loadSales();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: _buildAppBar(context, colorScheme),
      drawer: const AppDrawer(currentPage: 'sales'),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : _errorMessage != null
          ? _buildErrorState(colorScheme)
          : RefreshIndicator(
              onRefresh: _loadSales,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildPeriodFilter(colorScheme),
                  const SizedBox(height: 16),
                  _buildSalesSummary(colorScheme),
                  const SizedBox(height: 16),
                  _buildSalesList(colorScheme),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToRecordSale,
        backgroundColor: colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Record Sale',
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return AppBar(
      title: const Text('Sales'),
      centerTitle: true,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadSales,
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildPeriodFilter(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: colorScheme.surface,
      child: Row(
        children: [
          Text('Period:', style: TextStyle(color: colorScheme.onSurface)),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPeriodChip('7d', colorScheme),
                  const SizedBox(width: 8),
                  _buildPeriodChip('30d', colorScheme),
                  const SizedBox(width: 8),
                  _buildPeriodChip('90d', colorScheme),
                  const SizedBox(width: 8),
                  _buildPeriodChip('1y', colorScheme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String period, ColorScheme colorScheme) {
    final isSelected = _selectedPeriod == period;
    return FilterChip(
      label: Text(period),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedPeriod = period;
        });
        _loadSales();
      },
      backgroundColor: colorScheme.surfaceContainerHighest,
      selectedColor: colorScheme.primary.withOpacity(0.2),
      checkmarkColor: colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? colorScheme.primary : colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildSalesSummary(ColorScheme colorScheme) {
    final totalRevenue = _sales.fold<double>(
      0,
      (sum, sale) => sum + sale.netTotal,
    );
    final totalSales = _sales.length;
    final totalItems = _sales.fold<int>(0, (sum, sale) => sum + sale.quantity);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            label: 'Revenue',
            value: NumberFormat.currency(
              symbol: '\$',
              decimalDigits: 2,
            ).format(totalRevenue),
            icon: Icons.attach_money,
            colorScheme: colorScheme,
          ),
          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3)),
          _buildSummaryItem(
            label: 'Sales',
            value: totalSales.toString(),
            icon: Icons.shopping_cart,
            colorScheme: colorScheme,
          ),
          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3)),
          _buildSummaryItem(
            label: 'Items',
            value: totalItems.toString(),
            icon: Icons.inventory_2,
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required IconData icon,
    required ColorScheme colorScheme,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSalesList(ColorScheme colorScheme) {
    if (_sales.isEmpty) {
      return _buildEmptyState(colorScheme);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sales.length,
      itemBuilder: (context, index) {
        final sale = _sales[index];
        return _buildSaleCard(sale, colorScheme);
      },
    );
  }

  Widget _buildSaleCard(Sale sale, ColorScheme colorScheme) {
    final currencyFormat = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: sale.paymentStatus == 'completed'
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                sale.paymentStatus == 'completed'
                    ? Icons.check_circle
                    : Icons.pending,
                color: sale.paymentStatus == 'completed'
                    ? Colors.green
                    : Colors.orange,
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        sale.customer?.name ?? 'Walk-in Customer',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          sale.paymentMethodDisplay
                              .replaceAll(
                                RegExp(r'\p{Emoji}', unicode: true),
                                '',
                              )
                              .trim(),
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${sale.quantity} item${sale.quantity > 1 ? 's' : ''} × ${currencyFormat.format(sale.unitPrice)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),

            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currencyFormat.format(sale.netTotal),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sale.relativeTime,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 80,
            color: colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No sales yet',
            style: TextStyle(
              fontSize: 18,
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Record your first sale to get started',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToRecordSale,
            icon: const Icon(Icons.add),
            label: const Text('Record Sale'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: colorScheme.error.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadSales,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
