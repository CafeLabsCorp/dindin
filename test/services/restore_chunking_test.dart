import 'package:flutter_test/flutter_test.dart';

import 'package:dindin/services/restore_chunking.dart';

void main() {
  group('chunkForRulesCeiling', () {
    test('empty input yields no chunks', () {
      expect(chunkForRulesCeiling<int>([], (i) => null), isEmpty);
    });

    test('items with no category are chunked purely by doc count', () {
      final items = List.generate(850, (i) => i);
      final chunks = chunkForRulesCeiling<int>(items, (i) => null, maxDocsPerBatch: 400);
      expect(chunks.length, 3); // 400 + 400 + 50
      expect(chunks[0].length, 400);
      expect(chunks[1].length, 400);
      expect(chunks[2].length, 50);
      // Order is preserved end to end.
      expect(chunks.expand((c) => c).toList(), items);
    });

    test('a batch spanning exactly maxDistinctCategories stays in one chunk', () {
      // 19 items, each its own distinct category — the tested-safe cliff.
      final items = List.generate(19, (i) => 'c$i');
      final chunks = chunkForRulesCeiling<String>(items, (c) => c, maxDistinctCategories: 19);
      expect(chunks, [items]);
    });

    test('the 20th distinct category starts a new chunk', () {
      final items = List.generate(20, (i) => 'c$i');
      final chunks = chunkForRulesCeiling<String>(items, (c) => c, maxDistinctCategories: 19);
      expect(chunks.length, 2);
      expect(chunks[0].length, 19);
      expect(chunks[1], ['c19']);
    });

    test('repeated references to the SAME category never split a chunk', () {
      // 500 allocations, all in the same one caixinha — the real shape of a
      // heavy single-category ledger. Only the doc-count cap should apply.
      final items = List.generate(500, (i) => 'only-one-category');
      final chunks = chunkForRulesCeiling<String>(
        items,
        (c) => c,
        maxDistinctCategories: 19,
        maxDocsPerBatch: 400,
      );
      expect(chunks.length, 2);
      expect(chunks[0].length, 400);
      expect(chunks[1].length, 100);
    });

    test('mixed doc-count and category ceilings: whichever is hit first splits the chunk', () {
      // 5 distinct categories, 10 docs each = 50 docs total. Doc-count cap of
      // 12 should split before the category cap (5) ever matters.
      final items = [for (var c = 0; c < 5; c++) for (var i = 0; i < 10; i++) 'c$c'];
      final chunks = chunkForRulesCeiling<String>(
        items,
        (c) => c,
        maxDistinctCategories: 19,
        maxDocsPerBatch: 12,
      );
      expect(chunks.every((c) => c.length <= 12), isTrue);
      expect(chunks.expand((c) => c).toList(), items);
    });

    test('a realistic restore of 25 caixinhas splits into exactly two chunks under the default cap', () {
      final items = List.generate(25, (i) => 'c$i');
      final chunks = chunkForRulesCeiling<String>(items, (c) => c);
      expect(chunks.length, 2);
      expect(chunks[0].length, 19);
      expect(chunks[1].length, 6);
      for (final chunk in chunks) {
        expect(chunk.toSet().length <= 19, isTrue);
      }
    });

    test('null-category items interleaved with category items are never miscounted', () {
      final items = ['c0', null, 'c1', null, 'c0', 'c2'];
      final chunks = chunkForRulesCeiling<String?>(
        items,
        (c) => c,
        maxDistinctCategories: 2,
      );
      // c0, null, c1 = 2 distinct categories (c0, c1) -> fits.
      // null, c0 (repeat, free), c2 -> c2 is the 3rd distinct id relative to
      // the running chunk, which resets once the cap (2) would be exceeded.
      expect(chunks.expand((c) => c).toList(), items);
      for (final chunk in chunks) {
        final distinct = chunk.whereType<String>().toSet();
        expect(distinct.length <= 2, isTrue);
      }
    });
  });
}
