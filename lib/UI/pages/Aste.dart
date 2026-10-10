import 'package:flutter/material.dart';
import 'package:psw_frontend/UI/pages/DettaglioAsta.dart';
import 'package:psw_frontend/UI/widgets/Avvisi.dart';
import 'package:psw_frontend/UI/widgets/InputField.dart';
import 'package:psw_frontend/UI/widgets/ProductCard.dart';
import 'package:psw_frontend/UI/widgets/buttons/CircularIconButton.dart';
import 'package:psw_frontend/UI/widgets/buttons/StadiumButton.dart';
import 'package:psw_frontend/model/Model.dart';
import 'package:psw_frontend/model/objects/Asta.dart';
import 'package:psw_frontend/model/objects/Pagina.dart';
import 'package:psw_frontend/model/objects/Prodotto.dart';
import 'package:psw_frontend/model/support/Formati.dart';


/// Elenco delle aste in corso (con ricerca per nome e categoria) oppure programmate.
class Aste extends StatefulWidget {
  Aste() : super();

  @override
  _AsteState createState() => _AsteState();
}

class _AsteState extends State<Aste> with AzioniPagina<Aste> {
  List<Asta> _aste = [];
  int _pagina = 0;
  bool _ultima = true;
  bool _caricamento = false;
  bool _programmate = false;    // false = aste in corso, true = aste programmate
  String? _categoria;
  TextEditingController _cerca = TextEditingController();
  String _nomeCercato = "";     // il testo dell'ultima ricerca, usato anche da "Carica altre"


  @override
  void initState() {
    super.initState();
    _carica(daCapo: true);
  }

  @override
  void dispose() {
    _cerca.dispose();
    super.dispose();
  }

  /// Carica una pagina di aste; i filtri valgono solo per quelle in corso.
  Future<void> _carica({bool daCapo = true}) async {
    if (_caricamento) return;
    if (daCapo) {
      setState(() {
        _pagina = 0;
        _aste.clear();
        _ultima = true;
        _nomeCercato = _cerca.text;
      });
    }
    await esegui(() async {
      Pagina<Asta> p = await Model.sharedInstance.getAste(_programmate, _pagina, nome: _nomeCercato, categoria: _categoria);
      if (!mounted) return;
      setState(() {
        _aste.addAll(p.contenuto);
        _ultima = p.ultima;
        _pagina++;
      });
    }, imposta: (v) => _caricamento = v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text("In corso"), icon: Icon(Icons.timer_outlined)),
                ButtonSegment(value: true, label: Text("Programmate"), icon: Icon(Icons.event_outlined)),
              ],
              selected: {_programmate},
              // disattivato durante il caricamento, così i risultati dei due elenchi non si mescolano
              onSelectionChanged: _caricamento
                  ? null
                  : (Set<bool> scelta) {
                      setState(() {
                        _programmate = scelta.first;
                      });
                      _carica(daCapo: true);
                    },
            ),
          ),
          if (!_programmate) _filtri(),
          SizedBox(height: 8),
          Expanded(
            child: _elenco(),
          ),
        ],
      ),
    );
  }

  Widget _filtri() {
    return Padding(
      padding: EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: Row(
        children: [
          Flexible(
            child: InputField(
              labelText: "Cerca per nome",
              controller: _cerca,
              onSubmit: (value) {
                if (!_caricamento) _carica(daCapo: true);
              },
            ),
          ),
          DropdownButton<String?>(
            value: _categoria,
            hint: Text("Tutte le categorie"),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text("Tutte le categorie"),
              ),
              ...CATEGORIE.entries.map(
                (e) => DropdownMenuItem<String?>(
                  value: e.key,
                  child: Text(e.value),
                ),
              ),
            ],
            onChanged: _caricamento
                ? null
                : (valore) {
                    setState(() {
                      _categoria = valore;
                    });
                    _carica(daCapo: true);
                  },
          ),
          CircularIconButton(
            icon: Icons.search_rounded,
            onPressed: _caricamento
                ? null
                : () {
                    _carica(daCapo: true);
                  },
          ),
        ],
      ),
    );
  }

  Widget _elenco() {
    if (_aste.isEmpty) {
      return Center(
        child: _caricamento
            ? CircularProgressIndicator()
            : Text(_programmate ? "Nessuna asta programmata." : "Nessuna asta in corso."),
      );
    }
    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 240,
              childAspectRatio: 0.66,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _aste.length,
            itemBuilder: (context, index) {
              Asta asta = _aste[index];
              return ProductCard(
                product: asta.prodotto,
                prezzo: asta.prezzoCorrente,
                mostraDisponibilita: false,
                etichetta: _programmate
                    ? "Inizia il ${formattaDataOra(asta.dataInizio)}"
                    : "Termina il ${formattaDataOra(asta.dataFine)}",
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => DettaglioAsta(asta: asta)),
                  );
                },
              );
            },
          ),
        ),
        if (!_ultima)
          StadiumButton(
            title: "Carica altre",
            icon: Icons.expand_more_rounded,
            disabled: _caricamento,
            onPressed: () {
              _carica(daCapo: false);
            },
          ),
      ],
    );
  }


}
