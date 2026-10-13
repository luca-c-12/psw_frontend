class Constants {
  // app info
  static final String APP_VERSION = "1.0.0";
  static final String APP_NAME = "PSW Store";

  // addresses
  static final String ADDRESS_STORE_SERVER = "localhost:8080";
  static final String ADDRESS_AUTHENTICATION_SERVER = "localhost:8180";

  // authentication (psw-frontend è un client pubblico: niente client secret)
  static final String REALM = "psw";
  static final String CLIENT_ID = "psw-frontend";
  static final String REQUEST_LOGIN = "/realms/" + REALM + "/protocol/openid-connect/token";
  static final String REQUEST_LOGOUT = "/realms/" + REALM + "/protocol/openid-connect/logout";

  // requests
  static final String REQUEST_PRODOTTI = "/prodotti";                    // /{codice}, /{codice}/recensioni
  static final String REQUEST_RECENSIONI = "/recensioni";                // /{id}
  static final String REQUEST_RECENSIONI_MIE = "/recensioni/mie";
  static final String REQUEST_CARRELLO = "/carrello";
  static final String REQUEST_CARRELLO_PRODOTTI = "/carrello/prodotti";  // /{codice}
  static final String REQUEST_CARRELLO_MERGE = "/carrello/merge";
  static final String REQUEST_ORDINI = "/ordini";                        // /{id}
  static final String REQUEST_ASTE = "/aste";                            // /{idAsta}, /{idAsta}/offerte
  static final String REQUEST_ASTE_PROGRAMMATE = "/aste/programmate";
  static final String REQUEST_ASTE_MIE_OFFERTE = "/aste/mie-offerte";
  static final String REQUEST_PROFILO = "/utenti/me";
  static final String REQUEST_RICARICA = "/utenti/me/ricarica";
  static final String REQUEST_STATO_PROFILO = "/utenti/me/stato";       // {"attivo": true/false}, non riattiva
  static final String REQUEST_RIATTIVA = "/utenti/me/riattiva";
  static final String REQUEST_ADMIN_PRODOTTI = "/admin/prodotti";        // /{codice}, /{codice}/giacenza, /{codice}/visibilita
  static final String REQUEST_ADMIN_ASTE = "/admin/aste";                // /{idAsta}
  static final String REQUEST_ADMIN_ORDINI = "/admin/ordini";            // /{id}
  static final String REQUEST_ADMIN_RECENSIONI = "/admin/recensioni";    // /{id}
  static final String REQUEST_ADMIN_UTENTI = "/admin/utenti";            // /{id}

  static final int DIMENSIONE_PAGINA = 12;

  /// Mostra tab Carrello e "Aggiungi al carrello" anche a chi non ha fatto login.
  static const bool CARRELLO_OSPITE = true;

  static const String CHIAVE_CARRELLO_OSPITE = "carrello_ospite";

  // links
  static final String LINK_REGISTRAZIONE = "http://" + ADDRESS_AUTHENTICATION_SERVER + "/realms/" + REALM
      + "/protocol/openid-connect/registrations?client_id=" + CLIENT_ID
      + "&response_type=code&scope=openid&redirect_uri=http://localhost:4200/"
      // il client richiede PKCE anche qui: il code_challenge è fittizio perché il codice restituito non si usa
      + "&code_challenge_method=S256&code_challenge=registrazionePswFrontendCodiceFittizio0123456";
  static final String LINK_ACCOUNT = "http://" + ADDRESS_AUTHENTICATION_SERVER + "/realms/" + REALM + "/account";

  // footer (testi segnaposto da sostituire)
  static final String FOOTER_PROGETTO = "Progetto d'esame di Piattaforme Web · Università della Calabria";
  static final String FOOTER_AUTORE = "Nome Cognome";
  static final String FOOTER_EMAIL = "nome.cognome@studenti.unical.it";
  static final String LINK_GITHUB = "https://github.com/utente/psw";


}
