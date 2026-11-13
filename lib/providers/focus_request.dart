import 'package:flutter_riverpod/legacy.dart';

/// Which form field a page should put the cursor in the next time it is on
/// screen. Set by a button on another page (the Dashboard's "Lançar receita"
/// and "Lançar gasto") just before navigating: the destination page consumes
/// it as soon as it is visible and resets it to null.
enum FocusRequest { incomeAmount, expenseAmount }

final focusRequestProvider = StateProvider<FocusRequest?>((ref) => null);
