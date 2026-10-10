import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:psw_frontend/model/managers/RestManager.dart';
import 'package:psw_frontend/model/objects/Asta.dart';
import 'package:psw_frontend/model/objects/AuthenticationData.dart';
import 'package:psw_frontend/model/objects/Carrello.dart';
import 'package:psw_frontend/model/objects/Cliente.dart';
import 'package:psw_frontend/model/objects/Pagina.dart';
import 'package:psw_frontend/model/objects/Prodotto.dart';
import 'package:psw_frontend/model/support/Constants.dart';
import 'package:psw_frontend/model/support/LogInResult.dart';


/// Unico punto da cui l'interfaccia parla con backend e Keycloak.
/// Gli errori non si catturano qui: arrivano alle pagine come ErroreApi.
/// È un ChangeNotifier: quando cambia uno stato condiviso (login, carrello, profilo) avvisa le pagine.
class Model extends ChangeNotifier {
  static Model sharedInstance = Model._();

  RestManager _restManager = RestManager();
  AuthenticationData? _authenticationData;

  Timer? _timerRefresh;
  List<String> _ruoli = [];
  String? _nomeUtente;
  String? _ultimoErroreLogin;

  Carrello? _carrello;
  Cliente? _profilo;


  Model._() {
    _restManager.sessioneScaduta = _terminaSessione;
  }


  // ================================== STATO ==================================

  bool get loggato => _authenticationData != null;
  bool get admin => loggato && _ruoli.contains("ADMIN");
  // nel backend ADMIN ha la precedenza: un admin non è anche cliente
  bool get cliente => loggato && !admin && _ruoli.contains("CLIENTE");
  String? get nomeUtente => _nomeUtente;
  String? get ultimoErroreLogin => _ultimoErroreLogin;

  Carrello? get carrello => _carrello;
  int get articoliNelCarrello => _carrello?.numeroArticoli ?? 0;
  Cliente? get profilo => _profilo;

  /// Salva il carrello e avvisa le pagine (si aggiorna anche il numerino sulla tab).
  void _aggiornaCarrello(Carrello carrello) {
    _carrello = carrello;
    notifyListeners();
  }

  /// Salva il profilo e avvisa le pagine.
  void _aggiornaProfilo(Cliente profilo) {
    _profilo = profilo;
    notifyListeners();
  }

  /// Parametri di paginazione di una richiesta.
  Map<String, String> _pagina(int pagina) => {
    "page": pagina.toString(),
    "size": Constants.DIMENSIONE_PAGINA.toString(),
  };


  // ============================= AUTENTICAZIONE =============================

  Future<LogInResult> logIn(String email, String password) async {
    try{
      _ultimoErroreLogin = null;
      Map<String, String> params = Map();
      params["grant_type"] = "password";
      params["client_id"] = Constants.CLIENT_ID;
      params["username"] = email;
      params["password"] = password;
      // controllaStato false: anche con le credenziali sbagliate serve il corpo con "error_description"
      String result = await _restManager.makePostRequest(Constants.ADDRESS_AUTHENTICATION_SERVER, Constants.REQUEST_LOGIN, params, type: TypeHeader.urlencoded, controllaStato: false);
      _authenticationData = AuthenticationData.fromJson(jsonDecode(result));
      if ( _authenticationData!.hasError() ) {
        String? errore = _authenticationData!.error;
        _authenticationData = null;
        _ultimoErroreLogin = errore;
        if ( errore == "Invalid user credentials" ) {
          return LogInResult.error_wrong_credentials;
        }
        else if ( errore == "Account is not fully set up" ) {
          return LogInResult.error_not_fully_setupped;
        }
        else {
          return LogInResult.error_unknown;
        }
      }
      _restManager.token = _authenticationData!.accessToken;
      _leggiDatiDalToken(_authenticationData!.accessToken!);
      _timerRefresh?.cancel();
      _timerRefresh = Timer.periodic(Duration(seconds: (_authenticationData!.expiresIn! - 50)), (Timer t) {
        _refreshToken();
      });
      notifyListeners();
      if (cliente) {
        _precaricaCarrello();
      }
      return LogInResult.logged;
    }
    catch (e) {
      _authenticationData = null;
      _ultimoErroreLogin = e.toString();
      return LogInResult.error_unknown;
    }
  }

  Future<bool> _refreshToken() async {
    try {
      Map<String, String> params = Map();
      params["grant_type"] = "refresh_token";
      params["client_id"] = Constants.CLIENT_ID;
      params["refresh_token"] = _authenticationData!.refreshToken!;
      String result = await _restManager.makePostRequest(Constants.ADDRESS_AUTHENTICATION_SERVER, Constants.REQUEST_LOGIN, params, type: TypeHeader.urlencoded, controllaStato: false);
      AuthenticationData nuovi = AuthenticationData.fromJson(jsonDecode(result));
      if ( nuovi.hasError() ) {
        // sessione scaduta (es. inattività): si esce invece di restare con un token non valido
        _terminaSessione();
        return false;
      }
      _authenticationData = nuovi;
      _restManager.token = _authenticationData!.accessToken;
      return true;
    }
    catch (e) {
      return false;
    }
  }

  Future<bool> logOut() async {
    try{
      String? refreshToken = _authenticationData?.refreshToken;
      _terminaSessione();
      if (refreshToken != null) {
        Map<String, String> params = Map();
        params["client_id"] = Constants.CLIENT_ID;
        params["refresh_token"] = refreshToken;
        await _restManager.makePostRequest(Constants.ADDRESS_AUTHENTICATION_SERVER, Constants.REQUEST_LOGOUT, params, type: TypeHeader.urlencoded, controllaStato: false);
      }
      return true;
    }
    catch (e) {
      return false;
    }
  }

  /// Azzera lo stato della sessione (timer, token, ruoli, carrello, profilo) e avvisa le pagine.
  void _terminaSessione() {
    _timerRefresh?.cancel();
    _timerRefresh = null;
    _restManager.token = null;
    _authenticationData = null;
    _ruoli = [];
    _nomeUtente = null;
    _carrello = null;
    _profilo = null;
    notifyListeners();
  }

  /// Legge ruoli e nome dal payload del JWT ("intestazione.payload.firma", in Base64).
  void _leggiDatiDalToken(String token) {
    String payload = utf8.decode(base64Url.decode(base64Url.normalize(token.split(".")[1])));
    Map<String, dynamic> dati = jsonDecode(payload);
    dynamic realmAccess = dati["realm_access"];
    _ruoli = realmAccess == null ? [] : List<String>.from(realmAccess["roles"]);
    _nomeUtente = dati["given_name"] ?? dati["preferred_username"];
  }

  /// Dopo il login carica il carrello (per il numerino sulla tab) senza disturbare se fallisce.
  Future<void> _precaricaCarrello() async {
    try {
      await caricaCarrello();
    } catch (e) {
      // verrà caricato aprendo la pagina del carrello
    }
  }


  // ========================== CATALOGO E RECENSIONI ==========================

  /// GET /prodotti?nome=...&categoria=...&brand=...&page=...&size=...   (pubblico)
  Future<Pagina<Prodotto>> cercaProdotti(String nome, String? categoria, String brand, int pagina) async {
    Map<String, String> params = {"page":pagina.toString(), "size":Constants.DIMENSIONE_PAGINA.toString()};
    if(nome.trim().isNotEmpty) {
      params["nome"] = nome.trim();
    }
    if(categoria != null) {
      String testo = categoria.trim();
      if(testo.isNotEmpty)
        params["categoria"] = testo;
    }

      String value = brand.trim();
      if(value.isNotEmpty)
        params["brand"] = value;


    String risposta = await _restManager.makeGetRequest(Constants.ADDRESS_STORE_SERVER, Constants.REQUEST_PRODOTTI, params);
    return Pagina.fromJson(jsonDecode(risposta), Prodotto.fromJson);
  }

  /// GET /prodotti/{codice}   (pubblico) → ProdottoDTO aggiornato; 404 se non è più in catalogo.
  Future<Prodotto> getProdotto(int codiceProdotto) async {
    String risposta = await _restManager.makeGetRequest(Constants.ADDRESS_STORE_SERVER, "${Constants.REQUEST_PRODOTTI}/$codiceProdotto");
    return Prodotto.fromJson(jsonDecode(risposta));
  }

  /// GET /prodotti/{codice}/recensioni   (pubblico) → pagina di RecensioneDTO, dalla più recente.
  Future<Pagina<Recensione>> getRecensioni(int codiceProdotto, int pagina) async {
    String risposta = await _restManager.makeGetRequest(Constants.ADDRESS_STORE_SERVER, "${Constants.REQUEST_PRODOTTI}/$codiceProdotto/recensioni", _pagina(pagina));
    return Pagina.fromJson(jsonDecode(risposta), Recensione.fromJson);
  }

  /// POST /prodotti/{codice}/recensioni   Body: {"voto": 1..5, "testo": "..."} → RecensioneDTO creata.
  /// 409 se il cliente l'ha già recensito o non l'ha mai acquistato.
  Future<Recensione> scriviRecensione(int codiceProdotto, int voto, String testo) async {
    // TODO
    throw UnimplementedError("TODO: scriviRecensione");
  }

  /// GET /recensioni/mie → pagina delle recensioni del cliente, dalla più recente.
  Future<Pagina<Recensione>> getRecensioniMie(int pagina) async {
    String risposta = await _restManager.makeGetRequest(Constants.ADDRESS_STORE_SERVER, Constants.REQUEST_RECENSIONI_MIE, _pagina(pagina));
    return Pagina.fromJson(jsonDecode(risposta), Recensione.fromJson);
  }

  /// PUT /recensioni/{id}   Body: {"voto": 1..5, "testo": "..."} → RecensioneDTO aggiornata.
  Future<Recensione> modificaRecensione(int idRecensione, int voto, String testo) async {
    // TODO
    throw UnimplementedError("TODO: modificaRecensione");
  }

  /// DELETE /recensioni/{id} → 204.
  Future<void> eliminaRecensione(int idRecensione) async {
    await _restManager.makeDeleteRequest(Constants.ADDRESS_STORE_SERVER, "${Constants.REQUEST_RECENSIONI}/$idRecensione");
  }

  /// DELETE /admin/recensioni/{id} → 204. Moderazione: l'admin può eliminare qualsiasi recensione.
  Future<void> eliminaRecensioneAdmin(int idRecensione) async {
    await _restManager.makeDeleteRequest(Constants.ADDRESS_STORE_SERVER, "${Constants.REQUEST_ADMIN_RECENSIONI}/$idRecensione");
  }


  // ============================ CARRELLO E ORDINI ============================

  /// GET /carrello → CarrelloDTO
  Future<Carrello> caricaCarrello() async {
    return _carrelloDa(_restManager.makeGetRequest(Constants.ADDRESS_STORE_SERVER, Constants.REQUEST_CARRELLO));
  }

  /// POST /carrello/prodotti   Body: {"codiceProdotto": ..., "quantita": 1..99} → CarrelloDTO.
  /// Se il prodotto c'era già le quantità si sommano; 409 se la giacenza non basta.
  Future<Carrello> aggiungiAlCarrello(int codiceProdotto, int quantita) async {
    Map<String, int> body = {
      "codiceProdotto":codiceProdotto,
      "quantita":quantita
    };
    return _carrelloDa(_restManager.makePostRequest(Constants.ADDRESS_STORE_SERVER, Constants.REQUEST_CARRELLO_PRODOTTI, body));
  }

  /// PATCH /carrello/prodotti/{codice}?quantita=... → CarrelloDTO (quantità 0 = rimuovi).
  Future<Carrello> aggiornaQuantita(int codiceProdotto, int quantita) async {
    Map<String, String> params = {
      "quantita":quantita.toString()

    };
    return _carrelloDa(_restManager.makePatchRequest(Constants.ADDRESS_STORE_SERVER, "${Constants.REQUEST_CARRELLO_PRODOTTI}/$codiceProdotto", params));
  }

  /// DELETE /carrello/prodotti/{codice} → CarrelloDTO
  Future<Carrello> rimuoviDalCarrello(int codiceProdotto) async {
    return _carrelloDa(_restManager.makeDeleteRequest(Constants.ADDRESS_STORE_SERVER, "${Constants.REQUEST_CARRELLO_PRODOTTI}/$codiceProdotto"));
  }

  /// DELETE /carrello → CarrelloDTO vuoto.
  Future<Carrello> svuotaCarrello() =>
      _carrelloDa(_restManager.makeDeleteRequest(Constants.ADDRESS_STORE_SERVER, Constants.REQUEST_CARRELLO));

  /// POST /ordini   Body: carrelloVisto.toCheckoutRequest() → OrdineDTO.
  /// 409 se nel frattempo il carrello è cambiato, se il saldo non basta o manca l'indirizzo.
  Future<Ordine> effettuaCheckout(Carrello carrelloVisto) async {
    String risposta = await _restManager.makePostRequest(Constants.ADDRESS_STORE_SERVER, Constants.REQUEST_ORDINI, carrelloVisto.toCheckoutRequest());
    Ordine o = new Ordine.fromJson(jsonDecode(risposta));
    try {
      await caricaCarrello();
      await caricaProfilo();
    } catch(_) {/* l'ordine è già fatto: la ricarica non è essenziale */}
    return o;
  }

  /// GET /ordini → pagina di OrdineSintesiDTO (id, data, totale), dal più recente.
  Future<Pagina<Ordine>> getOrdini(int pagina) async {
    String risposta = await _restManager.makeGetRequest(Constants.ADDRESS_STORE_SERVER, Constants.REQUEST_ORDINI, _pagina(pagina));
    return Pagina.fromJson(jsonDecode(risposta), Ordine.fromJson);
  }

  /// GET /ordini/{id} → OrdineDTO completo; 404 se l'ordine è di un altro cliente.
  Future<Ordine> getOrdine(int idOrdine) async {
    String risposta = await _restManager.makeGetRequest(Constants.ADDRESS_STORE_SERVER, "${Constants.REQUEST_ORDINI}/$idOrdine");
    return Ordine.fromJson(jsonDecode(risposta));
  }


  // ============================= CARRELLO OSPITE =============================
  // Chi non ha fatto login riempie un carrello che vive solo qui, in memoria. Al login viene unito
  // a quello del backend con POST /carrello/merge: il backend somma le quantità alle righe che ha già,
  // salta i prodotti non più in catalogo e non supera la giacenza.
  //
  // Idea: il carrello ospite è un normale Carrello salvato in _carrello (idCarrello 0, righe costruite
  // qui), così CarrelloPagina e il numerino sulla tab funzionano senza cambiare niente.
  // Il login con il form non ricarica la pagina del browser, quindi il carrello arriva intatto al merge.
  //
  // Da fare:
  //  1. i tre metodi qui sotto. Totale, subtotali e numero di articoli vanno ricalcolati a ogni modifica;
  //     "disponibile" di una riga si può prendere dal prodotto.
  //  2. in caricaCarrello, aggiungiAlCarrello, aggiornaQuantita, rimuoviDalCarrello e svuotaCarrello:
  //     se !loggato si lavora sul carrello in memoria invece di chiamare il backend.
  //  3. in logIn: per un cliente, _unisciCarrelloOspite() al posto di _precaricaCarrello().
  //     Se il merge fallisce il login non deve fallire (al massimo il carrello ospite si perde).
  //  4. Constants.CARRELLO_OSPITE = true.

  /// Aggiunge un prodotto al carrello ospite, o ne somma la quantità se c'è già.
  /// I dati del prodotto (nome, prezzo, immagine) si prendono con getProdotto.
  Future<Carrello> _aggiungiOspite(int codiceProdotto, int quantita) async {
    // TODO
    throw UnimplementedError("TODO: _aggiungiOspite");
  }

  /// Imposta la quantità di una riga del carrello ospite (0 = la toglie).
  Carrello _aggiornaOspite(int codiceProdotto, int quantita) {
    // TODO
    throw UnimplementedError("TODO: _aggiornaOspite");
  }

  /// POST /carrello/merge   Body: {"righe": [{"codiceProdotto": ..., "quantita": ...}]} (max 50 righe)
  /// → CarrelloDTO, che da quel momento è il carrello del cliente.
  Future<Carrello> _unisciCarrelloOspite() async {
    // TODO
    throw UnimplementedError("TODO: _unisciCarrelloOspite");
  }


  // ================================== ASTE ==================================

  /// GET /aste (in corso, filtrabili per nome e categoria) oppure GET /aste/programmate → pagina di AstaDTO.
  Future<Pagina<Asta>> getAste(bool programmate, int pagina, {String? nome, String? categoria}) async {
    Map<String, String> params = _pagina(pagina);
    if (!programmate) {
      if (nome != null && nome.trim().isNotEmpty) {
        params["nome"] = nome.trim();
      }
      if (categoria != null) {
        params["categoria"] = categoria;
      }
    }
    String percorso = programmate ? Constants.REQUEST_ASTE_PROGRAMMATE : Constants.REQUEST_ASTE;
    String risposta = await _restManager.makeGetRequest(Constants.ADDRESS_STORE_SERVER, percorso, params);
    return Pagina.fromJson(jsonDecode(risposta), Asta.fromJson);
  }

  /// GET /aste/{id} → AstaDTO con prezzo corrente e stato aggiornati.
  Future<Asta> getAsta(int idAsta) async {
    String risposta = await _restManager.makeGetRequest(Constants.ADDRESS_STORE_SERVER, "${Constants.REQUEST_ASTE}/$idAsta");
    return Asta.fromJson(jsonDecode(risposta));
  }

  /// GET /aste/{id}/offerte → pagina di OffertaAstaDTO, dalla più alta.
  Future<Pagina<OffertaAsta>> getOfferte(int idAsta, int pagina) async {
    String risposta = await _restManager.makeGetRequest(Constants.ADDRESS_STORE_SERVER, "${Constants.REQUEST_ASTE}/$idAsta/offerte", _pagina(pagina));
    return Pagina.fromJson(jsonDecode(risposta), OffertaAsta.fromJson);
  }

  /// GET /aste/mie-offerte → pagina delle offerte del cliente, dalla più recente.
  Future<Pagina<OffertaAsta>> getMieOfferte(int pagina) async {
    String risposta = await _restManager.makeGetRequest(Constants.ADDRESS_STORE_SERVER, Constants.REQUEST_ASTE_MIE_OFFERTE, _pagina(pagina));
    return Pagina.fromJson(jsonDecode(risposta), OffertaAsta.fromJson);
  }

  /// POST /aste/{id}/offerte   Body: {"importo": ...} → AstaDTO aggiornata.
  /// 409 se l'offerta è troppo bassa, l'asta non è in corso, manca l'indirizzo o il saldo non basta.
  Future<Asta> faiOfferta(int idAsta, double importo) async {
    // TODO
    throw UnimplementedError("TODO: faiOfferta");
  }


  // ================================= PROFILO =================================

  /// GET /utenti/me → ClienteDTO. La prima chiamata di un utente appena registrato lo crea nel database.
  Future<Cliente> caricaProfilo() async {
    return _profiloDa(_restManager.makeGetRequest(Constants.ADDRESS_STORE_SERVER, Constants.REQUEST_PROFILO));
  }

  /// PUT /utenti/me   Body: {"indirizzo": "..."} → ClienteDTO
  Future<Cliente> aggiornaIndirizzo(String indirizzo) async {
    Map<String, String> body = {
      "indirizzo" : indirizzo
    };
    return _profiloDa(_restManager.makePutRequest(Constants.ADDRESS_STORE_SERVER, Constants.REQUEST_PROFILO, body));
  }

  /// POST /utenti/me/ricarica   Body: {"importo": ...} → ClienteDTO
  Future<Cliente> ricaricaSaldo(double importo) async {
    Map<String, double> body = {
      "importo":importo
    };
    return _profiloDa(_restManager.makePostRequest(Constants.ADDRESS_STORE_SERVER, Constants.REQUEST_RICARICA, body));
  }

  /// DELETE /utenti/me → 204. Il token resta valido fino alla scadenza: subito dopo va fatto il logout.
  Future<void> disattivaAccount() async {
    await _restManager.makeDeleteRequest(Constants.ADDRESS_STORE_SERVER, Constants.REQUEST_PROFILO);
  }


  // ================================== ADMIN ==================================

  /// GET /admin/prodotti → pagina di ProdottoAdminDTO (anche i prodotti nascosti).
  Future<Pagina<ProdottoAdmin>> getProdottiAdmin(int pagina) async {
    String risposta = await _restManager.makeGetRequest(Constants.ADDRESS_STORE_SERVER, Constants.REQUEST_ADMIN_PRODOTTI, _pagina(pagina));
    return Pagina.fromJson(jsonDecode(risposta), ProdottoAdmin.fromJson);
  }

  /// POST /admin/prodotti   Body: la Map del form (campi di CreaProdottoRequest) → ProdottoAdminDTO creato.
  Future<ProdottoAdmin> creaProdotto(Map<String, dynamic> dati) async {
    // TODO
    throw UnimplementedError("TODO: creaProdotto");
  }

  /// PUT /admin/prodotti/{codice}   Body: la Map del form (campi di AggiornaProdottoRequest, senza quantità)
  /// → ProdottoAdminDTO aggiornato.
  Future<ProdottoAdmin> aggiornaProdotto(int codiceProdotto, Map<String, dynamic> dati) async {
    // TODO
    throw UnimplementedError("TODO: aggiornaProdotto");
  }

  /// PATCH /admin/prodotti/{codice}/giacenza?quantita=... → ProdottoAdminDTO aggiornato.
  Future<ProdottoAdmin> impostaGiacenza(int codiceProdotto, int quantita) async {
    String risposta = await _restManager.makePatchRequest(Constants.ADDRESS_STORE_SERVER, "${Constants.REQUEST_ADMIN_PRODOTTI}/$codiceProdotto/giacenza", {"quantita": quantita.toString()});
    return ProdottoAdmin.fromJson(jsonDecode(risposta));
  }

  /// PATCH /admin/prodotti/{codice}/visibilita?visibile=... → ProdottoAdminDTO aggiornato.
  /// Nascondere un prodotto lo toglie dal catalogo (soft delete).
  Future<ProdottoAdmin> impostaVisibilita(int codiceProdotto, bool visibile) async {
    String risposta = await _restManager.makePatchRequest(Constants.ADDRESS_STORE_SERVER, "${Constants.REQUEST_ADMIN_PRODOTTI}/$codiceProdotto/visibilita", {"visibile": visibile.toString()});
    return ProdottoAdmin.fromJson(jsonDecode(risposta));
  }

  /// POST /admin/aste   Body: la Map del form (campi di CreaAstaRequest) → AstaDTO creata.
  /// 409 se il prodotto non è nascosto con giacenza o ha già un'asta; 400 se le date non sono nel futuro.
  Future<Asta> creaAsta(Map<String, dynamic> dati) async {
    // TODO
    throw UnimplementedError("TODO: creaAsta");
  }

  /// DELETE /admin/aste/{id} → 204; 409 se l'asta è già conclusa.
  Future<void> annullaAsta(int idAsta) async {
    await _restManager.makeDeleteRequest(Constants.ADDRESS_STORE_SERVER, "${Constants.REQUEST_ADMIN_ASTE}/$idAsta");
  }

  /// GET /admin/ordini?dal=yyyy-MM-dd&al=yyyy-MM-dd (estremi inclusi) → pagina di OrdineSintesiDTO.
  Future<Pagina<Ordine>> getOrdiniAdmin(DateTime dal, DateTime al, int pagina) async {
    // TODO
    throw UnimplementedError("TODO: getOrdiniAdmin");
  }

  /// GET /admin/ordini/{id} → OrdineDTO completo.
  Future<Ordine> getOrdineAdmin(int idOrdine) async {
    String risposta = await _restManager.makeGetRequest(Constants.ADDRESS_STORE_SERVER, "${Constants.REQUEST_ADMIN_ORDINI}/$idOrdine");
    return Ordine.fromJson(jsonDecode(risposta));
  }

  /// GET /admin/utenti → pagina di UtenteDTO, per cognome.
  Future<Pagina<Utente>> getUtenti(int pagina) async {
    String risposta = await _restManager.makeGetRequest(Constants.ADDRESS_STORE_SERVER, Constants.REQUEST_ADMIN_UTENTI, _pagina(pagina));
    return Pagina.fromJson(jsonDecode(risposta), Utente.fromJson);
  }

  /// GET /admin/utenti/{id} → UtenteDTO
  Future<Utente> getUtente(int idUtente) async {
    String risposta = await _restManager.makeGetRequest(Constants.ADDRESS_STORE_SERVER, "${Constants.REQUEST_ADMIN_UTENTI}/$idUtente");
    return Utente.fromJson(jsonDecode(risposta));
  }


  /// Converte una risposta CarrelloDTO, la salva nel Model e la restituisce.
  Future<Carrello> _carrelloDa(Future<String> richiesta) async {
    Carrello carrello = Carrello.fromJson(jsonDecode(await richiesta));
    _aggiornaCarrello(carrello);
    return carrello;
  }

  /// Converte una risposta ClienteDTO, la salva nel Model e la restituisce.
  Future<Cliente> _profiloDa(Future<String> richiesta) async {
    Cliente cliente = new Cliente.fromJson(jsonDecode(await richiesta));
    _aggiornaProfilo(cliente);
    return cliente;
  }


}
