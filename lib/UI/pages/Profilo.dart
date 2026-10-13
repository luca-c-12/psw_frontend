import 'package:flutter/material.dart';
import 'package:psw_frontend/UI/pages/Storico.dart';
import 'package:psw_frontend/UI/widgets/Avvisi.dart';
import 'package:psw_frontend/model/Model.dart';
import 'package:psw_frontend/model/objects/Cliente.dart';
import 'package:psw_frontend/model/support/Formati.dart';

/// Profilo del cliente. Come il carrello è uno stato condiviso nel Model:
/// per esempio il checkout cambia il saldo e questa pagina si aggiorna da sola.
class Profilo extends StatefulWidget {
  Profilo() : super();

  @override
  _ProfiloState createState() => _ProfiloState();
}

class _ProfiloState extends State<Profilo> with AzioniPagina<Profilo> {
  TextEditingController _indirizzo = TextEditingController();
  TextEditingController _importo = TextEditingController();
  bool _caricamento = false;
  bool _invio = false;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  @override
  void dispose() {
    _indirizzo.dispose();
    _importo.dispose();
    super.dispose();
  }

  /// Scarica il profilo dal backend.
  Future<void> _carica() => esegui(() async {
    Cliente c = await Model.sharedInstance.caricaProfilo();
    if (mounted) _indirizzo.text = c.indirizzo ?? "";
  }, imposta: (v) => _caricamento = v);

  /// Bottone "Salva" dell'indirizzo.
  Future<void> _salvaIndirizzo() async {
    String indirizzo = _indirizzo.text.trim();
    if (indirizzo.isEmpty) {
      mostraErrore(context, "Scrivi un indirizzo di spedizione.");
      return;
    }
    await esegui(
      () => Model.sharedInstance.aggiornaIndirizzo(indirizzo),
      imposta: (v) => _invio = v,
      messaggio: "Indirizzo salvato correttamente.",
    );
  }

  /// Bottone "Ricarica".
  Future<void> _ricarica() async {
    double? importo = leggiImporto(_importo.text);
    if (importo == null || importo <= 0) {
      mostraErrore(context, "Inserisci un importo valido.");
      return;
    }
    await esegui(
      () async {
        await Model.sharedInstance.ricaricaSaldo(importo);
        if (mounted) _importo.clear();
      },
      imposta: (v) => _invio = v,
      messaggio: "Saldo ricaricato correttamente.",
    );
  }

  /// Bottone "Disattiva account": dopo la conferma disattiva l'account ed esce.
  Future<void> _disattiva() async {
    if (!(await chiediConferma(
          context,
          "Procedere alla disattivazione dell'account?",
        )) ||
        !mounted)
      return;
    await esegui(() async {
      await Model.sharedInstance.disattivaAccount();
      if (mounted)
        mostraMessaggio(context, "Account disattivato con successo.");
      await Model.sharedInstance.logOut();
    }, imposta: (v) => _invio = v);
  }

  void _apriStorico(int tab) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => Storico(tabIniziale: tab)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Model.sharedInstance,
      builder: (context, _) {
        Cliente? profilo = Model.sharedInstance.profilo;
        if (profilo == null) {
          return Center(
            child: _caricamento
                ? CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Profilo non ancora caricato."),
                      TextButton(onPressed: _carica, child: Text("Riprova")),
                    ],
                  ),
          );
        }
        ThemeData tema = Theme.of(context);
        return SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // dati dell'utente
                  Card(
                    child: ListTile(
                      contentPadding: EdgeInsets.all(16),
                      leading: CircleAvatar(
                        radius: 26,
                        child: Text(
                          profilo.nomeCompleto.isEmpty
                              ? "?"
                              : profilo.nomeCompleto
                                    .substring(0, 1)
                                    .toUpperCase(),
                          style: tema.textTheme.titleLarge,
                        ),
                      ),
                      title: Text(
                        profilo.nomeCompleto.isEmpty
                            ? "Cliente"
                            : profilo.nomeCompleto,
                        style: tema.textTheme.titleLarge,
                      ),
                      subtitle: Text(profilo.email ?? ""),
                    ),
                  ),
                  SizedBox(height: 12),
                  // storico
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.receipt_long_outlined),
                          title: Text("I miei ordini"),
                          trailing: Icon(Icons.chevron_right),
                          onTap: () => _apriStorico(0),
                        ),
                        Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.rate_review_outlined),
                          title: Text("Le mie recensioni"),
                          trailing: Icon(Icons.chevron_right),
                          onTap: () => _apriStorico(1),
                        ),
                        Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.gavel_rounded),
                          title: Text("Le mie offerte"),
                          trailing: Icon(Icons.chevron_right),
                          onTap: () => _apriStorico(2),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  // saldo e ricarica
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Saldo disponibile",
                            style: tema.textTheme.labelLarge,
                          ),
                          Text(
                            formattaEuro(profilo.saldo),
                            style: tema.textTheme.displaySmall?.copyWith(
                              color: tema.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text("Ricarica", style: tema.textTheme.titleMedium),
                          SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [10.0, 50.0, 100.0]
                                .map(
                                  (valore) => ActionChip(
                                    label: Text("+ ${formattaEuro(valore)}"),
                                    onPressed: () {
                                      _importo.text = valore.toStringAsFixed(0);
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _importo,
                                  keyboardType: TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: "Importo (€)",
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              FilledButton.icon(
                                onPressed: _invio ? null : _ricarica,
                                icon: Icon(
                                  Icons.account_balance_wallet_outlined,
                                ),
                                label: Text("Ricarica"),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  // indirizzo di spedizione
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Indirizzo di spedizione",
                            style: tema.textTheme.titleMedium,
                          ),
                          Text(
                            "Serve per completare gli ordini e per fare offerte alle aste.",
                            style: tema.textTheme.bodySmall,
                          ),
                          SizedBox(height: 12),
                          TextField(
                            controller: _indirizzo,
                            maxLines: 2,
                            maxLength: 255,
                            decoration: InputDecoration(
                              labelText: "Via, numero civico, CAP, città",
                              border: OutlineInputBorder(),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton(
                              onPressed: _invio ? null : _salvaIndirizzo,
                              child: Text("Salva"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  // disattivazione dell'account
                  Card(
                    color: tema.colorScheme.errorContainer,
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      title: Text(
                        "Disattiva account",
                        style: TextStyle(
                          color: tema.colorScheme.onErrorContainer,
                        ),
                      ),
                      subtitle: Text(
                        "Gli ordini restano registrati, ma non potrai più accedere.",
                        style: TextStyle(
                          color: tema.colorScheme.onErrorContainer,
                        ),
                      ),
                      trailing: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: tema.colorScheme.error,
                        ),
                        onPressed: _invio ? null : _disattiva,
                        child: Text("Disattiva"),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
