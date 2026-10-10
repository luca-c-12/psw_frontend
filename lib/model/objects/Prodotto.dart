/// Nomi leggibili delle categorie (le chiavi sono i valori dell'enum CategoriaProdotto del backend).
const Map<String, String> CATEGORIE = {
  "ELETTRONICA": "Elettronica",
  "LIBRI": "Libri",
  "CASA_E_CUCINA": "Casa e cucina",
  "ABBIGLIAMENTO_SCARPE_GIOIELLI": "Abbigliamento, scarpe e gioielli",
  "BELLEZZA_E_SALUTE": "Bellezza e salute",
  "ALIMENTARI": "Alimentari",
  "SPORT_E_TEMPO_LIBERO": "Sport e tempo libero",
  "GIOCHI_E_GIOCATTOLI": "Giochi e giocattoli",
  "AUTO_E_MOTO": "Auto e moto",
  "CANCELLERIA_E_UFFICIO": "Cancelleria e ufficio",
  "PRODOTTI_PER_ANIMALI": "Prodotti per animali",
  "FAI_DA_TE": "Fai da te",
  "FILM_E_TV": "Film e TV",
  "VIDEOGIOCHI": "Videogiochi",
  "INFORMATICA": "Informatica",
  "GIARDINO_E_GIARDINAGGIO": "Giardino e giardinaggio",
};


class Prodotto {
  int codiceProdotto;
  String nome;
  String? descrizione;
  String? brand;
  double prezzo;
  String categoria;       // es. "ELETTRONICA"
  bool disponibile;
  String? urlImmagine;


  Prodotto({required this.codiceProdotto, required this.nome, this.descrizione, this.brand, required this.prezzo, required this.categoria, required this.disponibile, this.urlImmagine});

  factory Prodotto.fromJson(Map<String, dynamic> json) {
    return Prodotto(
      codiceProdotto: json['codiceProdotto'],
      nome: json['nome'],
      descrizione: json['descrizione'],
      brand: json['brand'],
      prezzo: (json['prezzo'] as num).toDouble(),
      categoria: json['categoria'],
      disponibile: json['disponibile'],
      urlImmagine: json['urlImmagine'],
    );
  }

  String get nomeCategoria => CATEGORIE[categoria] ?? categoria;

  @override
  String toString() {
    return nome;
  }


}


/// Prodotto visto dall'admin: in più ha giacenza e visibilità.
class ProdottoAdmin {
  Prodotto prodotto;
  int quantita;
  bool visibile;


  ProdottoAdmin({required this.prodotto, required this.quantita, required this.visibile});

  factory ProdottoAdmin.fromJson(Map<String, dynamic> json) {
    return ProdottoAdmin(
      prodotto: Prodotto.fromJson(json['prodotto']),
      quantita: json['quantita'],
      visibile: json['visibile'],
    );
  }


}


class Recensione {
  int idRecensione;
  int codiceProdotto;
  int idCliente;
  String? autore;         // es. "Mario R."
  int voto;               // da 1 a 5
  String? testo;
  DateTime dataRecensione;


  Recensione({required this.idRecensione, required this.codiceProdotto, required this.idCliente, this.autore, required this.voto, this.testo, required this.dataRecensione});

  factory Recensione.fromJson(Map<String, dynamic> json) {
    return Recensione(
      idRecensione: json['idRecensione'],
      codiceProdotto: json['codiceProdotto'],
      idCliente: json['idCliente'],
      autore: json['autore'],
      voto: json['voto'],
      testo: json['testo'],
      dataRecensione: DateTime.parse(json['dataRecensione']),
    );
  }


}
