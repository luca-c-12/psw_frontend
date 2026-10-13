import 'dart:async';

import 'package:flutter/material.dart';
import 'package:psw_frontend/UI/pages/Storico.dart';
import 'package:psw_frontend/UI/widgets/Avvisi.dart';
import 'package:psw_frontend/UI/widgets/Footer.dart';
import 'package:psw_frontend/model/Model.dart';
import 'package:psw_frontend/model/objects/Carrello.dart';
import 'package:psw_frontend/model/support/Formati.dart';
import 'package:psw_frontend/UI/pages/DettaglioProdotto.dart';
import 'package:psw_frontend/UI/pages/LogIn.dart';
import 'package:psw_frontend/UI/widgets/ProductCard.dart';
import 'package:flutter/services.dart';

/// Il carrello (si chiama così per non confondersi con la classe Carrello del modello).
/// Non ne tiene una copia: lo legge dal Model e si ridisegna quando il Model avvisa.
class CarrelloPagina extends StatefulWidget {
  CarrelloPagina() : super();

  @override
  _CarrelloPaginaState createState() => _CarrelloPaginaState();
}

class _CarrelloPaginaState extends State<CarrelloPagina>
    with AzioniPagina<CarrelloPagina> {
  bool _caricamento = false; // true mentre si scarica il carrello
  bool _invio = false; // true mentre è in corso una modifica o il checkout

  @override
  void initState() {
    super.initState();
    _carica();
  }

  /// Scarica il carrello dal backend.
  Future<void> _carica() => esegui(
    () => Model.sharedInstance.caricaCarrello(),
    imposta: (v) => _caricamento = v,
  );

  /// Bottoni "-" e "+" di una riga.
  Future<void> _cambiaQuantita(RigaCarrello riga, int nuovaQuantita) async {
    if (nuovaQuantita < 0) {
      mostraErrore(context, "Quantità non valida.");
      return;
    }
    await esegui(
      () => Model.sharedInstance.aggiornaQuantita(
        riga.codiceProdotto,
        nuovaQuantita,
      ),
      imposta: (v) => _invio = v,
    );
  }

  /// Bottone del cestino di una riga.
  Future<void> _rimuovi(RigaCarrello riga) => esegui(
    () => Model.sharedInstance.rimuoviDalCarrello(riga.codiceProdotto),
    imposta: (v) => _invio = v,
  );

  /// Bottone "Procedi all'ordine".
  Future<void> _checkout() async {
    Carrello? carrelloVisto = Model.sharedInstance.carrello;
    if (carrelloVisto == null) return;

    bool conferma = await chiediConferma(
      context,
      "Vuoi procedere al checkout?",
    );
    if (!(conferma && mounted)) return;
    await esegui(
      () async {
        Ordine ordine = await Model.sharedInstance.effettuaCheckout(
          carrelloVisto,
        );
        if (mounted) {
          mostraMessaggio(
            context,
            "Ordine n. ${ordine.idOrdine} confermato: pagati ${formattaEuro(ordine.totalePagato)}",
          );
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  RiepilogoOrdine(idOrdine: ordine.idOrdine, ordine: ordine),
            ),
          );
        }
      },
      imposta: (v) => _invio = v,
      dopoErrore: _carica,
    );
  }

  /// Bottone "Svuota carrello".
  Future<void> _svuota() async {
    if (!await chiediConferma(
      context,
      "Togliere tutti i prodotti dal carrello?",
    ))
      return;
    if (!mounted) return;
    await esegui(
      () => Model.sharedInstance.svuotaCarrello(),
      imposta: (v) => _invio = v,
    );
  }

  /// Per chi non ha fatto login: porta alla tab "Accedi" (l'ultima). Se il carrello è stato aperto
  /// sopra un'altra pagina (es. "Vai al carrello" dal dettaglio prodotto) le tab non ci sono:
  /// si apre il login sopra il carrello, che dopo l'accesso torna visibile già unito.
  void _vaiAlLogin() {
    TabController? tab = DefaultTabController.maybeOf(context);
    if (tab != null) {
      tab.animateTo(tab.length - 1);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => _PaginaAccesso()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Model.sharedInstance,
      builder: (context, _) {
        Carrello? carrello = Model.sharedInstance.carrello;
        if (carrello == null) {
          return Center(
            child: _caricamento
                ? CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Carrello non ancora caricato."),
                      TextButton(onPressed: _carica, child: Text("Riprova")),
                    ],
                  ),
          );
        }
        if (carrello.righe.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.remove_shopping_cart_outlined,
                  size: 80,
                  color: Theme.of(context).colorScheme.outline,
                ),
                SizedBox(height: 12),
                Text(
                  "Il carrello è vuoto.",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                // l'ultima voce è il footer
                itemCount: carrello.righe.length + 1,
                itemBuilder: (context, index) => index == carrello.righe.length
                    ? Footer()
                    : _riga(carrello.righe[index]),
              ),
            ),
            _riepilogo(carrello),
          ],
        );
      },
    );
  }

  /// Apre la finestra per scrivere la quantità e, se è cambiata, la aggiorna con _cambiaQuantita.
  Future<void> _chiediQuantita(RigaCarrello riga) async {
    int? scelta = await showDialog<int>(
      context: context,
      builder: (context) => _DialogoQuantita(
        nomeProdotto: riga.nomeProdotto,
        quantitaAttuale: riga.quantita,
      ),
    );
    if (!mounted || scelta == null || scelta == riga.quantita) return;
    _cambiaQuantita(riga, scelta);
  }

  Widget _riga(RigaCarrello riga) {
    ThemeData tema = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => DettaglioProdotto(prodotto: riga.prodotto),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ImmagineProdotto(
                    url: riga.prodotto.urlImmagine,
                    altezza: 64,
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(riga.nomeProdotto, style: tema.textTheme.titleMedium),
                    Text(
                      "${formattaEuro(riga.prezzoUnitario)} cad.",
                      style: tema.textTheme.bodySmall,
                    ),
                    if (!riga.disponibile)
                      Text(
                        "Non disponibile nella quantità richiesta",
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: tema.colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
              // a quantità 1 il "−" diventa un cestino: con quantità 0 la riga viene rimossa
              IconButton(
                tooltip: riga.quantita > 1 ? "Diminuisci" : "Rimuovi",
                onPressed: !_invio
                    ? () => _cambiaQuantita(riga, riga.quantita - 1)
                    : null,
                icon: Icon(
                  riga.quantita > 1
                      ? Icons.remove_circle_outline
                      : Icons.delete_outline,
                ),
              ),
              // cliccando il numero si scrive la quantità a mano
              Tooltip(
                message: "Scrivi la quantità",
                child: InkWell(
                  onTap: _invio ? null : () => _chiediQuantita(riga),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      "${riga.quantita}",
                      style: tema.textTheme.titleMedium?.copyWith(
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: "Aumenta",
                onPressed: !_invio
                    ? () => _cambiaQuantita(riga, riga.quantita + 1)
                    : null,
                icon: Icon(Icons.add_circle_outline),
              ),
              SizedBox(
                width: 100,
                child: Text(
                  formattaEuro(riga.subtotale),
                  textAlign: TextAlign.right,
                  style: tema.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: "Rimuovi",
                onPressed: !_invio ? () => _rimuovi(riga) : null,
                icon: Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _riepilogo(Carrello carrello) {
    ThemeData tema = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tema.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "${carrello.numeroArticoli} articoli",
                  style: tema.textTheme.bodyMedium,
                ),
                Text(
                  "Totale ${formattaEuro(carrello.totale)}",
                  style: tema.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!carrello.acquistabile)
                  Text(
                    "Rimuovi i prodotti non disponibili per procedere.",
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _invio ? null : _svuota,
            icon: Icon(Icons.remove_shopping_cart_outlined),
            label: Text("Svuota"),
          ),
          SizedBox(width: 8),
          if (Model.sharedInstance.loggato)
            FilledButton.icon(
              onPressed: carrello.acquistabile && !_invio ? _checkout : null,
              icon: Icon(Icons.payments_outlined),
              label: Text("Procedi all'ordine"),
            )
          else
            FilledButton.icon(
              onPressed: _vaiAlLogin,
              icon: Icon(Icons.login_rounded),
              label: Text("Accedi per ordinare"),
            ),
        ],
      ),
    );
  }
}

/// Finestra per scrivere a mano la quantità di una riga: restituisce il numero, o null se si annulla.
class _DialogoQuantita extends StatefulWidget {
  final String nomeProdotto;
  final int quantitaAttuale;

  _DialogoQuantita({required this.nomeProdotto, required this.quantitaAttuale});

  @override
  _DialogoQuantitaState createState() => _DialogoQuantitaState();
}

class _DialogoQuantitaState extends State<_DialogoQuantita> {
  late TextEditingController _campo;

  @override
  void initState() {
    super.initState();
    _campo = TextEditingController(text: "${widget.quantitaAttuale}");
  }

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  void _conferma() {
    Navigator.of(
      context,
    ).pop(int.tryParse(_campo.text)); // campo vuoto → null → come "Annulla"
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Quantità"),
      content: TextField(
        controller: _campo,
        autofocus: true,
        keyboardType: TextInputType.number,
        // solo cifre (niente negativi né decimali), al massimo 3
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(3),
        ],
        decoration: InputDecoration(
          labelText: widget.nomeProdotto,
          helperText: "Scrivi 0 per rimuovere il prodotto",
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _conferma(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text("Annulla"),
        ),
        FilledButton(onPressed: _conferma, child: Text("Aggiorna")),
      ],
    );
  }
}


/// Login aperto sopra il carrello: si chiude da solo appena l'accesso riesce.
/// Un cliente torna al carrello; un admin (che il carrello non ce l'ha) torna alla home.
class _PaginaAccesso extends StatefulWidget {
  @override
  _PaginaAccessoState createState() => _PaginaAccessoState();
}

class _PaginaAccessoState extends State<_PaginaAccesso> {
  @override
  void initState() {
    super.initState();
    Model.sharedInstance.addListener(_controllaAccesso);
  }

  @override
  void dispose() {
    Model.sharedInstance.removeListener(_controllaAccesso);
    super.dispose();
  }

  void _controllaAccesso() {
    Model model = Model.sharedInstance;
    if (!model.loggato || !mounted) return;
    Model.sharedInstance.removeListener(_controllaAccesso);
    if (model.cliente) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Accedi")),
      body: LogIn(),
    );
  }
}
