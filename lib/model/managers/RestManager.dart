import 'dart:convert';
import 'package:http/http.dart';
import 'package:psw_frontend/model/support/Constants.dart';


enum TypeHeader {
  json,
  urlencoded
}


/// Errore restituito dal backend (o server non raggiungibile).
/// [messaggio] è il "detail" del ProblemDetail di Spring: basta mostrarlo con mostraErrore(context, e).
class ErroreApi implements Exception {
  final int stato;        // codice HTTP (0 = server non raggiungibile)
  final String messaggio;


  ErroreApi(this.stato, this.messaggio);

  factory ErroreApi.daRisposta(int stato, String corpo) {
    String? dettaglio;
    try {
      dynamic dati = json.decode(corpo);
      if (dati is Map) {
        // "detail" = ProblemDetail di Spring, "error_description" = errori di Keycloak
        dynamic testo = dati['detail'] ?? dati['error_description'];
        if (testo != null) {
          dettaglio = testo.toString();
        }
      }
    } catch (_) {
      // corpo vuoto o non JSON
    }
    if (dettaglio == "Invalid request content.") {
      // messaggio standard di Spring quando falliscono le validazioni (@Valid)
      return ErroreApi(stato, "Dati non validi: controlla i campi.");
    }
    if (dettaglio != null && dettaglio.isNotEmpty) {
      return ErroreApi(stato, dettaglio);
    }
    if (stato == 400) {
      return ErroreApi(stato, "Dati non validi.");
    }
    if (stato == 401) {
      return ErroreApi(stato, "Devi effettuare l'accesso.");
    }
    if (stato == 403) {
      return ErroreApi(stato, "Operazione non consentita.");
    }
    if (stato == 404) {
      return ErroreApi(stato, "Risorsa non trovata.");
    }
    return ErroreApi(stato, "Errore $stato.");
  }

  @override
  String toString() => messaggio;
}


class RestManager {
  String? token;
  /// Chiamata quando il backend risponde 401 a una richiesta con token: il Model chiude la sessione.
  void Function()? sessioneScaduta;


  Future<String> _makeRequest(String serverAddress, String servicePath, String method, TypeHeader type, {Map<String, String>? value, dynamic body, bool controllaStato = true}) async {
    Uri uri = Uri.http(serverAddress, servicePath, value);
    // setting content type
    Map<String, String> headers = {};
    dynamic formattedBody;
    if (body != null) {
      if (type == TypeHeader.json) {
        headers["content-type"] = "application/json;charset=utf-8";
        formattedBody = json.encode(body);
      }
      else {
        // la Map la codifica il pacchetto http (gestisce anche & e = nella password)
        formattedBody = body;
      }
    }
    // setting headers: il token va solo al backend, non a Keycloak
    bool conToken = token != null && serverAddress == Constants.ADDRESS_STORE_SERVER;
    if (conToken) {
      headers["authorization"] = "Bearer $token";
    }
    // making request (nessun nuovo tentativo automatico: ripetere una POST potrebbe duplicare un ordine)
    late Response response;
    try {
      switch (method) {
        case "post":
          response = await post(uri, headers: headers, body: formattedBody);
          break;
        case "put":
          response = await put(uri, headers: headers, body: formattedBody);
          break;
        case "patch":
          response = await patch(uri, headers: headers, body: formattedBody);
          break;
        case "delete":
          response = await delete(uri, headers: headers);
          break;
        default:
          response = await get(uri, headers: headers);
      }
    } on ClientException {
      throw ErroreApi(0, "Impossibile contattare il server ($serverAddress). È avviato?");
    }
    if (conToken && response.statusCode == 401 && sessioneScaduta != null) {
      sessioneScaduta!();
    }
    String corpo = utf8.decode(response.bodyBytes);
    if (controllaStato && response.statusCode >= 400) {
      throw ErroreApi.daRisposta(response.statusCode, corpo);
    }
    return corpo;
  }

  /// [controllaStato] false: restituisce il corpo anche per le risposte di errore (serve al login).
  Future<String> makePostRequest(String serverAddress, String servicePath, dynamic value, {TypeHeader type = TypeHeader.json, bool controllaStato = true}) async {
    return _makeRequest(serverAddress, servicePath, "post", type, body: value, controllaStato: controllaStato);
  }

  Future<String> makeGetRequest(String serverAddress, String servicePath, [Map<String, String>? value, TypeHeader type = TypeHeader.json]) async {
    return _makeRequest(serverAddress, servicePath, "get", type, value: value);
  }

  Future<String> makePutRequest(String serverAddress, String servicePath, dynamic body) async {
    return _makeRequest(serverAddress, servicePath, "put", TypeHeader.json, body: body);
  }

  Future<String> makePatchRequest(String serverAddress, String servicePath, [Map<String, String>? value]) async {
    return _makeRequest(serverAddress, servicePath, "patch", TypeHeader.json, value: value);
  }

  Future<String> makeDeleteRequest(String serverAddress, String servicePath, [Map<String, String>? value, TypeHeader type = TypeHeader.json]) async {
    return _makeRequest(serverAddress, servicePath, "delete", type, value: value);
  }


}
