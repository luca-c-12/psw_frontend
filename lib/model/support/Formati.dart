String _dueCifre(int n) => n.toString().padLeft(2, '0');

/// 12.5 → "€ 12,50"
String formattaEuro(double valore) {
  return "€ ${valore.toStringAsFixed(2).replaceAll('.', ',')}";
}

/// → "05/10/2026"
String formattaData(DateTime d) {
  return "${_dueCifre(d.day)}/${_dueCifre(d.month)}/${d.year}";
}

/// → "05/10/2026 16:30"
String formattaDataOra(DateTime d) {
  return "${formattaData(d)} ${_dueCifre(d.hour)}:${_dueCifre(d.minute)}";
}

/// Data e ora da mandare al backend (LocalDateTime, senza fuso orario): "2026-10-05T16:30:00.000"
String dataPerBackend(DateTime d) {
  return d.toIso8601String();
}

/// Solo il giorno, nel formato dei parametri LocalDate del backend: "2026-10-05"
String giornoPerBackend(DateTime d) {
  return "${d.year}-${_dueCifre(d.month)}-${_dueCifre(d.day)}";
}

/// Legge un importo scritto dall'utente ("12,50" o "12.50"). Restituisce null se non è un numero.
double? leggiImporto(String testo) {
  double? valore = double.tryParse(testo.trim().replaceAll(',', '.'));
  // tryParse accetta anche "NaN" e "Infinity"
  return valore != null && valore.isFinite ? valore : null;
}

/// true se il testo è un importo con al massimo 8 cifre intere e 2 decimali (come vuole il backend).
bool importoValido(String testo) {
  return RegExp(r'^\d{1,8}([.,]\d{1,2})?$').hasMatch(testo.trim());
}
