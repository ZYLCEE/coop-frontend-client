import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'app_bottom_navigation_bar.dart';
import 'profile_confirmation_screen.dart';
import 'responsive.dart';
import 'schedtracker.dart';
import 'loan_calculator_service.dart';
import 'services/database_service.dart';

class LoansScreen extends StatefulWidget {
  final bool hideTabs;

  const LoansScreen({super.key, this.hideTabs = false});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  int _selectedTab = 0;
  String _selectedFilter = 'All';
  final DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> _myLoans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMyLoans();
  }

  Future<void> _loadMyLoans() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final loans = await _dbService.getLoanApplications(user.id);
      if (mounted) {
        setState(() {
          _myLoans = loans;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F4),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            // Tab Control
            if (!widget.hideTabs) _buildTabControl(),
            // Content
            Expanded(
              child: _selectedTab == 0
                  ? _buildAvailableLoans()
                  : _buildMyLoans(),
            ),
            // Bottom Navigation
            AppBottomNavigationBar(
              currentIndex: widget.hideTabs ? -1 : 1,
              parentContext: context,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.horizontalPadding(context),
        vertical: Responsive.verticalPadding(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Loans',
            style: TextStyle(
              color: const Color(0xFF183A24),
              fontSize: Responsive.headingSize(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabControl() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.horizontalPadding(context),
        vertical: Responsive.spacing(context, 12),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE8F3EC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTab = 0;
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    vertical: Responsive.spacing(context, 12),
                  ),
                  decoration: BoxDecoration(
                    color: _selectedTab == 0
                        ? AppTheme.primaryGreen
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Available Loans',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _selectedTab == 0
                          ? Colors.white
                          : const Color(0xFF183A24),
                      fontSize: Responsive.bodySize(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTab = 1;
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    vertical: Responsive.spacing(context, 12),
                  ),
                  decoration: BoxDecoration(
                    color: _selectedTab == 1
                        ? AppTheme.primaryGreen
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'My Loans',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _selectedTab == 1
                          ? Colors.white
                          : const Color(0xFF183A24),
                      fontSize: Responsive.bodySize(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableLoans() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.horizontalPadding(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: Responsive.spacing(context, 16)),
          _buildLoanCategory(
            'Personal Loans',
            'Everyday financing needs',
            const Color(0xFF206A3B),
            [
              _buildLoanCard(
                LoanType.regular,
                'Flexible financing for any purpose',
                const Color(0xFF206A3B),
                false,
              ),
              _buildLoanCard(
                LoanType.emergency,
                'Fast cash when you need it most',
                const Color(0xFF206A3B),
                false,
              ),
              _buildLoanCard(
                LoanType.multiPurpose,
                'One loan, many possibilities',
                const Color(0xFF206A3B),
                false,
              ),
              _buildLoanCard(
                LoanType.quick,
                'Minimal docs, same-day release',
                const Color(0xFF206A3B),
                false,
              ),
            ],
          ),
          SizedBox(height: Responsive.spacing(context, 24)),
          _buildLoanCategory(
            'Special Purpose Loans',
            'Tailored for specific needs',
            const Color(0xFF1E88E5),
            [
              _buildLoanCard(
                LoanType.educational,
                'Invest in your future',
                const Color(0xFF1E88E5),
                false,
              ),
              _buildLoanCard(
                LoanType.medical,
                'Prioritize your health',
                const Color(0xFF1E88E5),
                false,
              ),
              _buildLoanCard(
                LoanType.livelihood,
                'Grow your business',
                const Color(0xFF1E88E5),
                false,
              ),
              _buildLoanCard(
                LoanType.appliance,
                'Upgrade your home',
                const Color(0xFF1E88E5),
                false,
              ),
            ],
          ),
          SizedBox(height: Responsive.spacing(context, 24)),
          _buildLoanCategory(
            'Occasion Loans',
            'Celebrate life\'s milestones',
            const Color(0xFFC8A64A),
            [
              _buildLoanCard(
                LoanType.birthday,
                'Make your birthday unforgettable',
                const Color(0xFFC8A64A),
                false,
              ),
              _buildLoanCard(
                LoanType.anniversary,
                'Celebrate your union in style',
                const Color(0xFFC8A64A),
                false,
              ),
              _buildLoanCard(
                LoanType.fiesta,
                'Community festival financing',
                const Color(0xFFC8A64A),
                false,
              ),
              _buildLoanCard(
                LoanType.bonus,
                'Bridge the gap before bonus',
                const Color(0xFFC8A64A),
                false,
              ),
            ],
          ),
          SizedBox(height: Responsive.spacing(context, 24)),
          _buildLoanCategory(
            'Secured & Other Loans',
            'Collateral-backed programs',
            const Color(0xFF546E7A),
            [
              _buildLoanCard(
                LoanType.collateral,
                'Higher limits, asset-secured',
                const Color(0xFF546E7A),
                false,
              ),
              _buildLoanCard(
                LoanType.mortuary,
                'Support during times of loss',
                const Color(0xFF546E7A),
                false,
              ),
              _buildLoanCard(
                LoanType.subsistence,
                'Day-to-day subsistence aid',
                const Color(0xFF546E7A),
                false,
              ),
              _buildLoanCard(
                LoanType.assme,
                'ASSME-backed program',
                const Color(0xFF546E7A),
                false,
              ),
            ],
          ),
          SizedBox(height: Responsive.spacing(context, 24)),
        ],
      ),
    );
  }

  Widget _buildMyLoans() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.horizontalPadding(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: Responsive.spacing(context, 16)),
          // Filter chips
          _buildFilterChips(),
          SizedBox(height: Responsive.spacing(context, 16)),
          // Summary cards
          _buildSummaryCards(),
          SizedBox(height: Responsive.spacing(context, 24)),
          // Loan history
          _buildLoanHistory(),
          SizedBox(height: Responsive.spacing(context, 24)),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      'All',
      'Pending',
      'Approved',
      'Active',
      'Fully Paid',
      'Rejected',
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: EdgeInsets.only(right: Responsive.spacing(context, 8)),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedFilter = filter;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.spacing(context, 16),
                  vertical: Responsive.spacing(context, 8),
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryGreen : Colors.white,
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryGreen
                        : const Color(0xFFE0E0E0),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF183A24),
                    fontSize: Responsive.bodySize(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final activeCount = _myLoans
        .where((l) => l['status'] == 'released' || l['status'] == 'overdue')
        .length;
    final pendingCount = _myLoans
        .where((l) => l['status'] == 'pending' || l['status'] == 'under review')
        .length;
    final paidCount = _myLoans.where((l) => l['status'] == 'completed').length;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            activeCount.toString(),
            'Active',
            const Color(0xFF206A3B),
          ),
        ),
        SizedBox(width: Responsive.spacing(context, 12)),
        Expanded(
          child: _buildSummaryCard(
            pendingCount.toString(),
            'Pending',
            const Color(0xFFE67E22),
          ),
        ),
        SizedBox(width: Responsive.spacing(context, 12)),
        Expanded(
          child: _buildSummaryCard(
            paidCount.toString(),
            'Paid',
            const Color(0xFF206A3B),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String count, String label, Color color) {
    return Container(
      padding: EdgeInsets.all(Responsive.cardPadding(context)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              color: color,
              fontSize: Responsive.headingSize(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: Responsive.spacing(context, 4)),
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF7D8A82),
              fontSize: Responsive.captionSize(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanHistory() {
    final filteredLoans = _selectedFilter == 'All'
        ? _myLoans
        : _myLoans.where((loan) {
            switch (_selectedFilter) {
              case 'Pending':
                return loan['status'] == 'pending' ||
                    loan['status'] == 'under review';
              case 'Approved':
                return loan['status'] == 'approved';
              case 'Active':
                return loan['status'] == 'released' ||
                    loan['status'] == 'overdue';
              case 'Fully Paid':
                return loan['status'] == 'completed';
              case 'Rejected':
                return loan['status'] == 'rejected';
              default:
                return true;
            }
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Loan History',
          style: TextStyle(
            color: const Color(0xFF183A24),
            fontSize: Responsive.titleSize(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: Responsive.spacing(context, 16)),
        if (filteredLoans.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: Responsive.spacing(context, 32),
            ),
            child: Text(
              'No loans found',
              style: TextStyle(
                color: const Color(0xFF7D8A82),
                fontSize: Responsive.bodySize(context),
              ),
            ),
          )
        else
          ...filteredLoans.map((loan) {
            final statusColor = _getStatusColor(loan['status']);
            return Padding(
              padding: EdgeInsets.only(bottom: Responsive.spacing(context, 16)),
              child: _buildLoanHistoryCard(
                loan['loan_type'] ?? 'Unknown',
                loan['application_id'] ?? 'N/A',
                loan['date_submitted'] ?? 'N/A',
                loan['status'] ?? 'Unknown',
                statusColor,
                loan['amount'],
                null,
                null,
                null,
                null,
              ),
            );
          }).toList(),
      ],
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'approved':
      case 'released':
      case 'completed':
        return const Color(0xFF206A3B);
      case 'pending':
      case 'under review':
        return const Color(0xFFE67E22);
      case 'rejected':
        return const Color(0xFFD32F2F);
      case 'overdue':
        return const Color(0xFFD32F2F);
      default:
        return const Color(0xFF757575);
    }
  }

  Widget _buildLoanHistoryCard(
    String loanName,
    String loanId,
    String appliedDate,
    String status,
    Color statusColor,
    double? outstanding,
    double? monthly,
    String? nextDue,
    int? progress,
    int? totalMonths,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoanDetailsScreen()),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(top: BorderSide(color: statusColor, width: 4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(Responsive.cardPadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loanName,
                          style: TextStyle(
                            color: const Color(0xFF183A24),
                            fontSize: Responsive.titleSize(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: Responsive.spacing(context, 4)),
                        Text(
                          '$loanId\n$appliedDate',
                          style: TextStyle(
                            color: const Color(0xFF7D8A82),
                            fontSize: Responsive.captionSize(context),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.spacing(context, 12),
                          vertical: Responsive.spacing(context, 6),
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: Responsive.captionSize(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(width: Responsive.spacing(context, 8)),
                      Icon(
                        Icons.chevron_right,
                        color: const Color(0xFF7D8A82),
                        size: Responsive.iconSize(context, 20),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: Responsive.spacing(context, 16)),
              // Status-specific content
              if (status == 'Active')
                _buildActiveCardContent(
                  outstanding!,
                  monthly!,
                  nextDue!,
                  progress!,
                  totalMonths!,
                )
              else if (status == 'Fully Paid')
                _buildFullyPaidCardContent(
                  outstanding!,
                  monthly!,
                  progress!,
                  totalMonths!,
                )
              else if (status == 'Pending')
                _buildPendingCardContent(outstanding!)
              else if (status == 'Approved')
                _buildApprovedCardContent(outstanding!, 12)
              else if (status == 'Rejected')
                _buildRejectedCardContent(outstanding!, 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveCardContent(
    double outstanding,
    double monthly,
    String nextDue,
    int progress,
    int totalMonths,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildInfoRow(
                'Outstanding',
                '₱${outstanding.toStringAsFixed(2)}',
              ),
            ),
            SizedBox(width: Responsive.spacing(context, 16)),
            Expanded(
              child: _buildInfoRow('Monthly', '₱${monthly.toStringAsFixed(2)}'),
            ),
          ],
        ),
        SizedBox(height: Responsive.spacing(context, 12)),
        Row(children: [Expanded(child: _buildInfoRow('Next Due', nextDue))]),
        SizedBox(height: Responsive.spacing(context, 16)),
        // Progress bar
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress / totalMonths,
                  backgroundColor: const Color(0xFFE8F3EC),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF206A3B),
                  ),
                  minHeight: 6,
                ),
              ),
            ),
            SizedBox(width: Responsive.spacing(context, 12)),
            Text(
              '$progress / $totalMonths months',
              style: TextStyle(
                color: const Color(0xFF183A24),
                fontSize: Responsive.captionSize(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFullyPaidCardContent(
    double principal,
    double monthly,
    int progress,
    int totalMonths,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildInfoRow(
                'Principal',
                '₱${principal.toStringAsFixed(2)}',
              ),
            ),
            SizedBox(width: Responsive.spacing(context, 16)),
            Expanded(
              child: _buildInfoRow('Monthly', '₱${monthly.toStringAsFixed(2)}'),
            ),
          ],
        ),
        SizedBox(height: Responsive.spacing(context, 16)),
        // Progress bar - completed
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 1.0,
                  backgroundColor: const Color(0xFFE8F3EC),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF206A3B),
                  ),
                  minHeight: 6,
                ),
              ),
            ),
            SizedBox(width: Responsive.spacing(context, 12)),
            Icon(
              Icons.check_circle,
              color: const Color(0xFF206A3B),
              size: Responsive.iconSize(context, 20),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPendingCardContent(double principal) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(Responsive.cardPadding(context)),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.access_time,
                color: const Color(0xFF7D8A82),
                size: Responsive.iconSize(context, 20),
              ),
              SizedBox(width: Responsive.spacing(context, 12)),
              Expanded(
                child: Text(
                  'Under review by Credit Committee',
                  style: TextStyle(
                    color: const Color(0xFF7D8A82),
                    fontSize: Responsive.bodySize(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: Responsive.spacing(context, 16)),
        _buildInfoRow('Principal', '₱${principal.toStringAsFixed(2)}'),
      ],
    );
  }

  Widget _buildApprovedCardContent(double principal, int tenure) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(Responsive.cardPadding(context)),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: const Color(0xFF1E88E5),
                size: Responsive.iconSize(context, 20),
              ),
              SizedBox(width: Responsive.spacing(context, 12)),
              Expanded(
                child: Text(
                  'Approved — ₱${principal.toStringAsFixed(2)} ready for release',
                  style: TextStyle(
                    color: const Color(0xFF1E88E5),
                    fontSize: Responsive.bodySize(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: Responsive.spacing(context, 16)),
        Row(
          children: [
            Expanded(
              child: _buildInfoRow(
                'Principal',
                '₱${principal.toStringAsFixed(2)}',
              ),
            ),
            SizedBox(width: Responsive.spacing(context, 16)),
            Expanded(child: _buildInfoRow('Tenure', '$tenure months')),
          ],
        ),
      ],
    );
  }

  Widget _buildRejectedCardContent(double principal, int tenure) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(Responsive.cardPadding(context)),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.cancel,
                color: const Color(0xFFD9534F),
                size: Responsive.iconSize(context, 20),
              ),
              SizedBox(width: Responsive.spacing(context, 12)),
              Expanded(
                child: Text(
                  'Application not approved',
                  style: TextStyle(
                    color: const Color(0xFFD9534F),
                    fontSize: Responsive.bodySize(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: Responsive.spacing(context, 16)),
        Row(
          children: [
            Expanded(
              child: _buildInfoRow(
                'Principal',
                '₱${principal.toStringAsFixed(2)}',
              ),
            ),
            SizedBox(width: Responsive.spacing(context, 16)),
            Expanded(child: _buildInfoRow('Requested', '$tenure months')),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF7D8A82),
            fontSize: Responsive.captionSize(context),
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: Responsive.spacing(context, 4)),
        Text(
          value,
          style: TextStyle(
            color: const Color(0xFF183A24),
            fontSize: Responsive.bodySize(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildLoanCategory(
    String title,
    String subtitle,
    Color color,
    List<Widget> cards,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: const Color(0xFF183A24),
            fontSize: Responsive.titleSize(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: Responsive.spacing(context, 4)),
        Text(
          subtitle,
          style: TextStyle(
            color: const Color(0xFF7D8A82),
            fontSize: Responsive.bodySize(context),
            fontWeight: FontWeight.w400,
          ),
        ),
        SizedBox(height: Responsive.spacing(context, 16)),
        ...cards,
      ],
    );
  }

  Widget _buildLoanCard(
    LoanType loanType,
    String description,
    Color color,
    bool isActive,
  ) {
    final name = loanType.label;
    final isOngoing = LoanEligibility.isOngoing(loanType);

    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.spacing(context, 16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Top colored section
            Container(
              height: 110,
              decoration: BoxDecoration(
                color: isOngoing ? AppTheme.mutedGray : color,
              ),
              child: Stack(
                children: [
                  // Decorative circles
                  Positioned(
                    top: -30,
                    right: -30,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -40,
                    left: -40,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // Content positioned at bottom left
                  Positioned(
                    left: 20,
                    bottom: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'CSUCC',
                                style: TextStyle(color: Color(0xFFFFD817)),
                              ),
                              const TextSpan(
                                text: 'ERMPC',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                            style: TextStyle(
                              fontSize: Responsive.captionSize(context),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        SizedBox(height: Responsive.spacing(context, 6)),
                        Text(
                          name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: Responsive.headingSize(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Bottom white section
            Container(
              padding: EdgeInsets.all(Responsive.cardPadding(context)),
              decoration: const BoxDecoration(color: Colors.white),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: const Color(0xFF183A24),
                            fontSize: Responsive.titleSize(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: Responsive.spacing(context, 4)),
                        Text(
                          description,
                          style: TextStyle(
                            color: const Color(0xFF7D8A82),
                            fontSize: Responsive.bodySize(context),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isOngoing)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.spacing(context, 20),
                        vertical: Responsive.spacing(context, 12),
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.mutedGray,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Ongoing Loan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else if (!isActive)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ProfileConfirmationScreen(loanType: loanType),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.spacing(context, 20),
                          vertical: Responsive.spacing(context, 12),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        'Apply Now',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
