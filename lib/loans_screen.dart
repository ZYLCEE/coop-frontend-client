import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'app_bottom_navigation_bar.dart';
import 'profile_confirmation_screen.dart';
import 'responsive.dart';
import 'documents_screen.dart';
import 'schedtracker.dart';
import 'loan_calculator_service.dart';
import 'services/database_service.dart';

class LoansScreen extends StatefulWidget {
  final bool hideTabs;
  final bool startOnPendingApplications;

  const LoansScreen({
    super.key,
    this.hideTabs = false,
    this.startOnPendingApplications = false,
  }) : assert(!hideTabs || !startOnPendingApplications);

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> with WidgetsBindingObserver {
  late int _selectedTab = widget.startOnPendingApplications ? 1 : 0;
  int _categoryIndex = 0;
  final _categoryController = PageController();
  late String _selectedFilter = widget.startOnPendingApplications
      ? 'Pending'
      : 'All';
  final DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> _myLoans = [];
  bool _isLoading = true;
  String? _myLoansError;
  String? _progressLoadError;
  bool _refreshingMyLoans = false;
  Timer? _progressRefreshTimer;
  RealtimeChannel? _loanUpdatesChannel;
  String? _subscribedMemberId;
  ValueNotifier<Map<String, dynamic>>? _openApplicationProgress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMyLoans();
    _progressRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && _selectedTab == 1) {
        unawaited(_loadMyLoans(showLoading: false));
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progressRefreshTimer?.cancel();
    final channel = _loanUpdatesChannel;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    _categoryController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _selectedTab == 1) {
      unawaited(_loadMyLoans(showLoading: false));
    }
  }

  void _goToCategory(int index) {
    if (!_categoryController.hasClients) return;
    _categoryController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _loadMyLoans({bool showLoading = true}) async {
    if (_refreshingMyLoans) return;
    _refreshingMyLoans = true;
    if (mounted && showLoading)
      setState(() {
        _isLoading = true;
        _myLoansError = null;
      });
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted)
          setState(() {
            _isLoading = false;
            _myLoansError = 'Sign in to load your loan history.';
          });
        return;
      }

      final member = await _dbService.getMember(user.id);
      _listenForLoanUpdates(member['id']?.toString());
      final loans = await _dbService.getLoanApplications(user.id);
      var nextProgressError =
          'Live review progress is unavailable. Pull down to retry.';
      final progressByApplication = <String, Map<String, dynamic>>{};
      try {
        final progressRows = await _dbService.getMemberApplicationProgress();
        for (final row in progressRows) {
          final applicationId = row['application_id']?.toString();
          if (applicationId != null) {
            progressByApplication[applicationId] = row;
          }
        }
        final hasMissingProgress = loans.any(
          (loan) => !progressByApplication.containsKey(
            loan['application_id']?.toString(),
          ),
        );
        nextProgressError = hasMissingProgress
            ? 'The cooperative review stage could not be loaded. Pull down to retry.'
            : '';
      } catch (_) {
        // Keep loan history available while clearly marking unsynced workflow data.
      }
      final refreshedLoans = loans.map((loan) {
        final progress =
            progressByApplication[loan['application_id']?.toString()];
        return {
          ...loan,
          if (progress != null) ...{
            '_workflow_stage': progress['workflow_stage'],
            '_review_stage': progress['review_stage'],
            '_crecom_approved': progress['crecom_approved'],
            '_crecom_assigned': progress['crecom_assigned'],
            '_bod_approved': progress['bod_approved'],
            '_bod_assigned': progress['bod_assigned'],
            '_progress_updated_at': progress['progress_updated_at'],
          },
        };
      }).toList();
      if (mounted) {
        setState(() {
          _myLoans = refreshedLoans;
          _isLoading = false;
          _myLoansError = null;
          _progressLoadError = nextProgressError.isEmpty
              ? null
              : nextProgressError;
        });
        final activeProgress = _openApplicationProgress;
        if (activeProgress != null) {
          Map<String, dynamic>? application;
          for (final loan in refreshedLoans) {
            if (loan['application_id']?.toString() ==
                _activeProgressApplicationId) {
              application = loan;
              break;
            }
          }
          if (application != null) {
            activeProgress.value = {
              ...application,
              '_workflow_sync_error': _progressLoadError,
            };
          }
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _myLoansError = error is LoanHistoryLoadException
              ? error.stage == 'member account link'
                    ? 'Your login is not linked to a member record. Contact the cooperative admin to check your member account.'
                    : 'Could not read loan records for your member account. Check the loan table access and retry.'
              : 'Unable to load your loan history. Check your connection and retry.';
        });
      }
    } finally {
      _refreshingMyLoans = false;
    }
  }

  String? _activeProgressApplicationId;

  void _listenForLoanUpdates(String? memberId) {
    if (memberId == null ||
        memberId.isEmpty ||
        memberId == _subscribedMemberId) {
      return;
    }
    final oldChannel = _loanUpdatesChannel;
    if (oldChannel != null) {
      unawaited(Supabase.instance.client.removeChannel(oldChannel));
    }
    _subscribedMemberId = memberId;
    _loanUpdatesChannel = Supabase.instance.client
        .channel('member-loan-progress-$memberId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'loan_applications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'member_id',
            value: memberId,
          ),
          callback: (_) => unawaited(_loadMyLoans(showLoading: false)),
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
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
                  _loadMyLoans();
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
    final categories = [
      (
        title: 'Personal Loans',
        subtitle: 'Everyday financing needs',
        cards: [
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
      (
        title: 'Special Purpose Loans',
        subtitle: 'Tailored for specific needs',
        cards: [
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
      (
        title: 'Occasion Loans',
        subtitle: 'Celebrate life\'s milestones',
        cards: [
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
      (
        title: 'Secured & Other Loans',
        subtitle: 'Collateral-backed programs',
        cards: [
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
    ];
    final padding = Responsive.horizontalPadding(context);
    final category = categories[_categoryIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(padding, AppTheme.spacingS, padding, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.title,
                style: TextStyle(
                  color: AppTheme.primaryText,
                  fontSize: Responsive.titleSize(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _categoryButton(
                      'Previous',
                      _categoryIndex > 0
                          ? () => _goToCategory(_categoryIndex - 1)
                          : null,
                    ),
                  ),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        'Category ${_categoryIndex + 1} of ${categories.length}',
                        textAlign: TextAlign.center,
                        style: AppTheme.captionBold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _categoryButton(
                      'Next',
                      _categoryIndex < categories.length - 1
                          ? () => _goToCategory(_categoryIndex + 1)
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            key: const PageStorageKey('available-loan-categories'),
            controller: _categoryController,
            itemCount: categories.length,
            onPageChanged: (index) => setState(() => _categoryIndex = index),
            itemBuilder: (context, index) {
              final page = categories[index];
              return SingleChildScrollView(
                key: PageStorageKey('available-loans-$index'),
                primary: false,
                padding: EdgeInsets.fromLTRB(
                  padding,
                  AppTheme.spacingS,
                  padding,
                  AppTheme.spacingXXL,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_myLoansError != null)
                      Card(
                        color: const Color(0xFFFFF3E0),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Unable to verify existing applications. Apply is disabled until the loan history loads. $_myLoansError',
                                ),
                              ),
                              TextButton(
                                onPressed: _loadMyLoans,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Text(
                      page.subtitle,
                      style: TextStyle(
                        color: AppTheme.mutedGray,
                        fontSize: Responsive.bodySize(context),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingL),
                    ...page.cards,
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _categoryButton(String label, VoidCallback? onPressed) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: AppTheme.primaryGreen,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXS),
    ),
    child: Text(label, textAlign: TextAlign.center),
  );

  Widget _buildMyLoans() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_myLoansError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_myLoansError!, textAlign: TextAlign.center),
              TextButton(onPressed: _loadMyLoans, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.horizontalPadding(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: Responsive.spacing(context, 16)),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _loadMyLoans,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh history'),
            ),
          ),
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
      'Returned',
      'Approved',
      'Active',
      'Overdue',
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
                  borderRadius: BorderRadius.circular(
                    AppTheme.cardBorderRadius,
                  ),
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
    final statuses = _myLoans.map(LoanEligibility.statusFor).toList();
    final activeCount = statuses
        .where((status) => status == 'released' || status == 'overdue')
        .length;
    final pendingCount = statuses
        .where((status) => status == 'pending' || status == 'under review')
        .length;
    final paidCount = statuses.where((status) => status == 'completed').length;

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
            final status = LoanEligibility.statusFor(loan);
            switch (_selectedFilter) {
              case 'Pending':
                return status == 'pending' || status == 'under review';
              case 'Returned':
                return status == 'returned';
              case 'Approved':
                return status == 'approved';
              case 'Active':
                return status == 'released';
              case 'Overdue':
                return status == 'overdue';
              case 'Fully Paid':
                return status == 'completed';
              case 'Rejected':
                return status == 'rejected';
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
            final details = Loan.fromDatabase(loan);
            final rawStatus = details.status;
            final status = _loanStatusLabel(rawStatus);
            final displayStatus = _applicationProgressLabel(
              loan['_workflow_stage']?.toString(),
              loan['_review_stage']?.toString(),
              status,
            );
            final amount = _asDouble(loan['amount']);
            final monthly = _asDouble(loan['monthly_payment']);
            final tenure = _asInt(loan['tenure_months']);
            final hasSchedule = details.amortizationSchedule.isNotEmpty;
            final nextDue = details.amortizationSchedule
                .where((payment) => payment.status != PaymentStatus.completed)
                .firstOrNull
                ?.date;
            final statusColor = _getStatusColor(rawStatus);
            return Padding(
              key: ValueKey(details.id),
              padding: EdgeInsets.only(bottom: Responsive.spacing(context, 16)),
              child: _buildLoanHistoryCard(
                loan,
                loan['loan_type'] ?? 'Unknown',
                loan['application_id'] ?? 'N/A',
                loan['date_submitted'] ?? 'N/A',
                status,
                displayStatus,
                statusColor,
                amount,
                hasSchedule ? details.outstandingBalance : null,
                monthly,
                hasSchedule ? (nextDue ?? 'None') : null,
                hasSchedule
                    ? details.totalMonths - details.remainingMonths
                    : null,
                tenure,
              ),
            );
          }).toList(),
      ],
    );
  }

  double? _asDouble(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value');
  int? _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value');

  String _loanStatusLabel(String status) => switch (status.toLowerCase()) {
    'under review' => 'Under Review',
    'returned' => 'Returned',
    'released' => 'Active',
    'completed' => 'Fully Paid',
    'pending' => 'Pending',
    'approved' => 'Approved',
    'rejected' => 'Rejected',
    'overdue' => 'Overdue',
    _ => status,
  };

  String _applicationProgressLabel(
    String? workflowStage,
    String? reviewStage,
    String fallback,
  ) => switch (workflowStage?.toLowerCase()) {
    'not_started' || 'needs_verification' => 'Initial Review',
    'ready_for_committee' || 'crecom_review' => 'CRECOM Review',
    'ready_for_bod' || 'bod_review' => 'BOD Review',
    'ready_for_final' => 'Final Review',
    'review_attention' =>
      reviewStage?.toUpperCase() == 'BOD' ? 'BOD Review' : 'CRECOM Review',
    'final_approved' => 'Approved',
    'final_rejected' => 'Rejected',
    'returned_for_requirements' => 'Returned',
    _ => fallback,
  };

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'approved':
      case 'released':
      case 'completed':
        return const Color(0xFF206A3B);
      case 'pending':
      case 'under review':
      case 'returned':
        return const Color(0xFFE67E22);
      case 'rejected':
        return const Color(0xFFD32F2F);
      case 'overdue':
        return const Color(0xFFD32F2F);
      default:
        return const Color(0xFF757575);
    }
  }

  Future<void> _showApplicationStatus({
    required Map<String, dynamic> application,
    required String loanName,
    required String loanId,
    required String appliedDate,
  }) {
    final liveProgress = ValueNotifier<Map<String, dynamic>>({
      ...application,
      '_workflow_sync_error': _progressLoadError,
    });
    _openApplicationProgress = liveProgress;
    _activeProgressApplicationId = loanId;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 430,
            maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.82,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.stacked_line_chart,
                      color: AppTheme.primaryGreen,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Application Progress',
                        style: AppTheme.titleBold,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Text(
                  'You can track the status of your loan application below.',
                  style: AppTheme.captionRegular,
                ),
                const SizedBox(height: 12),
                Text('$loanName  ·  $loanId', style: AppTheme.bodyBold),
                Text('Submitted $appliedDate', style: AppTheme.captionRegular),
                const SizedBox(height: 18),
                ValueListenableBuilder<Map<String, dynamic>>(
                  valueListenable: liveProgress,
                  builder: (context, currentProgress, _) => Column(
                    children: [
                      if (currentProgress['_workflow_sync_error'] is String)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            currentProgress['_workflow_sync_error'] as String,
                            style: const TextStyle(
                              color: AppTheme.accentGold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      _ApplicationProgressTimeline(
                        status: _loanStatusLabel(
                          LoanEligibility.statusFor(currentProgress),
                        ),
                        workflowStage: currentProgress['_workflow_stage']
                            ?.toString(),
                        reviewStage: currentProgress['_review_stage']
                            ?.toString(),
                        crecomApproved: _asInt(
                          currentProgress['_crecom_approved'],
                        ),
                        crecomAssigned: _asInt(
                          currentProgress['_crecom_assigned'],
                        ),
                        bodApproved: _asInt(currentProgress['_bod_approved']),
                        bodAssigned: _asInt(currentProgress['_bod_assigned']),
                        appliedDate: appliedDate,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      if (identical(_openApplicationProgress, liveProgress)) {
        _openApplicationProgress = null;
        _activeProgressApplicationId = null;
      }
      liveProgress.dispose();
    });
  }

  Widget _buildLoanHistoryCard(
    Map<String, dynamic> application,
    String loanName,
    String loanId,
    String appliedDate,
    String status,
    String displayStatus,
    Color statusColor,
    double? principal,
    double? outstanding,
    double? monthly,
    String? nextDue,
    int? progress,
    int? totalMonths,
  ) {
    final awaitingDecision = status == 'Pending' || status == 'Under Review';
    final trackApplicationProgress =
        awaitingDecision ||
        status == 'Returned' ||
        status == 'Approved' ||
        status == 'Rejected';
    return GestureDetector(
      onTap: () {
        if (trackApplicationProgress) {
          _showApplicationStatus(
            application: application,
            loanName: loanName,
            loanId: loanId,
            appliedDate: appliedDate,
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LoanDetailsScreen(applicationId: loanId),
          ),
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
                          displayStatus,
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
              if (status == 'Active' || status == 'Overdue')
                principal != null &&
                        outstanding != null &&
                        monthly != null &&
                        nextDue != null &&
                        progress != null &&
                        totalMonths != null
                    ? _buildActiveCardContent(
                        principal,
                        outstanding,
                        monthly,
                        nextDue,
                        progress,
                        totalMonths,
                      )
                    : const Text('Repayment details are not available yet.')
              else if (status == 'Fully Paid')
                principal != null &&
                        monthly != null &&
                        progress != null &&
                        totalMonths != null
                    ? _buildFullyPaidCardContent(
                        principal,
                        monthly,
                        progress,
                        totalMonths,
                      )
                    : const Text('Repayment details are not available yet.')
              else if (awaitingDecision)
                principal == null
                    ? const SizedBox.shrink()
                    : _buildPendingCardContent(principal, status)
              else if (status == 'Returned')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Corrections are required before this application can continue.',
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const DocumentsScreen(),
                        ),
                      ),
                      child: const Text('View requirements and resubmit'),
                    ),
                  ],
                )
              else if (status == 'Approved')
                principal == null
                    ? const SizedBox.shrink()
                    : _buildApprovedCardContent(principal, totalMonths ?? 0)
              else if (status == 'Rejected')
                principal == null
                    ? const SizedBox.shrink()
                    : _buildRejectedCardContent(principal, totalMonths ?? 0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveCardContent(
    double principal,
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
                'Original Loan Amount',
                '₱${principal.toStringAsFixed(2)}',
              ),
            ),
            SizedBox(width: Responsive.spacing(context, 16)),
            Expanded(
              child: _buildInfoRow(
                'Outstanding Balance',
                '₱${outstanding.toStringAsFixed(2)}',
              ),
            ),
          ],
        ),
        SizedBox(height: Responsive.spacing(context, 12)),
        Row(
          children: [
            Expanded(
              child: _buildInfoRow(
                'Monthly Payment',
                '₱${monthly.toStringAsFixed(2)}',
              ),
            ),
            SizedBox(width: Responsive.spacing(context, 16)),
            Expanded(child: _buildInfoRow('Next Due', nextDue)),
          ],
        ),
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

  Widget _buildPendingCardContent(double principal, String status) {
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
                  status == 'Under Review'
                      ? 'Application is under review'
                      : 'Awaiting a status update',
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
                color: AppTheme.danger,
                size: Responsive.iconSize(context, 20),
              ),
              SizedBox(width: Responsive.spacing(context, 12)),
              Expanded(
                child: Text(
                  'Application not approved',
                  style: TextStyle(
                    color: AppTheme.danger,
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

  Widget _buildLoanCard(
    LoanType loanType,
    String description,
    Color color,
    bool isActive,
  ) {
    final name = loanType.label;
    final existingApplication = LoanEligibility.blockingApplication(
      loanType,
      _myLoans,
    );
    final existingStatus = '${existingApplication?['status'] ?? ''}'
        .toLowerCase();
    final isOngoing =
        existingApplication != null || _isLoading || _myLoansError != null;
    final blockedLabel = _myLoansError != null
        ? 'History Unavailable'
        : _isLoading
        ? 'Checking Applications...'
        : switch (existingStatus) {
            'pending' => 'Application Pending',
            'under review' => 'Returned',
            'approved' => 'Approved',
            'released' || 'overdue' => 'Loan Active',
            _ => 'Ongoing Loan',
          };

    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.spacing(context, 16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top colored section
            Container(
              constraints: const BoxConstraints(minHeight: 110),
              decoration: BoxDecoration(
                color: isOngoing ? AppTheme.mutedGray : color,
              ),
              child: Stack(
                alignment: Alignment.bottomLeft,
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
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
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
                  const SizedBox(width: AppTheme.spacingS),
                  if (isOngoing)
                    Flexible(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.spacing(context, 20),
                          vertical: Responsive.spacing(context, 12),
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.mutedGray,
                          borderRadius: BorderRadius.circular(
                            AppTheme.cardBorderRadius,
                          ),
                        ),
                        child: Text(
                          blockedLabel,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  else if (!isActive)
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProfileConfirmationScreen(
                                  loanType: loanType,
                                ),
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
                              borderRadius: BorderRadius.circular(
                                AppTheme.cardBorderRadius,
                              ),
                            ),
                          ),
                          child: const Text(
                            'Apply Now',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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

class _ApplicationProgressTimeline extends StatelessWidget {
  const _ApplicationProgressTimeline({
    required this.status,
    required this.workflowStage,
    required this.reviewStage,
    required this.crecomApproved,
    required this.crecomAssigned,
    required this.bodApproved,
    required this.bodAssigned,
    required this.appliedDate,
  });

  final String status;
  final String? workflowStage;
  final String? reviewStage;
  final int? crecomApproved;
  final int? crecomAssigned;
  final int? bodApproved;
  final int? bodAssigned;
  final String appliedDate;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final stage = workflowStage?.toLowerCase();
    final rejected = normalized == 'rejected' || stage == 'final_rejected';
    final finalRejected = stage == 'final_rejected';
    final returned =
        normalized == 'returned' || stage == 'returned_for_requirements';
    final completed = const {
      'released',
      'completed',
      'overdue',
    }.contains(normalized);
    final currentIndex = switch (stage) {
      'ready_for_committee' || 'crecom_review' => 2,
      'ready_for_bod' || 'bod_review' => 3,
      'ready_for_final' => 4,
      'final_approved' => 5,
      'final_rejected' => 4,
      'review_attention' => reviewStage?.toUpperCase() == 'BOD' ? 3 : 2,
      _ => switch (normalized) {
        'returned' => 1,
        'under review' => 2,
        'approved' => 5,
        'released' || 'completed' || 'overdue' => 6,
        _ => 1,
      },
    };
    final stages = [
      _ApplicationProgressStage(
        title: 'Application Submitted',
        description: 'Submitted on $appliedDate.',
        icon: Icons.check,
      ),
      _ApplicationProgressStage(
        title: rejected && !finalRejected
            ? 'Application Rejected'
            : returned
            ? 'Returned for Correction'
            : 'Initial Requirements Review',
        description: rejected && !finalRejected
            ? 'The cooperative did not approve this application.'
            : returned
            ? 'Corrections are required before the application can continue.'
            : 'The cooperative checks your application documents and requirements.',
        icon: rejected
            ? (finalRejected
                  ? Icons.assignment_turned_in_outlined
                  : Icons.close)
            : returned
            ? Icons.assignment_return_outlined
            : Icons.access_time,
      ),
      _ApplicationProgressStage(
        title: 'CRECOM Review',
        description:
            'CRECOM approval progress: ${crecomApproved ?? 0} of ${crecomAssigned ?? 3} recorded.',
        icon: Icons.groups_2_outlined,
      ),
      _ApplicationProgressStage(
        title: 'BOD Review',
        description: switch (stage) {
          'ready_for_bod' || 'bod_review' =>
            'BOD approval progress: ${bodApproved ?? 0} of ${bodAssigned ?? 1} recorded.',
          _ => 'The Board of Directors reviews the application after CRECOM.',
        },
        icon: Icons.gavel_outlined,
      ),
      _ApplicationProgressStage(
        title: finalRejected ? 'Final Decision · Rejected' : 'Final Review',
        description: finalRejected
            ? 'The application was rejected after cooperative review.'
            : stage == 'ready_for_final'
            ? 'CRECOM: ${crecomApproved ?? 0} of ${crecomAssigned ?? 3} approved. BOD: ${bodApproved ?? 0} of ${bodAssigned ?? 1} approved. The application is awaiting the final decision.'
            : 'The cooperative records its final decision after committee review.',
        icon: finalRejected ? Icons.close : Icons.fact_check_outlined,
      ),
      _ApplicationProgressStage(
        title: 'Loan Release',
        description: completed
            ? 'Your approved loan has been released.'
            : normalized == 'approved' || stage == 'final_approved'
            ? 'Your loan is approved and being prepared for release.'
            : 'The loan is released after final approval.',
        icon: Icons.account_balance_outlined,
      ),
    ];

    return Column(
      children: List.generate(stages.length, (index) {
        final stage = stages[index];
        final isRejected = rejected && index == (finalRejected ? 4 : 1);
        final isComplete = index < currentIndex || (completed && index == 5);
        final isCurrent = !completed && !rejected && index == currentIndex;
        final state = isRejected
            ? 'Rejected'
            : isComplete
            ? 'Completed'
            : isCurrent
            ? 'Current'
            : 'Upcoming';
        final accent = isRejected
            ? AppTheme.danger
            : (isComplete || isCurrent)
            ? AppTheme.primaryGreen
            : const Color(0xFFB8C0BC);
        final cardColor = isCurrent
            ? const Color(0xFFEAF4E9)
            : AppTheme.cardWhite;

        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isComplete ? AppTheme.primaryGreen : cardColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accent,
                        width: isCurrent ? 2 : 1.5,
                      ),
                    ),
                    child: Icon(
                      isComplete ? Icons.check : stage.icon,
                      size: 13,
                      color: isComplete ? Colors.white : accent,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                stage.title,
                                style: const TextStyle(
                                  color: Color(0xFF183A24),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _ProgressStateBadge(label: state, color: accent),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          stage.description,
                          style: const TextStyle(
                            color: Color(0xFF637169),
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (index < stages.length - 1)
              Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Center(
                      child: Container(
                        width: 2,
                        height: 12,
                        color: index < currentIndex
                            ? AppTheme.primaryGreen.withOpacity(0.55)
                            : const Color(0xFFD5DAD7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ),
          ],
        );
      }),
    );
  }
}

class _ApplicationProgressStage {
  const _ApplicationProgressStage({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}

class _ProgressStateBadge extends StatelessWidget {
  const _ProgressStateBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700),
    ),
  );
}
