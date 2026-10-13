import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:psw_frontend/UI/pages/Storico.dart';
import 'package:psw_frontend/UI/widgets/Avvisi.dart';
import 'package:psw_frontend/UI/widgets/ProductCard.dart';
import 'package:psw_frontend/model/Model.dart';
import 'package:psw_frontend/model/objects/Asta.dart';
import 'package:psw_frontend/model/objects/Carrello.dart';
import 'package:psw_frontend/model/objects/Cliente.dart';
import 'package:psw_frontend/model/objects/Pagina.dart';
import 'package:psw_frontend/model/objects/Prodotto.dart';
import 'package:psw_frontend/model/support/Formati.dart';

/// Area dell'amministratore: prodotti, aste, ordini e utenti.
class Admin extends StatefulWidget {
  Admin() : super();

  @override
  _AdminState createState() => _AdminState();
}

class _AdminState extends State<Admin> with AzioniPagina<Admin> {
  List<ProdottoAdmin> _prodotti = [];
  int _paginaProdotti = 0;
  bool _ultimaProdotti = true;
  bool _caricamentoProdotti = false;

  // aste in corso e programmate, insieme
  List<Asta> _aste = [];
  bool _caricamentoAste = false;
  List<ProdottoAdmin> _candidatiAsta = []; // prodotti offerti nel form "Nuova asta" (tutto il catalogo)

  List<Ordine> _ordini = [];
  int _paginaOrdini = 0;
  bool _ultimaOrdini = true;
  bool _caricamentoOrdini = false;
  DateTime _dal = DateTime.now().subtract(Duration(days: 30));
  DateTime _al = DateTime.now();

  List<Utente> _utenti = [];
  int _paginaUtenti = 0;
  bool _ultimaUtenti = true;
  bool _caricamentoUtenti = false;

  bool _invio = false; // true mentre è in corso una modifica

  @override
  void initState() {
    super.initState();
    _caricaProdotti(daCapo: true);
    _caricaAste();
    _caricaOrdini(daCapo: true);
    _caricaUtenti(daCapo: true);
  }

  // ================================ PRODOTTI ================================

  /// Carica una pagina di prodotti (anche quelli nascosti).
  Future<void> _caricaProdotti({bool daCapo = true}) async {
    if (_caricamentoProdotti) return;
    if (daCapo) {
      setState(() {
        _paginaProdotti = 0;
        _prodotti.clear();
        _ultimaProdotti = true;
      });
    }
    await esegui(() async {
      Pagina<ProdottoAdmin> p = await Model.sharedInstance.getProdottiAdmin(
        _paginaProdotti,
      );
      if (!mounted) return;
      setState(() {
        _prodotti.addAll(p.contenuto);
        _ultimaProdotti = p.ultima;
        _paginaProdotti++;
      });
    }, imposta: (v) => _caricamentoProdotti = v);
  }

  /// Sostituisce nell'elenco un prodotto con la versione aggiornata dal backend.
  void _sostituisci(ProdottoAdmin vecchio, ProdottoAdmin nuovo) {
    setState(() {
      int i = _prodotti.indexOf(vecchio);
      if (i != -1) _prodotti[i] = nuovo;
    });
  }

  /// Interruttore Visibile/Nascosto di un prodotto.
  Future<void> _cambiaVisibilita(ProdottoAdmin prodotto, bool visibile) =>
      esegui(() async {
        ProdottoAdmin aggiornato = await Model.sharedInstance.impostaVisibilita(
          prodotto.prodotto.codiceProdotto,
          visibile,
        );
        if (mounted) _sostituisci(prodotto, aggiornato);
      }, imposta: (v) => _invio = v);

  /// Chiamato con i dati del form "Nuovo prodotto": il nuovo prodotto va in cima all'elenco.
  Future<void> _creaProdotto(Map<String, dynamic> dati) async {
    await esegui(
      () async {
        ProdottoAdmin p = await Model.sharedInstance.creaProdotto(dati);
        if (mounted) {
          setState(() {
            _prodotti.insert(0, p);
          });
        }
      },
      imposta: (v) => _invio = v,
      messaggio: "Prodotto aggiunto al catalogo con successo.",
    );
  }

  /// Chiamato con i dati del form "Modifica prodotto".
  Future<void> _modificaProdotto(
    ProdottoAdmin prodotto,
    Map<String, dynamic> dati,
  ) async {
    await esegui(
      () async {
        ProdottoAdmin p = await Model.sharedInstance.aggiornaProdotto(
          prodotto.prodotto.codiceProdotto,
          dati,
        );
        if (mounted) _sostituisci(prodotto, p);
      },
      imposta: (v) => _invio = v,
      messaggio: "Dati del prodotto aggiornati correttamente.",
    );
  }

  /// Bottone "Giacenza" di un prodotto.
  Future<void> _impostaGiacenza(ProdottoAdmin prodotto) async {
    int? quantita = await showDialog<int>(
      context: context,
      builder: (context) => _DialogoGiacenza(
        nomeProdotto: prodotto.prodotto.nome,
        quantitaAttuale: prodotto.quantita,
      ),
    );
    if (quantita == null || quantita == prodotto.quantita || !mounted) return;
    await esegui(
      () async {
        ProdottoAdmin aggiornato = await Model.sharedInstance.impostaGiacenza(
          prodotto.prodotto.codiceProdotto,
          quantita,
        );
        if (mounted) _sostituisci(prodotto, aggiornato);
      },
      imposta: (v) => _invio = v,
      messaggio: "Giacenza aggiornata",
    );
  }

  Future<void> _apriFormProdotto({ProdottoAdmin? daModificare}) async {
    Map<String, dynamic>? dati = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _FormProdotto(iniziale: daModificare),
    );
    if (dati == null || !mounted) return;
    if (daModificare == null) {
      _creaProdotto(dati);
    } else {
      _modificaProdotto(daModificare, dati);
    }
  }

  // ================================== ASTE ==================================

  /// Carica le aste in corso e quelle programmate (prima pagina di ciascuna).
  Future<void> _caricaAste() => esegui(() async {
    List<Pagina<Asta>> pagine = await Future.wait([
      Model.sharedInstance.getAste(false, 0),
      Model.sharedInstance.getAste(true, 0),
    ]);
    if (!mounted) return;
    setState(() {
      _aste = [...pagine[0].contenuto, ...pagine[1].contenuto];
    });
  }, imposta: (v) => _caricamentoAste = v);

  /// Chiamato con i dati del form "Nuova asta".
  Future<void> _creaAsta(Map<String, dynamic> dati) async {
    int indice = -1;
    for (int i = 0; i < _candidatiAsta.length; i++) {
      if (_candidatiAsta[i].prodotto.codiceProdotto == dati['codiceProdotto']) {
        indice = i;
        break;
      }
    }
    String msg = (indice != -1 && _candidatiAsta[indice].visibile)
        ? "Asta creata correttamente. ${_candidatiAsta[indice].prodotto.nome} è stato rimosso dal catalogo."
        : "Asta creata correttamente.";
    await esegui(
      () async {
        Asta a = await Model.sharedInstance.creaAsta(dati);
        if (mounted) {
          setState(() {
            _aste.insert(0, a);
          });
          _caricaProdotti(daCapo: true);
        }
      },
      imposta: (v) => _invio = v,
      messaggio: msg,
    );
  }

  /// Bottone "Annulla" di un'asta.
  Future<void> _annullaAsta(Asta asta) async {
    if (!await chiediConferma(
      context,
      "Annullare l'asta di ${asta.prodotto.nome}?",
    ))
      return;
    if (!mounted) return;
    await esegui(
      () async {
        await Model.sharedInstance.annullaAsta(asta.idAsta);
        if (mounted) {
          setState(() {
            _aste.remove(asta);
          });
        }
      },
      imposta: (v) => _invio = v,
      messaggio: "Asta annullata",
    );
  }

  Future<void> _apriFormAsta() async {
    // la tendina offre tutto il catalogo, non solo le pagine caricate nella sezione Prodotti
    List<ProdottoAdmin>? tutti;
    await esegui(() async {
      tutti = await Model.sharedInstance.getTuttiProdottiAdmin();
    }, imposta: (v) => _invio = v);
    List<ProdottoAdmin>? caricati = tutti;
    if (caricati == null || !mounted) return;
    // il backend nasconde il prodotto quando crea l'asta; servono pezzi disponibili e nessuna asta già aperta
    _candidatiAsta = caricati
        .where(
          (p) =>
              p.quantita > 0 &&
              !_aste.any(
                (a) => a.prodotto.codiceProdotto == p.prodotto.codiceProdotto,
              ),
        )
        .toList();
    Map<String, dynamic>? dati = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _FormAsta(prodotti: _candidatiAsta),
    );
    if (dati != null && mounted) {
      _creaAsta(dati);
    }
  }

  // ================================= ORDINI =================================

  /// Carica una pagina degli ordini fatti tra _dal e _al (estremi inclusi).
  Future<void> _caricaOrdini({bool daCapo = true}) async {
    if (_caricamentoOrdini) return;
    if(DateTime(_dal.year, _dal.month, _dal.day)
        .isAfter(DateTime(_al.year, _al.month, _al.day))) {
      mostraErrore(context, "Inserire un intervallo valido.");
      return;
    }
    if (daCapo) {
      setState(() {
        _paginaOrdini = 0;
        _ordini.clear();
        _ultimaOrdini = true;
      });
    }
    await esegui(() async {
      Pagina<Ordine> p = await Model.sharedInstance.getOrdiniAdmin(_dal, _al, _paginaOrdini);
      if (!mounted) return;
      setState(() {
        _ordini.addAll(p.contenuto);
        _ultimaOrdini = p.ultima;
        _paginaOrdini++;
      });
    }, imposta: (v) => _caricamentoOrdini = v);
  }

  Future<void> _scegliGiorno(bool inizio) async {
    DateTime? scelta = await showDatePicker(
      context: context,
      initialDate: inizio ? _dal : _al,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (scelta == null || !mounted) return;
    setState(() {
      if (inizio) {
        _dal = scelta;
      } else {
        _al = scelta;
      }
    });
  }

  // ================================= UTENTI =================================

  /// Carica una pagina di utenti.
  Future<void> _caricaUtenti({bool daCapo = true}) async {
    if (_caricamentoUtenti) return;
    if (daCapo) {
      setState(() {
        _paginaUtenti = 0;
        _utenti.clear();
        _ultimaUtenti = true;
      });
    }
    await esegui(() async {
      Pagina<Utente> p = await Model.sharedInstance.getUtenti(_paginaUtenti);
      if (!mounted) return;
      setState(() {
        _utenti.addAll(p.contenuto);
        _ultimaUtenti = p.ultima;
        _paginaUtenti++;
      });
    }, imposta: (v) => _caricamentoUtenti = v);
  }

  /// Rilegge un utente dal backend e ne mostra la scheda.
  Future<void> _apriUtente(Utente utente) => esegui(() async {
    Utente u = await Model.sharedInstance.getUtente(utente.idUtente);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => _SchedaUtente(utente: u),
    );
  }, imposta: (v) => _invio = v);

  // ================================= GRAFICA =================================

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: Column(
          children: [
            TabBar(
              tabs: [
                Tab(text: "Prodotti", icon: Icon(Icons.inventory_2_outlined)),
                Tab(text: "Aste", icon: Icon(Icons.gavel_rounded)),
                Tab(text: "Ordini", icon: Icon(Icons.receipt_long_outlined)),
                Tab(text: "Utenti", icon: Icon(Icons.people_outline)),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _sezioneProdotti(),
                  _sezioneAste(),
                  _sezioneOrdini(),
                  _sezioneUtenti(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ultima voce di un elenco paginato: "Carica altri" se ci sono altre pagine.
  Widget _caricaAltri(bool ultima, bool caricamento, VoidCallback carica) {
    if (ultima) return SizedBox(height: 24);
    return Center(
      child: TextButton(
        onPressed: caricamento ? null : carica,
        child: Text("Carica altri"),
      ),
    );
  }

  Widget _miniatura(String? url) {
    return SizedBox(
      width: 56,
      height: 56,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ImmagineProdotto(url: url, altezza: 56),
      ),
    );
  }

  Widget _sezioneProdotti() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Text(
                "${_prodotti.length} prodotti caricati",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Spacer(),
              FilledButton.icon(
                onPressed: () => _apriFormProdotto(),
                icon: Icon(Icons.add),
                label: Text("Nuovo prodotto"),
              ),
            ],
          ),
        ),
        Expanded(
          child: _prodotti.isEmpty
              ? Center(
                  child: _caricamentoProdotti
                      ? CircularProgressIndicator()
                      : Text("Nessun prodotto."),
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _prodotti.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _prodotti.length) {
                      return _caricaAltri(
                        _ultimaProdotti,
                        _caricamentoProdotti,
                        () => _caricaProdotti(daCapo: false),
                      );
                    }
                    return _rigaProdotto(_prodotti[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _rigaProdotto(ProdottoAdmin pa) {
    Prodotto p = pa.prodotto;
    return Card(
      child: ListTile(
        leading: _miniatura(p.urlImmagine),
        title: Text(p.nome),
        subtitle: Text(
          "${formattaEuro(p.prezzo)} · ${pa.quantita} pz · ${p.nomeCategoria}",
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: "Modifica",
              onPressed: _invio
                  ? null
                  : () => _apriFormProdotto(daModificare: pa),
              icon: Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: "Giacenza",
              onPressed: _invio ? null : () => _impostaGiacenza(pa),
              icon: Icon(Icons.inventory_outlined),
            ),
            SizedBox(width: 8),
            Text(pa.visibile ? "Visibile" : "Nascosto"),
            Switch(
              value: pa.visibile,
              onChanged: _invio
                  ? null
                  : (valore) => _cambiaVisibilita(pa, valore),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sezioneAste() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Text(
                "Aste in corso e programmate",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Spacer(),
              IconButton(
                tooltip: "Aggiorna",
                onPressed: _caricamentoAste ? null : _caricaAste,
                icon: Icon(Icons.refresh_rounded),
              ),
              SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _invio ? null : _apriFormAsta,
                icon: Icon(Icons.add),
                label: Text("Nuova asta"),
              ),
            ],
          ),
        ),
        Expanded(
          child: _aste.isEmpty
              ? Center(
                  child: _caricamentoAste
                      ? CircularProgressIndicator()
                      : Text("Nessuna asta attiva."),
                )
              : ListView(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  children: _aste
                      .map(
                        (asta) => Card(
                          child: ListTile(
                            leading: _miniatura(asta.prodotto.urlImmagine),
                            title: Text(asta.prodotto.nome),
                            subtitle: Text(
                              "${asta.nomeStato} · ${formattaEuro(asta.prezzoCorrente)}\n"
                              "dal ${formattaDataOra(asta.dataInizio)} al ${formattaDataOra(asta.dataFine)}",
                            ),
                            isThreeLine: true,
                            trailing: OutlinedButton.icon(
                              onPressed: _invio
                                  ? null
                                  : () => _annullaAsta(asta),
                              icon: Icon(Icons.cancel_outlined),
                              label: Text("Annulla"),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _sezioneOrdini() {
    ThemeData tema = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(12),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text("Ordini dal", style: tema.textTheme.titleMedium),
              OutlinedButton.icon(
                onPressed: () => _scegliGiorno(true),
                icon: Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(formattaData(_dal)),
              ),
              Text("al", style: tema.textTheme.titleMedium),
              OutlinedButton.icon(
                onPressed: () => _scegliGiorno(false),
                icon: Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(formattaData(_al)),
              ),
              FilledButton.icon(
                onPressed: _caricamentoOrdini
                    ? null
                    : () => _caricaOrdini(daCapo: true),
                icon: Icon(Icons.search_rounded),
                label: Text("Cerca"),
              ),
            ],
          ),
        ),
        Expanded(
          child: _ordini.isEmpty
              ? Center(
                  child: _caricamentoOrdini
                      ? CircularProgressIndicator()
                      : Text("Nessun ordine nel periodo."),
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _ordini.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _ordini.length) {
                      return _caricaAltri(
                        _ultimaOrdini,
                        _caricamentoOrdini,
                        () => _caricaOrdini(daCapo: false),
                      );
                    }
                    Ordine ordine = _ordini[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(Icons.receipt_long_outlined),
                        ),
                        title: Text("Ordine n. ${ordine.idOrdine}"),
                        subtitle: Text(formattaDataOra(ordine.dataOrdine)),
                        trailing: Text(
                          formattaEuro(ordine.totalePagato),
                          style: tema.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => RiepilogoOrdine(
                                idOrdine: ordine.idOrdine,
                                admin: true,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _sezioneUtenti() {
    ThemeData tema = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Text(
                "${_utenti.length} utenti caricati",
                style: tema.textTheme.titleMedium,
              ),
              Spacer(),
              IconButton(
                tooltip: "Aggiorna",
                onPressed: _caricamentoUtenti
                    ? null
                    : () => _caricaUtenti(daCapo: true),
                icon: Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: _utenti.isEmpty
              ? Center(
                  child: _caricamentoUtenti
                      ? CircularProgressIndicator()
                      : Text("Nessun utente."),
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _utenti.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _utenti.length) {
                      return _caricaAltri(
                        _ultimaUtenti,
                        _caricamentoUtenti,
                        () => _caricaUtenti(daCapo: false),
                      );
                    }
                    Utente u = _utenti[index];
                    String nome = u.nomeCompleto.isEmpty
                        ? (u.email ?? "Utente ${u.idUtente}")
                        : u.nomeCompleto;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            nome.isEmpty
                                ? "?"
                                : nome.substring(0, 1).toUpperCase(),
                          ),
                        ),
                        title: Text(nome),
                        subtitle: Text(u.email ?? ""),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            Chip(
                              label: Text(
                                u.ruolo == "ADMIN" ? "Admin" : "Cliente",
                              ),
                            ),
                            if (!u.attivo)
                              Chip(
                                label: Text("Disattivato"),
                                backgroundColor:
                                    tema.colorScheme.errorContainer,
                              ),
                          ],
                        ),
                        onTap: _invio ? null : () => _apriUtente(u),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ================================== DIALOGHI ==================================

/// Scheda di un utente.
class _SchedaUtente extends StatelessWidget {
  final Utente utente;

  _SchedaUtente({required this.utente});

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

/// Finestra per scrivere la nuova giacenza: restituisce il numero, o null se si annulla.
class _DialogoGiacenza extends StatefulWidget {
  final String nomeProdotto;
  final int quantitaAttuale;

  _DialogoGiacenza({required this.nomeProdotto, required this.quantitaAttuale});

  @override
  _DialogoGiacenzaState createState() => _DialogoGiacenzaState();
}

class _DialogoGiacenzaState extends State<_DialogoGiacenza> {
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
    Navigator.of(context).pop(int.tryParse(_campo.text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Giacenza"),
      content: TextField(
        controller: _campo,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        decoration: InputDecoration(
          labelText: widget.nomeProdotto,
          helperText: "Pezzi in magazzino",
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _conferma(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text("Annulla"),
        ),
        FilledButton(onPressed: _conferma, child: Text("Salva")),
      ],
    );
  }
}

/// Form "Nuovo prodotto" (campi di CreaProdottoRequest) oppure, con [iniziale],
/// "Modifica prodotto" (campi di AggiornaProdottoRequest: senza quantità, che ha il suo PATCH).
/// Restituisce la Map per il backend, o null se si annulla.
class _FormProdotto extends StatefulWidget {
  final ProdottoAdmin? iniziale;

  _FormProdotto({this.iniziale});

  @override
  _FormProdottoState createState() => _FormProdottoState();
}

class _FormProdottoState extends State<_FormProdotto> {
  final GlobalKey<FormState> _chiaveForm = GlobalKey<FormState>();
  TextEditingController _nome = TextEditingController();
  TextEditingController _brand = TextEditingController();
  TextEditingController _descrizione = TextEditingController();
  TextEditingController _prezzo = TextEditingController();
  TextEditingController _quantita = TextEditingController(text: "1");
  TextEditingController _urlImmagine = TextEditingController();
  String? _categoria;

  bool get _modifica => widget.iniziale != null;

  @override
  void initState() {
    super.initState();
    ProdottoAdmin? iniziale = widget.iniziale;
    if (iniziale != null) {
      Prodotto p = iniziale.prodotto;
      _nome.text = p.nome;
      _brand.text = p.brand ?? "";
      _descrizione.text = p.descrizione ?? "";
      _prezzo.text = p.prezzo.toStringAsFixed(2).replaceAll('.', ',');
      _quantita.text = "${iniziale.quantita}";
      _urlImmagine.text = p.urlImmagine ?? "";
      _categoria = p.categoria;
    }
  }

  @override
  void dispose() {
    _nome.dispose();
    _brand.dispose();
    _descrizione.dispose();
    _prezzo.dispose();
    _quantita.dispose();
    _urlImmagine.dispose();
    super.dispose();
  }

  void _conferma() {
    if (!_chiaveForm.currentState!.validate()) return;
    String descrizione = _descrizione.text.trim();
    String brand = _brand.text.trim();
    String url = _urlImmagine.text.trim();
    Map<String, dynamic> dati = {
      "nome": _nome.text.trim(),
      "descrizione": descrizione.isEmpty ? null : descrizione,
      "brand": brand.isEmpty ? null : brand,
      "prezzo": leggiImporto(_prezzo.text),
      "categoria": _categoria,
      "urlImmagine": url.isEmpty ? null : url,
    };
    if (!_modifica) {
      dati["quantita"] = int.parse(_quantita.text.trim());
    }
    Navigator.of(context).pop(dati);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_modifica ? "Modifica prodotto" : "Nuovo prodotto"),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _chiaveForm,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nome,
                  decoration: InputDecoration(labelText: "Nome *"),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? "Il nome è obbligatorio"
                      : null,
                ),
                TextFormField(
                  controller: _brand,
                  decoration: InputDecoration(labelText: "Marca"),
                ),
                TextFormField(
                  controller: _descrizione,
                  decoration: InputDecoration(labelText: "Descrizione"),
                  maxLines: 3,
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _prezzo,
                        decoration: InputDecoration(labelText: "Prezzo (€) *"),
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          double? prezzo = leggiImporto(v ?? "");
                          return !importoValido(v ?? "") ||
                                  prezzo == null ||
                                  prezzo <= 0
                              ? "Prezzo non valido (max 2 decimali)"
                              : null;
                        },
                      ),
                    ),
                    if (!_modifica) ...[
                      SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _quantita,
                          decoration: InputDecoration(labelText: "Quantità *"),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            int? quantita = int.tryParse((v ?? "").trim());
                            return quantita == null || quantita < 0
                                ? "Quantità non valida"
                                : null;
                          },
                        ),
                      ),
                    ],
                  ],
                ),
                DropdownButtonFormField<String>(
                  initialValue: _categoria,
                  decoration: InputDecoration(labelText: "Categoria *"),
                  items: CATEGORIE.entries
                      .map(
                        (e) => DropdownMenuItem<String>(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (valore) {
                    setState(() {
                      _categoria = valore;
                    });
                  },
                  validator: (v) => v == null ? "Scegli una categoria" : null,
                ),
                TextFormField(
                  controller: _urlImmagine,
                  decoration: InputDecoration(
                    labelText: "URL immagine (http://... o https://...)",
                  ),
                  validator: (v) {
                    String url = (v ?? "").trim();
                    return url.isEmpty || RegExp(r'^https?://.+').hasMatch(url)
                        ? null
                        : "Deve iniziare con http:// o https://";
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text("Annulla"),
        ),
        FilledButton(
          onPressed: _conferma,
          child: Text(_modifica ? "Salva" : "Crea"),
        ),
      ],
    );
  }
}

/// Form "Nuova asta" (campi di CreaAstaRequest): restituisce la Map per il backend, o null se si annulla.
class _FormAsta extends StatefulWidget {
  final List<ProdottoAdmin> prodotti;

  _FormAsta({required this.prodotti});

  @override
  _FormAstaState createState() => _FormAstaState();
}

class _FormAstaState extends State<_FormAsta> {
  final GlobalKey<FormState> _chiaveForm = GlobalKey<FormState>();
  TextEditingController _prezzoBase = TextEditingController();
  int? _codiceProdotto;
  DateTime? _dataInizio; // null = l'asta parte subito
  DateTime? _dataFine;
  String? _erroreDate;
  TextEditingController _ricerca = TextEditingController();
  String _filtro = "";

  @override
  void dispose() {
    _prezzoBase.dispose();
    _ricerca.dispose();
    super.dispose();
  }

  /// Fa scegliere prima il giorno e poi l'ora. null se l'utente annulla.
  Future<DateTime?> _scegliDataOra(DateTime? iniziale) async {
    DateTime adesso = DateTime.now();
    DateTime base = iniziale ?? adesso.add(Duration(hours: 1));
    DateTime? giorno = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(adesso.year, adesso.month, adesso.day),
      lastDate: adesso.add(Duration(days: 365)),
    );
    if (giorno == null || !mounted) return null;
    TimeOfDay? ora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (ora == null) return null;
    return DateTime(
      giorno.year,
      giorno.month,
      giorno.day,
      ora.hour,
      ora.minute,
    );
  }

  void _conferma() {
    bool campiValidi = _chiaveForm.currentState!.validate();
    DateTime adesso = DateTime.now();
    DateTime? inizio = _dataInizio;
    DateTime? fine = _dataFine;
    String? errore;
    if (fine == null) {
      errore = "Scegli la data di fine.";
    } else if (!fine.isAfter(adesso)) {
      errore = "La fine deve essere nel futuro.";
    } else if (inizio != null && !inizio.isAfter(adesso)) {
      errore =
          "L'inizio deve essere nel futuro (oppure lascialo vuoto per partire subito).";
    } else if (inizio != null && !fine.isAfter(inizio)) {
      errore = "La fine deve essere dopo l'inizio.";
    }
    setState(() {
      _erroreDate = errore;
    });
    if (!campiValidi || errore != null || fine == null) return;
    Navigator.of(context).pop(<String, dynamic>{
      "codiceProdotto": _codiceProdotto,
      "prezzoBase": leggiImporto(_prezzoBase.text),
      "dataInizio": inizio == null ? null : dataPerBackend(inizio),
      "dataFine": dataPerBackend(fine),
    });
  }

  @override
  Widget build(BuildContext context) {
    ThemeData tema = Theme.of(context);
    // il prodotto già scelto resta sempre nell'elenco, altrimenti la tendina andrebbe in errore
    List<ProdottoAdmin> elenco = widget.prodotti
        .where((p) => p.prodotto.codiceProdotto == _codiceProdotto || p.prodotto.nome.toLowerCase().contains(_filtro))
        .toList();
    return AlertDialog(
      title: Text("Nuova asta"),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _chiaveForm,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.prodotti.isEmpty)
                  Text(
                    "Nessun prodotto adatto: servono pezzi disponibili e nessuna asta già aperta sul prodotto.",
                    style: TextStyle(color: tema.colorScheme.error),
                  ),
                TextField(
                  controller: _ricerca,
                  decoration: InputDecoration(
                    labelText: "Cerca prodotto (${widget.prodotti.length} disponibili)",
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (testo) => setState(() => _filtro = testo.trim().toLowerCase()),
                ),
                DropdownButtonFormField<int>(
                  initialValue: _codiceProdotto,
                  isExpanded: true,
                  itemHeight: 56,
                  decoration: InputDecoration(labelText: "Prodotto *"),
                  items: elenco
                      .map(
                        (pa) => DropdownMenuItem<int>(
                          value: pa.prodotto.codiceProdotto,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 40,
                                height: 40,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: ImmagineProdotto(url: pa.prodotto.urlImmagine, altezza: 40),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(pa.prodotto.nome, overflow: TextOverflow.ellipsis),
                              ),
                              SizedBox(width: 8),
                              Text(
                                "${pa.quantita} pz${pa.visibile ? ' · in catalogo' : ''}",
                                style: tema.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (valore) {
                    setState(() {
                      _codiceProdotto = valore;
                    });
                  },
                  validator: (v) => v == null ? "Scegli un prodotto" : null,
                ),
                TextFormField(
                  controller: _prezzoBase,
                  decoration: InputDecoration(labelText: "Prezzo base (€) *"),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    double? prezzo = leggiImporto(v ?? "");
                    return !importoValido(v ?? "") ||
                            prezzo == null ||
                            prezzo <= 0
                        ? "Prezzo non valido (max 2 decimali)"
                        : null;
                  },
                ),
                SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.play_circle_outline),
                  title: Text("Inizio"),
                  subtitle: Text(
                    _dataInizio == null
                        ? "Subito"
                        : formattaDataOra(_dataInizio!),
                  ),
                  trailing: Wrap(
                    children: [
                      if (_dataInizio != null)
                        IconButton(
                          tooltip: "Parti subito",
                          onPressed: () => setState(() => _dataInizio = null),
                          icon: Icon(Icons.clear),
                        ),
                      TextButton(
                        onPressed: () async {
                          DateTime? scelta = await _scegliDataOra(_dataInizio);
                          if (scelta != null)
                            setState(() => _dataInizio = scelta);
                        },
                        child: Text("Scegli"),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.flag_outlined),
                  title: Text("Fine *"),
                  subtitle: Text(
                    _dataFine == null
                        ? "Da scegliere"
                        : formattaDataOra(_dataFine!),
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      DateTime? scelta = await _scegliDataOra(_dataFine);
                      if (scelta != null) setState(() => _dataFine = scelta);
                    },
                    child: Text("Scegli"),
                  ),
                ),
                if (_erroreDate != null)
                  Text(
                    _erroreDate!,
                    style: TextStyle(color: tema.colorScheme.error),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text("Annulla"),
        ),
        FilledButton(onPressed: _conferma, child: Text("Crea")),
      ],
    );
  }
}
