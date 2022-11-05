import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'dao.g.dart';

// TODO: DBの呼び出し検討
final copanDB = CopanDB();

@DataClassName('ExpenseTable')
class ExpensesTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get price => integer()();
  IntColumn get categoryId => integer()();
  TextColumn get description => text().withLength(max: 200)();
  DateTimeColumn get createDate => dateTime()();
  TextColumn get expenseUuid => text().withLength()();
}

@DataClassName('UserTable')
class UsersTable extends Table {
  TextColumn get email => text().nullable()();
  TextColumn get accessToken => text().nullable()();

  @override
  Set<Column> get primaryKey => {email};
}

@DriftDatabase(
  tables: [ExpensesTable, UsersTable],
)
class CopanDB extends _$CopanDB {
  CopanDB() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  Future<List<ExpenseTable>> get getAllExpenseEntries =>
      select(expensesTable).get();

  Future<int> addExpense(ExpensesTableCompanion entry) {
    return into(expensesTable).insert(entry);
  }

  Future<void> deleteExpense({required String expenseUuid}) {
    return (delete(expensesTable)
          ..where((table) => table.expenseUuid.equals(expenseUuid)))
        .go();
  }

  Future<int> addUser(UsersTableCompanion entry) {
    return into(usersTable).insertOnConflictUpdate(entry);
  }

  Future<int> deleteUser() {
    return delete(usersTable).go();
  }

  Future<List<UserTable>> get getUser => select(usersTable).get();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.splite'));
    return NativeDatabase(file);
  });
}
