/// Ported 1:1 from the Next.js app's `IncomeSourceSchema` in `src/lib/schemas.ts`.
enum IncomeSource {
  estagio('Estágio'),
  freela('freela'),
  outro('outro');

  final String value;
  const IncomeSource(this.value);

  static IncomeSource fromValue(String value) {
    return IncomeSource.values.firstWhere(
      (s) => s.value == value,
      orElse: () => IncomeSource.outro,
    );
  }
}
