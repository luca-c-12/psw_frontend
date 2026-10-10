/// Una pagina di risultati (Page<T> di Spring): Pagina.fromJson(jsonDecode(risposta), Prodotto.fromJson)
class Pagina<T> {
  List<T> contenuto;
  int numero;          // numero di questa pagina (parte da 0)
  int totalePagine;
  int totaleElementi;


  Pagina({required this.contenuto, required this.numero, required this.totalePagine, required this.totaleElementi});

  factory Pagina.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) convertiElemento) {
    Map<String, dynamic> info = json['page'];
    return Pagina<T>(
      contenuto: (json['content'] as List).map((e) => convertiElemento(e as Map<String, dynamic>)).toList(),
      numero: info['number'],
      totalePagine: info['totalPages'],
      totaleElementi: info['totalElements'],
    );
  }

  /// true se dopo questa pagina non ce ne sono altre.
  bool get ultima => numero + 1 >= totalePagine;


}
