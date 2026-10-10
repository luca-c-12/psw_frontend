import 'package:flutter/material.dart';
import 'package:psw_frontend/UI/pages/DettaglioAsta.dart';
import 'package:psw_frontend/UI/pages/DettaglioProdotto.dart';
import 'package:psw_frontend/UI/widgets/Avvisi.dart';
import 'package:psw_frontend/UI/widgets/ProductCard.dart';
import 'package:psw_frontend/model/Model.dart';
import 'package:psw_frontend/model/objects/Asta.dart';
import 'package:psw_frontend/model/objects/Carrello.dart';
import 'package:psw_frontend/model/objects/Pagina.dart';
import 'package:psw_frontend/model/objects/Prodotto.dart';
import 'package:psw_frontend/model/support/Formati.dart';


/// Storico del cliente: ordini, recensioni e offerte alle aste, in tre tab.
class Storico extends StatelessWidget {
  final int tabIniziale;


  Storico({this.tabIniziale = 0}) : super();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: tabIniziale,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Il mio storico"),
          bottom: TabBar(
            tabs: [
              Tab(text: "Ordini", icon: Icon(Icons.receipt_long_outlined)),
              Tab(text: "Recensioni", icon: Icon(Icons.rate_review_outlined)),
              Tab(text: "Offerte", icon: Icon(Icons.gavel_rounded)),
            ],
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 800),
            child: TabBarView(
              children: [
                _StoricoOrdini(),
                _StoricoRecensioni(),
                _StoricoOfferte(),
              ],
            ),
          ),
        ),
      ),
    );
  }


}


/// Bottone "Carica altri" in fondo a un elenco.
Widget _caricaAltri(bool ultima, bool caricamento, VoidCallback carica) {
  if (ultima) return SizedBox(height: 24);
  return Center(
    child: TextButton(
      onPressed: caricamento ? null : carica,
      child: Text("Carica altri"),
    ),
  );
}

/// Messaggio (o rotellina) al posto di un elenco vuoto.
Widget _elencoVuoto(BuildContext context, bool caricamento, IconData icona, String testo) {
  if (caricamento) return Center(child: CircularProgressIndicator());
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icona, size: 80, color: Theme.of(context).colorScheme.outline),
        SizedBox(height: 12),
        Text(testo, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}

/// Miniatura quadrata di un prodotto.
Widget _miniatura(String? url, {double lato = 56}) {
  return SizedBox(
    width: lato,
    height: lato,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ImmagineProdotto(url: url, altezza: lato),
    ),
  );
}


// ================================== ORDINI ==================================

class _StoricoOrdini extends StatefulWidget {
  @override
  _StoricoOrdiniState createState() => _StoricoOrdiniState();
}

class _StoricoOrdiniState extends State<_StoricoOrdini> with AzioniPagina<_StoricoOrdini> {
  List<Ordine> _ordini = [];
  int _pagina = 0;
  bool _ultima = true;
  bool _caricamento = false;


  @override
  void initState() {
    super.initState();
    _carica(daCapo: true);
  }

  Future<void> _carica({bool daCapo = true}) async {
    if (_caricamento) return;
    if (daCapo) {
      setState(() {
        _pagina = 0;
        _ordini.clear();
        _ultima = true;
      });
    }
    await esegui(() async {
      Pagina<Ordine> p = await Model.sharedInstance.getOrdini(_pagina);
      if (!mounted) return;
      setState(() {
        _ordini.addAll(p.contenuto);
        _ultima = p.ultima;
        _pagina++;
      });
    }, imposta: (v) => _caricamento = v);
  }

  @override
  Widget build(BuildContext context) {
    ThemeData tema = Theme.of(context);
    if (_ordini.isEmpty) {
      return _elencoVuoto(context, _caricamento, Icons.receipt_long_outlined, "Non hai ancora effettuato ordini.");
    }
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _ordini.length + 1,
      itemBuilder: (context, index) {
        if (index == _ordini.length) {
          return _caricaAltri(_ultima, _caricamento, () => _carica(daCapo: false));
        }
        Ordine ordine = _ordini[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: CircleAvatar(child: Icon(Icons.receipt_long_outlined)),
            title: Text("Ordine n. ${ordine.idOrdine}", style: tema.textTheme.titleMedium),
            subtitle: Text(formattaDataOra(ordine.dataOrdine)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formattaEuro(ordine.totalePagato),
                  style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 8),
                Icon(Icons.chevron_right),
              ],
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => RiepilogoOrdine(idOrdine: ordine.idOrdine)),
              );
            },
          ),
        );
      },
    );
  }


}


// ================================ RECENSIONI ================================

class _StoricoRecensioni extends StatefulWidget {
  @override
  _StoricoRecensioniState createState() => _StoricoRecensioniState();
}

class _StoricoRecensioniState extends State<_StoricoRecensioni> with AzioniPagina<_StoricoRecensioni> {
  List<Recensione> _recensioni = [];
  // la recensione contiene solo il codice del prodotto: nome e immagine si leggono a parte
  // (null = prodotto nascosto o esaurito)
  Map<int, Prodotto?> _prodotti = {};
  int _pagina = 0;
  bool _ultima = true;
  bool _caricamento = false;
  bool _invio = false;


  @override
  void initState() {
    super.initState();
    _carica(daCapo: true);
  }

  Future<void> _carica({bool daCapo = true}) async {
    if (_caricamento) return;
    if (daCapo) {
      setState(() {
        _pagina = 0;
        _recensioni.clear();
        _ultima = true;
      });
    }
    await esegui(() async {
      Pagina<Recensione> p = await Model.sharedInstance.getRecensioniMie(_pagina);
      List<int> mancanti = p.contenuto.map((r) => r.codiceProdotto).toSet().where((c) => !_prodotti.containsKey(c)).toList();
      List<Prodotto?> letti = await Future.wait(mancanti.map(_prodottoOppureNull));
      if (!mounted) return;
      setState(() {
        _prodotti.addAll(Map.fromIterables(mancanti, letti));
        _recensioni.addAll(p.contenuto);
        _ultima = p.ultima;
        _pagina++;
      });
    }, imposta: (v) => _caricamento = v);
  }

  Future<Prodotto?> _prodottoOppureNull(int codice) async {
    try {
      return await Model.sharedInstance.getProdotto(codice);
    } catch (_) {
      return null;
    }
  }

  /// Salva la recensione modificata e la sostituisce nell'elenco.
  Future<void> _modificaRecensione(Recensione r, int voto, String testo) async {
    // TODO
  }

  /// Cestino di una recensione.
  Future<void> _elimina(Recensione r) async {
    if (!await chiediConferma(context, "Eliminare questa recensione?")) return;
    if (!mounted) return;
    await esegui(() async {
      await Model.sharedInstance.eliminaRecensione(r.idRecensione);
      if (mounted) {
        setState(() {
          _recensioni.remove(r);
        });
      }
    }, imposta: (v) => _invio = v, messaggio: "Recensione eliminata");
  }

  Future<void> _apriModifica(Recensione r) async {
    ({int voto, String testo})? scelta = await showDialog<({int voto, String testo})>(
      context: context,
      builder: (context) => _DialogoRecensione(voto: r.voto, testo: r.testo ?? ""),
    );
    if (scelta == null || !mounted) return;
    _modificaRecensione(r, scelta.voto, scelta.testo);
  }

  @override
  Widget build(BuildContext context) {
    if (_recensioni.isEmpty) {
      return _elencoVuoto(context, _caricamento, Icons.rate_review_outlined, "Non hai ancora scritto recensioni.");
    }
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _recensioni.length + 1,
      itemBuilder: (context, index) {
        if (index == _recensioni.length) {
          return _caricaAltri(_ultima, _caricamento, () => _carica(daCapo: false));
        }
        return _riga(_recensioni[index]);
      },
    );
  }

  Widget _riga(Recensione r) {
    ThemeData tema = Theme.of(context);
    Prodotto? prodotto = _prodotti[r.codiceProdotto];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: prodotto == null
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => DettaglioProdotto(prodotto: prodotto)),
                );
              },
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _miniatura(prodotto?.urlImmagine),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(prodotto?.nome ?? "Prodotto non disponibile", style: tema.textTheme.titleMedium),
                    Row(
                      children: [
                        StelleVoto(voto: r.voto, dimensione: 18),
                        SizedBox(width: 8),
                        Text(formattaData(r.dataRecensione), style: tema.textTheme.bodySmall),
                      ],
                    ),
                    if (r.testo != null && r.testo!.isNotEmpty)
                      Padding(padding: EdgeInsets.only(top: 6), child: Text(r.testo!)),
                  ],
                ),
              ),
              IconButton(
                tooltip: "Modifica",
                onPressed: _invio ? null : () => _apriModifica(r),
                icon: Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: "Elimina",
                onPressed: _invio ? null : () => _elimina(r),
                icon: Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }


}


/// Finestra per modificare voto e testo di una recensione: restituisce i nuovi valori, o null se si annulla.
class _DialogoRecensione extends StatefulWidget {
  final int voto;
  final String testo;


  _DialogoRecensione({required this.voto, required this.testo});

  @override
  _DialogoRecensioneState createState() => _DialogoRecensioneState();
}

class _DialogoRecensioneState extends State<_DialogoRecensione> {
  late int _voto;
  late TextEditingController _testo;


  @override
  void initState() {
    super.initState();
    _voto = widget.voto;
    _testo = TextEditingController(text: widget.testo);
  }

  @override
  void dispose() {
    _testo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Modifica recensione"),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StelleVoto(voto: _voto, onChanged: (v) => setState(() => _voto = v)),
            TextField(
              controller: _testo,
              maxLines: 4,
              maxLength: 4000,
              decoration: InputDecoration(
                hintText: "Cosa ne pensi? (facoltativo)",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text("Annulla"),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop((voto: _voto, testo: _testo.text)),
          child: Text("Salva"),
        ),
      ],
    );
  }


}


// ================================= OFFERTE =================================

class _StoricoOfferte extends StatefulWidget {
  @override
  _StoricoOfferteState createState() => _StoricoOfferteState();
}

class _StoricoOfferteState extends State<_StoricoOfferte> with AzioniPagina<_StoricoOfferte> {
  List<OffertaAsta> _offerte = [];
  // l'offerta contiene solo l'id dell'asta: prodotto e stato si leggono a parte (null = asta non disponibile)
  Map<int, Asta?> _aste = {};
  int _pagina = 0;
  bool _ultima = true;
  bool _caricamento = false;


  @override
  void initState() {
    super.initState();
    _carica(daCapo: true);
  }

  Future<void> _carica({bool daCapo = true}) async {
    if (_caricamento) return;
    if (daCapo) {
      setState(() {
        _pagina = 0;
        _offerte.clear();
        _aste.clear();
        _ultima = true;
      });
    }
    await esegui(() async {
      Pagina<OffertaAsta> p = await Model.sharedInstance.getMieOfferte(_pagina);
      List<int> mancanti = p.contenuto.map((o) => o.idAsta).toSet().where((id) => !_aste.containsKey(id)).toList();
      List<Asta?> lette = await Future.wait(mancanti.map(_astaOppureNull));
      if (!mounted) return;
      setState(() {
        _aste.addAll(Map.fromIterables(mancanti, lette));
        _offerte.addAll(p.contenuto);
        _ultima = p.ultima;
        _pagina++;
      });
    }, imposta: (v) => _caricamento = v);
  }

  Future<Asta?> _astaOppureNull(int idAsta) async {
    try {
      return await Model.sharedInstance.getAsta(idAsta);
    } catch (_) {
      return null;
    }
  }

  /// Etichetta e colore dello stato di un'offerta rispetto alla sua asta.
  (String, Color) _stato(OffertaAsta o, Asta? asta) {
    ThemeData tema = Theme.of(context);
    if (asta == null) return ("Asta non disponibile", tema.colorScheme.outline);
    bool piuAlta = asta.offertaMassima?.idOffertaAsta == o.idOffertaAsta;
    if (asta.chiusa) {
      return piuAlta && asta.vincitore != null
          ? ("Vinta", Colors.green.shade700)
          : ("Non vinta", tema.colorScheme.outline);
    }
    return piuAlta
        ? ("Offerta più alta", Colors.green.shade700)
        : ("Superata: ora ${formattaEuro(asta.prezzoCorrente)}", tema.colorScheme.error);
  }

  @override
  Widget build(BuildContext context) {
    if (_offerte.isEmpty) {
      return _elencoVuoto(context, _caricamento, Icons.gavel_rounded, "Non hai ancora fatto offerte.");
    }
    ThemeData tema = Theme.of(context);
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _offerte.length + 1,
      itemBuilder: (context, index) {
        if (index == _offerte.length) {
          return _caricaAltri(_ultima, _caricamento, () => _carica(daCapo: false));
        }
        OffertaAsta o = _offerte[index];
        Asta? asta = _aste[o.idAsta];
        (String, Color) stato = _stato(o, asta);
        return Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            leading: _miniatura(asta?.prodotto.urlImmagine),
            title: Text(asta?.prodotto.nome ?? "Asta n. ${o.idAsta}"),
            subtitle: Text(
              "${formattaDataOra(o.dataOfferta)}\n${stato.$1}",
              style: TextStyle(color: stato.$2),
            ),
            isThreeLine: true,
            trailing: Text(
              formattaEuro(o.importo),
              style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            onTap: asta == null
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => DettaglioAsta(asta: asta)),
                    );
                  },
          ),
        );
      },
    );
  }


}


// ============================ RIEPILOGO ORDINE ============================

/// Riepilogo di un ordine: indirizzo, prodotti acquistati e totale.
/// Con [admin] true legge l'ordine con l'endpoint dell'amministratore.
class RiepilogoOrdine extends StatefulWidget {
  final int idOrdine;
  final bool admin;


  RiepilogoOrdine({required this.idOrdine, this.admin = false}) : super();

  @override
  _RiepilogoOrdineState createState() => _RiepilogoOrdineState();
}

class _RiepilogoOrdineState extends State<RiepilogoOrdine> with AzioniPagina<RiepilogoOrdine> {
  Ordine? _ordine;
  bool _caricamento = false;
  bool _apertura = false;     // true mentre si apre la scheda di un prodotto


  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() => esegui(() async {
    Ordine ordine = widget.admin
        ? await Model.sharedInstance.getOrdineAdmin(widget.idOrdine)
        : await Model.sharedInstance.getOrdine(widget.idOrdine);
    if (mounted) {
      setState(() {
        _ordine = ordine;
      });
    }
  }, imposta: (v) => _caricamento = v);

  /// Apre la scheda attuale del prodotto di una riga (errore se ora è nascosto o esaurito).
  Future<void> _apriProdotto(int codiceProdotto) => esegui(() async {
    Prodotto prodotto = await Model.sharedInstance.getProdotto(codiceProdotto);
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => DettaglioProdotto(prodotto: prodotto)),
      );
    }
  }, imposta: (v) => _apertura = v);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Ordine n. ${widget.idOrdine}")),
      body: _corpo(),
    );
  }

  Widget _corpo() {
    Ordine? ordine = _ordine;
    if (ordine == null) {
      return Center(
        child: _caricamento
            ? CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Ordine non ancora caricato."),
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
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: tema.colorScheme.primary, size: 32),
                      SizedBox(width: 12),
                      Expanded(child: Text("Riepilogo ordine", style: tema.textTheme.headlineSmall)),
                    ],
                  ),
                  SizedBox(height: 16),
                  _voce("Numero ordine", "${ordine.idOrdine}"),
                  _voce("Data", formattaDataOra(ordine.dataOrdine)),
                  _voce("Spedito a", ordine.indirizzoSpedizione ?? "—"),
                  Divider(height: 32),
                  Text("Prodotti", style: tema.textTheme.titleMedium),
                  SizedBox(height: 8),
                  ...ordine.righe.map((riga) => _riga(riga)),
                  Divider(height: 32),
                  Row(
                    children: [
                      Expanded(child: Text("Totale pagato", style: tema.textTheme.titleLarge)),
                      Text(
                        formattaEuro(ordine.totalePagato),
                        style: tema.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: tema.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text("I prezzi sono quelli applicati al momento dell'acquisto.", style: tema.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _voce(String etichetta, String valore) {
    ThemeData tema = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(etichetta, style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.outline)),
          ),
          Expanded(child: Text(valore, style: tema.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  Widget _riga(LineaOrdine riga) {
    ThemeData tema = Theme.of(context);
    int? codice = riga.codiceProdotto;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _miniatura(riga.urlImmagine, lato: 64),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(riga.nomeProdotto, style: tema.textTheme.bodyLarge),
                Text("${riga.quantita} × ${formattaEuro(riga.prezzoUnitario)}", style: tema.textTheme.bodySmall),
                if (codice != null)
                  TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                    onPressed: _apertura ? null : () => _apriProdotto(codice),
                    child: Text("Visualizza prodotto"),
                  ),
              ],
            ),
          ),
          Text(formattaEuro(riga.subtotale), style: tema.textTheme.bodyLarge),
        ],
      ),
    );
  }


}
