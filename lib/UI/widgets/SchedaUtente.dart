import 'package:flutter/material.dart';
import 'package:psw_frontend/UI/widgets/Avvisi.dart';
import 'package:psw_frontend/model/Model.dart';
import 'package:psw_frontend/model/objects/Cliente.dart';
import 'package:psw_frontend/model/support/Formati.dart';

/// Scheda di un utente (finestra). Usata dall'area admin: tab Utenti, ordini, offerte delle aste.
class SchedaUtente extends StatelessWidget {
  final Utente utente;

  SchedaUtente({required this.utente});

  @override
  Widget build(BuildContext context) {
    Widget voce(String etichetta, String valore) => Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              etichetta,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          Expanded(child: Text(valore)),
        ],
      ),
    );
    DateTime? registrazione = utente.dataRegistrazione;
    return AlertDialog(
      title: Text(
        utente.nomeCompleto.isEmpty
            ? "Utente ${utente.idUtente}"
            : utente.nomeCompleto,
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            voce("Id", "${utente.idUtente}"),
            voce("Email", utente.email ?? "—"),
            voce(
              "Ruolo",
              utente.ruolo == "ADMIN" ? "Amministratore" : "Cliente",
            ),
            voce(
              "Registrato il",
              registrazione == null ? "—" : formattaDataOra(registrazione),
            ),
            voce("Stato", utente.attivo ? "Attivo" : "Disattivato"),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text("Chiudi"),
        ),
      ],
    );
  }
}

/// Legge l'utente dal backend (GET /admin/utenti/{id}) e ne apre la scheda. Solo per l'admin.
Future<void> mostraSchedaUtente(BuildContext context, int idUtente) async {
  try {
    Utente utente = await Model.sharedInstance.getUtente(idUtente);
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (context) => SchedaUtente(utente: utente),
    );
  } catch (e) {
    if (context.mounted) mostraErrore(context, e);
  }
}

/// Testo con l'aspetto di un link (colore primario, sottolineato) che apre la scheda di un utente.
class LinkUtente extends StatelessWidget {
  final String testo;
  final int idUtente;

  LinkUtente({required this.testo, required this.idUtente});

  @override
  Widget build(BuildContext context) {
    ThemeData tema = Theme.of(context);
    return InkWell(
      onTap: () => mostraSchedaUtente(context, idUtente),
      borderRadius: BorderRadius.circular(4),
      child: Text(
        testo,
        style: tema.textTheme.bodyMedium?.copyWith(
          color: tema.colorScheme.primary,
          decoration: TextDecoration.underline,
          decorationColor: tema.colorScheme.primary,
        ),
      ),
    );
  }
}
