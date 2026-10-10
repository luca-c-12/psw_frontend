import 'package:psw_frontend/model/objects/Prodotto.dart';


class Asta {
  int idAsta;
  Prodotto prodotto;
  DateTime dataInizio;
  DateTime dataFine;
  double prezzoBase;
  OffertaAsta? offertaMassima;   // null se non ci sono ancora offerte
  double prezzoCorrente;         // offerta massima, oppure prezzo base se non ci sono offerte
  String stato;                  // "PROGRAMMATA", "IN_CORSO" o "TERMINATA"
  bool chiusa;
  String? vincitore;             // null finché l'asta non è chiusa (o se nessuno poteva pagare)


  Asta({required this.idAsta, required this.prodotto, required this.dataInizio, required this.dataFine, required this.prezzoBase, this.offertaMassima, required this.prezzoCorrente, required this.stato, required this.chiusa, this.vincitore});

  factory Asta.fromJson(Map<String, dynamic> json) {
    return Asta(
      idAsta: json['idAsta'],
      prodotto: Prodotto.fromJson(json['prodotto']),
      dataInizio: DateTime.parse(json['dataInizio']),
      dataFine: DateTime.parse(json['dataFine']),
      prezzoBase: (json['prezzoBase'] as num).toDouble(),
      offertaMassima: json['offertaMassima'] == null ? null : OffertaAsta.fromJson(json['offertaMassima']),
      prezzoCorrente: (json['prezzoCorrente'] as num).toDouble(),
      stato: json['stato'],
      chiusa: json['chiusa'],
      vincitore: json['vincitore'],
    );
  }

  bool get inCorso => stato == "IN_CORSO";

  String get nomeStato {
    if (stato == "PROGRAMMATA") return "Programmata";
    if (stato == "IN_CORSO") return "In corso";
    return "Terminata";
  }


}


class OffertaAsta {
  int idOffertaAsta;
  int idAsta;
  int idCliente;
  String? offerente;      // es. "Mario R."
  double importo;
  DateTime dataOfferta;


  OffertaAsta({required this.idOffertaAsta, required this.idAsta, required this.idCliente, this.offerente, required this.importo, required this.dataOfferta});

  factory OffertaAsta.fromJson(Map<String, dynamic> json) {
    return OffertaAsta(
      idOffertaAsta: json['idOffertaAsta'],
      idAsta: json['idAsta'],
      idCliente: json['idCliente'],
      offerente: json['offerente'],
      importo: (json['importo'] as num).toDouble(),
      dataOfferta: DateTime.parse(json['dataOfferta']),
    );
  }


}
