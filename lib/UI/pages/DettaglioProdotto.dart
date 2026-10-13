import 'package:flutter/material.dart';
import 'package:psw_frontend/UI/widgets/Avvisi.dart';
import 'package:psw_frontend/UI/widgets/Footer.dart';
import 'package:psw_frontend/UI/widgets/ProductCard.dart';
import 'package:psw_frontend/model/Model.dart';
import 'package:psw_frontend/model/managers/RestManager.dart';
import 'package:psw_frontend/model/objects/Pagina.dart';
import 'package:psw_frontend/model/objects/Prodotto.dart';
import 'package:psw_frontend/model/support/Constants.dart';
import 'package:psw_frontend/model/support/Formati.dart';
import 'package:psw_frontend/UI/pages/CarrelloPagina.dart';

class DettaglioProdotto extends StatefulWidget {
  final Prodotto prodotto;

  DettaglioProdotto({required this.prodotto}) : super();

  @override
  _DettaglioProdottoState createState() => _DettaglioProdottoState();
}

class _DettaglioProdottoState extends State<DettaglioProdotto>
    with AzioniPagina<DettaglioProdotto> {
  // si parte dai dati ricevuti (catalogo, carrello...) e si aggiornano con quelli del backend
  late Prodotto _prodotto;
  bool _fuoriCatalogo = false;

  List<Recensione> _recensioni = [];
  int _paginaRecensioni = 0;
  bool _ultimaRecensioni = true;
  bool _caricamento = false;

  int _quantita = 1;

  int _voto = 0;
  TextEditingController _testoRecensione = TextEditingController();

  bool _invio = false;

  @override
  void initState() {
    super.initState();
    _prodotto = widget.prodotto;
    _aggiornaProdotto();
    _caricaRecensioni(daCapo: true);
  }

  @override
  void dispose() {
    _testoRecensione.dispose();
    super.dispose();
  }

  /// Rilegge il prodotto dal backend (prezzo e disponibilità attuali). Se ora non è acquistabile
  /// (404: nascosto o esaurito) lo segnala sulla pagina invece di mostrare un errore.
  Future<void> _aggiornaProdotto() async {
    try {
      Prodotto aggiornato = await Model.sharedInstance.getProdotto(
        widget.prodotto.codiceProdotto,
      );
      if (mounted) {
        setState(() {
          _prodotto = aggiornato;
        });
      }
    } on ErroreApi catch (e) {
      if (mounted && e.stato == 404) {
        setState(() {
          _fuoriCatalogo = true;
        });
      }
    } catch (_) {
      // si tengono i dati che si avevano già
    }
  }

  /// Carica una pagina di recensioni del prodotto.
  Future<void> _caricaRecensioni({bool daCapo = true}) async {
    if (_caricamento) return;
    if (daCapo) {
      setState(() {
        _paginaRecensioni = 0;
        _recensioni.clear();
        _ultimaRecensioni = true;
      });
    }
    await esegui(() async {
      Pagina<Recensione> p = await Model.sharedInstance.getRecensioni(
        widget.prodotto.codiceProdotto,
        _paginaRecensioni,
      );
      if (!mounted) return;
      setState(() {
        _recensioni.addAll(p.contenuto);
        _ultimaRecensioni = p.ultima;
        _paginaRecensioni++;
      });
    }, imposta: (v) => _caricamento = v);
  }

  /// Bottone "Aggiungi al carrello".
  Future<void> _aggiungiAlCarrello() => esegui(
    () async {
      await Model.sharedInstance.aggiungiAlCarrello(
        widget.prodotto.codiceProdotto,
        _quantita,
      );
      if (mounted) {
        setState(() {
          _quantita = 1;
        });
      }
    },
    imposta: (v) => _invio = v,
    messaggio: "Prodotto aggiunto al carrello con successo.",
  );

  /// Bottone "Pubblica" della recensione: la nuova recensione va in cima all'elenco.
  Future<void> _inviaRecensione() async {
    if(_voto < 1) {
      mostraErrore(context, "Scegli da 1 a 5 stelle.");
      return;
    }
    await esegui(
      () async {
        await Model.sharedInstance.scriviRecensione(
          widget.prodotto.codiceProdotto,
          _voto,
          _testoRecensione.text,
        );
        if (mounted) {
          setState(() {
            _voto = 0;
            _testoRecensione.clear();
          });
          _caricaRecensioni(daCapo: true);
        }
      },
      imposta: (v) => _invio = v,
      messaggio: "Recensione inviata con successo",
    );
  }

  /// Cestino di una recensione (solo admin).
  Future<void> _eliminaRecensione(Recensione r) async {
    if (!await chiediConferma(
      context,
      "Eliminare la recensione di ${r.autore ?? 'Anonimo'}?",
    ))
      return;
    if (!mounted) return;
    await esegui(
      () async {
        await Model.sharedInstance.eliminaRecensioneAdmin(r.idRecensione);
        if (mounted) {
          setState(() {
            _recensioni.remove(r);
          });
        }
      },
      imposta: (v) => _invio = v,
      messaggio: "Recensione eliminata",
    );
  }

  /// Apre il carrello sopra questa pagina: da lì si procede all'ordine.
  void _apriCarrello() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text("Carrello")),
          body: CarrelloPagina(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Prodotto p = _prodotto;
    return Scaffold(
      appBar: AppBar(title: Text(p.nome)),
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
                    Widget immagine = ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: ImmagineProdotto(url: p.urlImmagine, altezza: 340),
                    );
                    // su schermi larghi immagine e dati affiancati, su schermi stretti uno sotto l'altro
                    if (vincoli.maxWidth > 700) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: immagine),
                          SizedBox(width: 24),
                          Expanded(child: _informazioni(p)),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        immagine,
                        SizedBox(height: 16),
                        _informazioni(p),
                      ],
                    );
                  },
                ),
                SizedBox(height: 32),
                Text(
                  "Recensioni",
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                SizedBox(height: 8),
                if (Model.sharedInstance.cliente) _formRecensione(),
                ..._recensioni.map((r) => _recensione(r)),
                if (_recensioni.isEmpty && !_caricamento)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text("Ancora nessuna recensione."),
                  ),
                if (_caricamento)
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (!_ultimaRecensioni)
                  Center(
                    child: TextButton(
                      onPressed: _caricamento
                          ? null
                          : () => _caricaRecensioni(daCapo: false),
                      child: Text("Mostra altre recensioni"),
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

  Widget _informazioni(Prodotto p) {
    ThemeData tema = Theme.of(context);
    Model model = Model.sharedInstance;
    bool puoComprare =
        model.cliente || (!model.loggato && Constants.CARRELLO_OSPITE);
    bool disponibile = p.disponibile && !_fuoriCatalogo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          p.nome,
          style: tema.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (p.brand != null)
          Text(
            p.brand!,
            style: tema.textTheme.titleMedium?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
        // la categoria manca solo quando la pagina è aperta dai dati di un vecchio ordine
        if (p.categoria.isNotEmpty) ...[
          SizedBox(height: 12),
          Chip(
            avatar: Icon(Icons.sell_outlined, size: 18),
            label: Text(p.nomeCategoria),
          ),
        ],
        SizedBox(height: 12),
        Text(
          formattaEuro(p.prezzo),
          style: tema.textTheme.headlineMedium?.copyWith(
            color: tema.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          disponibile ? "Disponibile" : "Non disponibile",
          style: TextStyle(
            color: disponibile ? Colors.green.shade700 : tema.colorScheme.error,
          ),
        ),
        if (p.descrizione != null && p.descrizione!.isNotEmpty) ...[
          SizedBox(height: 16),
          Text(p.descrizione!, style: tema.textTheme.bodyLarge),
        ],
        SizedBox(height: 24),
        if (puoComprare && disponibile)
          Row(
            children: [
              IconButton.outlined(
                onPressed: _quantita > 1
                    ? () => setState(() => _quantita--)
                    : null,
                icon: Icon(Icons.remove),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  "$_quantita",
                  textAlign: TextAlign.center,
                  style: tema.textTheme.titleMedium,
                ),
              ),
              IconButton.outlined(
                onPressed: _quantita < 99
                    ? () => setState(() => _quantita++)
                    : null,
                icon: Icon(Icons.add),
              ),
              SizedBox(width: 16),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _invio ? null : _aggiungiAlCarrello,
                  icon: Icon(Icons.add_shopping_cart_rounded),
                  label: Text("Aggiungi al carrello"),
                ),
              ),
            ],
          ),
        if (puoComprare)
          ListenableBuilder(
            listenable: Model.sharedInstance,
            builder: (context, _) {
              int articoli = Model.sharedInstance.articoliNelCarrello;
              if (articoli == 0) return SizedBox.shrink();
              return Padding(
                padding: EdgeInsets.only(top: 12),
                child: OutlinedButton.icon(
                  onPressed: _apriCarrello,
                  icon: Icon(Icons.shopping_cart_checkout),
                  label: Text("Vai al carrello ($articoli)"),
                ),
              );
            },
          ),
        if (!model.loggato)
          Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              Constants.CARRELLO_OSPITE
                  ? "Accedi come cliente per ordinare e lasciare una recensione."
                  : "Accedi come cliente per acquistare e lasciare una recensione.",
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  Widget _formRecensione() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Scrivi una recensione",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            StelleVoto(
              voto: _voto,
              onChanged: (v) => setState(() => _voto = v),
            ),
            TextField(
              controller: _testoRecensione,
              maxLines: 4,
              maxLength: 4000,
              decoration: InputDecoration(
                hintText: "Cosa ne pensi? (facoltativo)",
                border: OutlineInputBorder(),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _invio ? null : _inviaRecensione,
                child: Text("Pubblica"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recensione(Recensione r) {
    ThemeData tema = Theme.of(context);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StelleVoto(voto: r.voto, dimensione: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    r.autore ?? "Anonimo",
                    style: tema.textTheme.titleSmall,
                  ),
                ),
                Text(
                  formattaData(r.dataRecensione),
                  style: tema.textTheme.bodySmall,
                ),
                if (Model.sharedInstance.admin)
                  IconButton(
                    tooltip: "Elimina recensione",
                    onPressed: _invio ? null : () => _eliminaRecensione(r),
                    icon: Icon(Icons.delete_outline),
                  ),
              ],
            ),
            if (r.testo != null && r.testo!.isNotEmpty)
              Padding(padding: EdgeInsets.only(top: 8), child: Text(r.testo!)),
          ],
        ),
      ),
    );
  }
}
