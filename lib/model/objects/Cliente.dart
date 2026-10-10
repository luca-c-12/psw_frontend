/// Profilo del cliente loggato (ClienteDTO, che contiene un UtenteDTO annidato).
class Cliente {
  int idUtente;
  String? nome;
  String? cognome;
  String? email;
  String? indirizzo;
  double saldo;


  Cliente({required this.idUtente, this.nome, this.cognome, this.email, this.indirizzo, required this.saldo});

  factory Cliente.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> utente = json['utente'];
    return Cliente(
      idUtente: utente['idUtente'],
      nome: utente['nome'],
      cognome: utente['cognome'],
      email: utente['email'],
      indirizzo: json['indirizzo'],
      saldo: (json['saldo'] as num).toDouble(),
    );
  }

  String get nomeCompleto => "${nome ?? ''} ${cognome ?? ''}".trim();

  @override
  String toString() {
    return nomeCompleto;
  }


}


/// Utente visto dall'admin (UtenteDTO).
class Utente {
  int idUtente;
  String? nome;
  String? cognome;
  String? email;
  String ruolo;                 // "CLIENTE" o "ADMIN"
  DateTime? dataRegistrazione;
  bool attivo;                  // false se l'account è stato disattivato


  Utente({required this.idUtente, this.nome, this.cognome, this.email, required this.ruolo, this.dataRegistrazione, required this.attivo});

  factory Utente.fromJson(Map<String, dynamic> json) {
    return Utente(
      idUtente: json['idUtente'],
      nome: json['nome'],
      cognome: json['cognome'],
      email: json['email'],
      ruolo: json['ruolo'],
      dataRegistrazione: json['dataRegistrazione'] == null ? null : DateTime.parse(json['dataRegistrazione']),
      // il campo del record si chiama isVisible: a seconda della versione di Jackson arriva come "isVisible" o "visible"
      attivo: json['isVisible'] ?? json['visible'] ?? true,
    );
  }

  String get nomeCompleto => "${nome ?? ''} ${cognome ?? ''}".trim();


}
