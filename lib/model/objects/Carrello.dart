import 'package:psw_frontend/model/objects/Prodotto.dart';


class Carrello {
  int idCarrello;
  List<RigaCarrello> righe;      // nel JSON si chiama "prodotti"
  int numeroArticoli;
  double totale;


  Carrello({required this.idCarrello, required this.righe, required this.numeroArticoli, required this.totale});

  factory Carrello.fromJson(Map<String, dynamic> json) {
    return Carrello(
      idCarrello: json['idCarrello'],
      righe: (json['prodotti'] as List).map((r) => RigaCarrello.fromJson(r)).toList(),
      numeroArticoli: json['numeroArticoli'],
      totale: (json['totale'] as num).toDouble(),
    );
  }

  /// Si può ordinare solo se il carrello non è vuoto e tutte le righe sono disponibili.
  bool get acquistabile => righe.isNotEmpty && righe.every((r) => r.disponibile);

  /// Body di POST /ordini: le righe così come il cliente le ha viste (il backend risponde 409 se sono cambiate).
  Map<String, dynamic> toCheckoutRequest() => {
    'righe': righe.map((r) => r.toRigaCheckout()).toList(),
  };


}


class RigaCarrello {
  int idRecordCarrello;
  Prodotto prodotto;
  int quantita;
  double subtotale;
  bool disponibile;       // false se il prodotto è stato nascosto o la giacenza non basta


  RigaCarrello({required this.idRecordCarrello, required this.prodotto, required this.quantita, required this.subtotale, required this.disponibile});

  factory RigaCarrello.fromJson(Map<String, dynamic> json) {
    return RigaCarrello(
      idRecordCarrello: json['idRecordCarrello'],
      prodotto: Prodotto.fromJson(json['prodotto']),
      quantita: json['quantita'],
      subtotale: (json['subtotale'] as num).toDouble(),
      disponibile: json['disponibile'],
    );
  }

  int get codiceProdotto => prodotto.codiceProdotto;
  String get nomeProdotto => prodotto.nome;
  double get prezzoUnitario => prodotto.prezzo;

  Map<String, dynamic> toRigaCheckout() => {
    'codiceProdotto': codiceProdotto,
    'quantita': quantita,
    'prezzoUnitario': prezzoUnitario,
  };


}


/// OrdineDTO (completo) oppure OrdineSintesiDTO (solo id, data e totale: indirizzo null e righe vuote).
class Ordine {
  int idOrdine;
  DateTime dataOrdine;
  double totalePagato;
  String? indirizzoSpedizione;
  List<LineaOrdine> righe;      // nel JSON si chiama "prodottiAcquistati"


  Ordine({required this.idOrdine, required this.dataOrdine, required this.totalePagato, this.indirizzoSpedizione, this.righe = const []});

  factory Ordine.fromJson(Map<String, dynamic> json) {
    return Ordine(
      idOrdine: json['idOrdine'],
      dataOrdine: DateTime.parse(json['dataOrdine']),
      totalePagato: (json['totalePagato'] as num).toDouble(),
      indirizzoSpedizione: json['indirizzoSpedizione'],
      righe: ((json['prodottiAcquistati'] ?? []) as List).map((r) => LineaOrdine.fromJson(r)).toList(),
    );
  }


}


/// Riga di un ordine: nome e prezzo sono quelli del momento dell'acquisto.
class LineaOrdine {
  int idLineaOrdine;
  int? codiceProdotto;          // null se il prodotto è stato eliminato
  String nomeProdotto;
  double prezzoUnitario;
  int quantita;
  double subtotale;
  String? urlImmagine;


  LineaOrdine({required this.idLineaOrdine, this.codiceProdotto, required this.nomeProdotto, required this.prezzoUnitario, required this.quantita, required this.subtotale, this.urlImmagine});

  factory LineaOrdine.fromJson(Map<String, dynamic> json) {
    return LineaOrdine(
      idLineaOrdine: json['idLineaOrdine'],
      codiceProdotto: json['codiceProdotto'],
      nomeProdotto: json['nomeProdotto'],
      prezzoUnitario: (json['prezzoUnitario'] as num).toDouble(),
      quantita: json['quantita'],
      subtotale: (json['subtotale'] as num).toDouble(),
      urlImmagine: json['urlImmagine'],
    );
  }


}
