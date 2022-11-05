import 'dart:convert';

import 'package:copan_flutter/data/expense/expense_category.dart';
import 'package:copan_flutter/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../data/expense/expense.dart';
import '../../data/local/db/dao.dart' as db;
import '../../notifier/notifier.dart';
import '../../resources/expense_category.dart';
import '../../theme/app_theme.dart';
import '../../utility/format_price.dart';
import '../widget/custom_card.dart';
import '../widget/custom_inkwell.dart';
import '../widget/expenses_chart.dart';
import '../widget/total_expense.dart';
import 'drawer.dart';

class Expenses extends StatelessWidget {
  const Expenses({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appTheme = getAppTheme(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('家計簿'),
      ),
      drawer: const AppDrawer(),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Container(
              color: appTheme.appColors.secondaryBackground,
              height: 12,
            ),
          ),
          SliverToBoxAdapter(
            child: LayoutBuilder(builder: (context, constraint) {
              return Container(
                color: appTheme.appColors.secondaryBackground,
                child: CustomCard(
                  child: Column(children: [
                    const MonthSelector(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: ExpensesChart(),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: TotalExpense(
                              width: constraint.maxWidth / 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ]),
                ),
              );
            }),
          ),
          SliverToBoxAdapter(
            child: Container(
              color: appTheme.appColors.secondaryBackground,
              height: 12,
            ),
          ),
          const _Expenses(),
          const SliverToBoxAdapter(
            child: SizedBox(height: 96),
          ),
        ]),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).pushNamed('/inputExpense'),
        backgroundColor: appTheme.appColors.accentColor,
        child: Icon(
          Icons.add,
          color: appTheme.appColors.secondaryText,
        ),
      ),
    );
  }
}

class MonthSelector extends ConsumerStatefulWidget {
  const MonthSelector({Key? key}) : super(key: key);

  @override
  MonthSelectorState createState() => MonthSelectorState();
}

class MonthSelectorState extends ConsumerState<MonthSelector> {
  late String showDateString;

  @override
  void initState() {
    super.initState();
    ref.read(selectedMonthProvider);
  }

  void showPrevMonth() {
    var selectedMonth = ref.watch(selectedMonthProvider);
    ref.read(selectedMonthProvider.notifier).state =
        DateTime(selectedMonth.year, selectedMonth.month - 1);
  }

  void showNextMonth() {
    var selectedMonth = ref.watch(selectedMonthProvider);
    ref.read(selectedMonthProvider.notifier).state =
        DateTime(selectedMonth.year, selectedMonth.month + 1);
  }

  @override
  Widget build(BuildContext context) {
    final targetMonth = ref.watch(selectedMonthProvider);
    final dateString = getDateString(targetMonth: targetMonth);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CustomInkWell(icon: Icons.arrow_left, onTap: showPrevMonth),
                Text(
                  dateString,
                  style: const TextStyle(fontSize: 18),
                ),
                CustomInkWell(icon: Icons.arrow_right, onTap: showNextMonth),
              ],
            ),
          );
        },
      ),
    );
  }

  String getDateString({required DateTime targetMonth}) {
    String showDateString = '${targetMonth.year}年${targetMonth.month}月~';

    return showDateString;
  }
}

class _Expenses extends ConsumerWidget {
  const _Expenses({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesList = ref.watch(filteredExpensesProvider);
    final expensesByCategoryList =
        getExpensesByCategory(expenses: expensesList);

    late final Widget widget;

    if (expensesByCategoryList.isNotEmpty) {
      widget = SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final expensesByCategory = expensesByCategoryList[index];
            late final String expenseName;
            late final IconData expenseCategoryIcon;
            late final Color? expenseCategoryIconColor;

            expenseName =
                expenseCategoryMap[expensesByCategory.categoryId]?.name ??
                    defaultExpenseCategory.name;
            expenseCategoryIcon =
                expenseCategoryMap[expensesByCategory.categoryId]?.icon ??
                    defaultExpenseCategory.icon;
            expenseCategoryIconColor =
                expenseCategoryMap[expensesByCategory.categoryId]?.iconColor ??
                    defaultExpenseCategory.iconColor;

            final listTiles = <Dismissible>[];
            for (final expense in expensesByCategory.expenses) {
              final formattedPrice = getFormattedPrice(expense.price);
              listTiles.add(
                Dismissible(
                  key: UniqueKey(),
                  background: Container(
                    color: Colors.red,
                    child: Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: const [
                              Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                              Icon(
                                Icons.navigate_next,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        )),
                  ),
                  direction: DismissDirection.startToEnd,
                  child: ListTile(
                    // leadingで上下中央によせるため、
                    // ColumnのmainAxisAlignmentで調整、回避している
                    leading: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _getMonthAndDay(expense.createDate),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    title: Text(
                      expense.description,
                      style: const TextStyle(fontSize: 14),
                      textHeightBehavior: const TextHeightBehavior(
                        applyHeightToFirstAscent: false,
                        applyHeightToLastDescent: false,
                      ),
                    ),
                    trailing: Text(
                      '\u00A5$formattedPrice',
                      style: const TextStyle(fontSize: 14),
                    ),
                    onTap: () {
                      // TODO: 各費目をタップしたときの処理
                    },
                  ),
                  onDismissed: (_) {
                    _request(
                      expenseUuid: expense.expenseUuid,
                    );

                    db.copanDB.deleteExpense(
                      expenseUuid: expense.expenseUuid,
                    );

                    ref
                        .read(expensesProvider.notifier)
                        .deleteExpense(expense.expenseUuid);
                  },
                ),
              );
            }

            return ExpansionTile(
              leading: Icon(
                expenseCategoryIcon,
                color: expenseCategoryIconColor,
              ),
              title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(expenseName),
                    Text(
                        '\u00A5 ${getFormattedPrice(expensesByCategory.totalPrice)}')
                  ]),
              children: listTiles,
            );
          },
          childCount: expensesByCategoryList.length,
        ),
      );
    } else {
      widget = const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text(
              '今月の支出はありません',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }
    return widget;
  }
}

List<ExpensesByCategory> getExpensesByCategory(
    {required List<Expense> expenses}) {
  final expensesByCategoryList = <ExpensesByCategory>[];

  for (final expense in expenses) {
    bool containsCategory = false;
    for (final expensesByCategory in expensesByCategoryList) {
      if (expensesByCategory.categoryId == expense.categoryId) {
        containsCategory = true;
        expensesByCategory.expenses.add(expense);
        expensesByCategory.totalPrice += expense.price;
      }
    }
    // まだ追加していないカテゴリをリストに加える
    if (!containsCategory) {
      expensesByCategoryList.add(ExpensesByCategory(
          categoryId: expense.categoryId,
          expenses: [expense],
          totalPrice: expense.price));
    }
  }
  return expensesByCategoryList;
}

class ExpensesByCategory {
  ExpensesByCategory({
    required this.categoryId,
    required this.expenses,
    required this.totalPrice,
  });

  CategoryId categoryId;
  List<Expense> expenses;
  int totalPrice;
}

String _getMonthAndDay(DateTime date) {
  return "${date.month}/${date.day}";
}

Future<void> _request({
  required String expenseUuid,
}) async {
  final req = <String, dynamic>{
    "action": "deleteExpense",
    "expenseUuid": expenseUuid,
  };
  Map<String, String> headers = {'content-type': 'application/json'};
  String body = json.encode(req);
  try {
    http.Response resp =
        await http.post(Uri.parse(uri), headers: headers, body: body);

    if (resp.statusCode != 200) {
      throw AssertionError("Failed get response");
    }
  } catch (e) {
    rethrow;
  }
}
