import 'package:flutter/material.dart';
import 'package:psw_frontend/UI/pages/DettaglioProdotto.dart';
import 'package:psw_frontend/UI/widgets/Avvisi.dart';
import 'package:psw_frontend/UI/widgets/Footer.dart';
import 'package:psw_frontend/UI/widgets/ProductCard.dart';
import 'package:psw_frontend/UI/widgets/SchedaUtente.dart';
import 'package:psw_frontend/model/Model.dart';
import 'package:psw_frontend/model/objects/Asta.dart';
import 'package:psw_frontend/model/objects/Pagina.dart';
import 'package:psw_frontend/model/support/Formati.dart';

/// Pagina di un'asta, con le offerte ricevute e il campo per offrire.
class DettaglioAsta extends StatefulWidget {
  final Asta asta;

  DettaglioAsta({required this.asta}) : super();

  @override
  _DettaglioAstaState createState() => _DettaglioAstaState();
}

class _DettaglioAstaState extends State<DettaglioAsta>
    with AzioniPagina<DettaglioAsta> {
  late Asta _asta; // si parte da quella ricevuta dall'elenco, poi si aggiorna
  List<OffertaAsta> _offerte = [];
  bool _caricamento = false;
  bool _invio = false;
  TextEditingController _importo = TextEditingController();

  @override
  void initState() {
    super.initState();
    _asta = widget.asta;
    _aggiorna();
  }

  @override
  void dispose() {
    _importo.dispose();
    super.dispose();
  }

  /// Ricarica l'asta (prezzo corrente, stato) e la prima pagina delle sue offerte.
  /// È anche il bottone di aggiornamento in alto.
  Future<void> _aggiorna() async {
    await esegui(() async {
      List<dynamic> lista = await Future.wait([
        Model.sharedInstance.getAsta(_asta.idAsta),
        Model.sharedInstance.getOfferte(_asta.idAsta, 0),
      ]);
      Pagina<OffertaAsta> pagina = lista[1] as Pagina<OffertaAsta>;
      if (mounted) {
        setState(() {
          _asta = lista[0] as Asta;
          _offerte = pagina.contenuto;
        });
      }
    }, imposta: (v) => _caricamento = v);
  }

  /// Bottone "Offri".
  Future<void> _offri() async {
    if (_invio) return;
    double? importo = leggiImporto(_importo.text);
    if (importo == null || !importoValido(_importo.text)) {
      mostraErrore(context, "Inserire un importo valido.");
      return;
    }
    await esegui(() async {
      await Model.sharedInstance.faiOfferta(_asta.idAsta, importo);
      if(mounted) {
        _importo.clear();
        _aggiorna();
      }
    },
        imposta: (v) => _invio = v,
        messaggio: "Offerta inviata correttamente.",
        dopoErrore: _aggiorna
    );
  }

  /// Apre la pagina del prodotto messo all'asta (durante l'asta è fuori catalogo: compare "Non disponibile").
  void _apriProdotto() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DettaglioProdotto(prodotto: _asta.prodotto),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool admin = Model.sharedInstance.admin;
    return Scaffold(
      appBar: AppBar(
        title: Text("Asta: ${_asta.prodotto.nome}"),
        actions: [
          IconButton(
            tooltip: "Aggiorna",
            onPressed: _caricamento ? null : _aggiorna,
            icon: Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, vincoli) {
                    Widget immagine = InkWell(
                      onTap: _apriProdotto,
                      borderRadius: BorderRadius.circular(20),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: ImmagineProdotto(
                          url: _asta.prodotto.urlImmagine,
                          altezza: 300,
                        ),
                      ),
                    );
                    if (vincoli.maxWidth > 700) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: immagine),
                          SizedBox(width: 24),
                          Expanded(child: _informazioni()),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        immagine,
                        SizedBox(height: 16),
                        _informazioni(),
                      ],
                    );
                  },
                ),
                SizedBox(height: 24),
                if (Model.sharedInstance.cliente &&
                    _asta.inCorso &&
                    !_asta.chiusa)
                  _formOfferta(),
                SizedBox(height: 24),
                Text(
                  "Offerte",
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                SizedBox(height: 8),
                if (_offerte.isEmpty)
                  Text(
                    _caricamento
                        ? "Caricamento..."
                        : "Nessuna offerta per ora.",
                  ),
                ..._offerte.map(
                  (o) => Card(
                    child: ListTile(
                      // l'admin vede la scheda di chi ha offerto
                      onTap: admin ? () => mostraSchedaUtente(context, o.idCliente) : null,
                      leading: CircleAvatar(child: Icon(Icons.person_rounded)),
                      title: Text(o.offerente ?? "Anonimo"),
                      subtitle: Text(formattaDataOra(o.dataOfferta)),
                      trailing: Text(
                        formattaEuro(o.importo),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                Footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _informazioni() {
    ThemeData tema = Theme.of(context);
    Color coloreStato = _asta.inCorso
        ? Colors.green.shade700
        : (_asta.stato == "PROGRAMMATA"
              ? tema.colorScheme.primary
              : tema.colorScheme.outline);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _asta.prodotto.nome,
          style: tema.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        TextButton.icon(
          onPressed: _apriProdotto,
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          icon: Icon(Icons.info_outline, size: 18),
          label: Text("Scheda del prodotto e recensioni"),
        ),
        SizedBox(height: 8),
        Chip(
          avatar: Icon(Icons.circle, size: 12, color: coloreStato),
          label: Text(_asta.nomeStato),
        ),
        SizedBox(height: 12),
        Text(
          _asta.offertaMassima == null ? "Prezzo base" : "Offerta attuale",
          style: tema.textTheme.labelLarge,
        ),
        Text(
          formattaEuro(_asta.prezzoCorrente),
          style: tema.textTheme.headlineMedium?.copyWith(
            color: tema.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (_asta.offertaMassima != null)
          Text(
            "di ${_asta.offertaMassima!.offerente ?? 'Anonimo'} · prezzo base ${formattaEuro(_asta.prezzoBase)}",
          ),
        SizedBox(height: 12),
        Text("Inizio: ${formattaDataOra(_asta.dataInizio)}"),
        Text("Fine: ${formattaDataOra(_asta.dataFine)}"),
        if (_asta.chiusa) ...[
          SizedBox(height: 12),
          Text(
            _asta.vincitore != null
                ? "Vinta da ${_asta.vincitore}"
                : "Nessun vincitore",
            style: tema.textTheme.titleMedium,
          ),
        ],
      ],
    );
  }

  Widget _formOfferta() {
    String suggerimento = _asta.offertaMassima == null
        ? "Almeno ${formattaEuro(_asta.prezzoBase)}"
        : "Più di ${formattaEuro(_asta.prezzoCorrente)}";
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _importo,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: "La tua offerta (€)",
                  helperText: suggerimento,
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _offri(),
              ),
            ),
            SizedBox(width: 12),
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: FilledButton.icon(
                onPressed: _invio ? null : _offri,
                icon: Icon(Icons.gavel_rounded),
                label: Text("Offri"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
