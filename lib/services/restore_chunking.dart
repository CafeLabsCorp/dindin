/// Chunking for the batched writes/deletes `FirestoreService.replaceAll` and
/// `FirestoreService.deleteAllUserData` issue against Firestore.
///
/// Two INDEPENDENT ceilings apply to a single `batch.commit()`, and both are
/// pinned by `test/rules/rules.test.mjs` ("rules document-access ceiling
/// (H1)" and "full account deletion (B5)"):
///
///  1. Firestore's own hard cap of 500 writes per batch (kept at a
///     conservative 400 here, unchanged from before this fix existed).
///  2. `firestore.rules`' DOCUMENT-ACCESS CEILING: a batch can trigger at
///     most 20 total `get()`/`getAfter()` calls across every rule it
///     evaluates. Writing or deleting a ledger doc that references a
///     caixinha (a category, or an allocation/expense with a `categoryId`)
///     costs one such call PER DISTINCT caixinha touched in the batch
///     (repeats on the same caixinha are cached and free) — see the
///     "DOCUMENT-ACCESS CEILING" comment atop `firestore.rules`.
///
/// Before this fix, `replaceAll` chunked ONLY on (1) — a fixed 400 docs per
/// batch — which a restore spanning 20+ distinct caixinhas blew straight
/// through, failing at step 2/3 AFTER step 1 had already wiped the balance
/// docs: a data-loss bug, not a cosmetic one (confirmed against the
/// Firestore emulator: 19 caixinhas succeeds, 20 fails).
library;

/// Splits [items] into chunks that are safe to commit as one Firestore
/// batch. [categoryOf] returns the caixinha id a given item's write/delete
/// would charge against the rules' document-access ceiling, or `null` if it
/// charges none at all (e.g. a subscription or installment purchase, whose
/// rules never call `get()`/`getAfter()`).
///
/// [maxDistinctCategories] defaults to 19, not 20: almost every ledger
/// write/delete that touches a caixinha ALSO reads `meta/account` in the
/// same rule evaluation (see `accountDeltaOk`/`accountNonNeg` in
/// `firestore.rules`), so one slot of the 20-call budget is reserved for
/// that shared access, matching the cliff `rules.test.mjs` measures against
/// the real emulator exactly (19 succeeds, 20 fails). Applying this ceiling
/// uniformly to every category-touching write — even the few whose rule
/// happens not to also touch the account — is a deliberate, safe
/// over-approximation: it never turns a valid batch into an invalid one, it
/// only occasionally splits a batch one chunk earlier than the bare minimum
/// would require, and a restore/delete is a rare, one-time operation where
/// that headroom costs nothing a user would notice.
///
/// Ordering is preserved — chunk N always precedes chunk N+1 in the original
/// list order — so callers relying on `for (final chunk in ...)` executing
/// batches in sequence see the same effective order as an unchunked run.
List<List<T>> chunkForRulesCeiling<T>(
  List<T> items,
  String? Function(T item) categoryOf, {
  int maxDistinctCategories = 19,
  int maxDocsPerBatch = 400,
}) {
  final chunks = <List<T>>[];
  var current = <T>[];
  var categoriesInChunk = <String>{};

  for (final item in items) {
    final category = categoryOf(item);
    final addsNewCategory = category != null && !categoriesInChunk.contains(category);
    final wouldExceedCategories =
        addsNewCategory && categoriesInChunk.length + 1 > maxDistinctCategories;
    final wouldExceedDocs = current.length >= maxDocsPerBatch;

    if (current.isNotEmpty && (wouldExceedCategories || wouldExceedDocs)) {
      chunks.add(current);
      current = [];
      categoriesInChunk = {};
    }

    current.add(item);
    if (category != null) categoriesInChunk.add(category);
  }

  if (current.isNotEmpty) chunks.add(current);
  return chunks;
}
