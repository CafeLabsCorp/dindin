/// The pages that have an onboarding tutorial. The [id] is the field name in
/// `users/{uid}/meta/tutorials` and MUST stay in sync with the closed list in
/// `firestore.rules` (`validTutorials`).
enum TutorialPage {
  dashboard,
  receitas,
  gastos,
  assinaturas,
  parcelamentos,
  categorias,
  ajustes;

  String get id => name;

  static TutorialPage? fromId(String id) {
    for (final page in values) {
      if (page.id == id) return page;
    }
    return null;
  }
}

/// How a tutorial ended. Both count as "seen"; the difference only shows in
/// Ajustes ("Pulado").
enum TutorialState {
  done,
  skipped;

  static TutorialState? fromId(Object? id) {
    for (final state in values) {
      if (state.name == id) return state;
    }
    return null;
  }
}

/// The current version of each page's tutorial. Bump a page's number when its
/// layout changes enough that the old tour no longer fits: users whose saved
/// [TutorialEntry.version] is lower see that one tutorial again.
const Map<TutorialPage, int> tutorialVersions = {
  TutorialPage.dashboard: 1,
  TutorialPage.receitas: 1,
  TutorialPage.gastos: 1,
  TutorialPage.assinaturas: 1,
  TutorialPage.parcelamentos: 1,
  TutorialPage.categorias: 1,
  TutorialPage.ajustes: 1,
};

/// One page's saved outcome.
class TutorialEntry {
  final TutorialState state;
  final int version;

  const TutorialEntry({required this.state, required this.version});

  /// Null when [map] isn't a well-formed entry (treated as "not seen").
  static TutorialEntry? fromMap(Object? map) {
    if (map is! Map) return null;
    final state = TutorialState.fromId(map['state']);
    final version = map['v'];
    if (state == null || version is! int) return null;
    return TutorialEntry(state: state, version: version);
  }

  Map<String, dynamic> toMap() => {'state': state.name, 'v': version};

  /// Whether this saved outcome still covers the CURRENT version of [page].
  bool covers(TutorialPage page) => version >= (tutorialVersions[page] ?? 1);
}

/// Parses the whole `meta/tutorials` doc; unknown or malformed entries are
/// dropped rather than failing the screen.
Map<TutorialPage, TutorialEntry> parseTutorialProgress(Map<String, dynamic>? data) {
  final result = <TutorialPage, TutorialEntry>{};
  if (data == null) return result;
  for (final entry in data.entries) {
    final page = TutorialPage.fromId(entry.key);
    final parsed = TutorialEntry.fromMap(entry.value);
    if (page != null && parsed != null) result[page] = parsed;
  }
  return result;
}
