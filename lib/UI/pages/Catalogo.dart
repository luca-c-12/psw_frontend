import 'package:flutter/material.dart';
import 'package:psw_frontend/UI/pages/DettaglioProdotto.dart';
import 'package:psw_frontend/UI/widgets/Avvisi.dart';
import 'package:psw_frontend/UI/widgets/InputField.dart';
import 'package:psw_frontend/UI/widgets/ProductCard.dart';
import 'package:psw_frontend/UI/widgets/buttons/CircularIconButton.dart';
import 'package:psw_frontend/UI/widgets/buttons/StadiumButton.dart';
import 'package:psw_frontend/model/Model.dart';
import 'package:psw_frontend/model/objects/Pagina.dart';
import 'package:psw_frontend/model/objects/Prodotto.dart';

class Catalogo extends StatefulWidget {
  Catalogo() : super();

  @override
  _CatalogoState createState() => _CatalogoState();
}

class _CatalogoState extends State<Catalogo> with AzioniPagina<Catalogo>{
  bool _searching = false;

  List<Prodotto> _products = [];
  int _pagina = 0; // prossima pagina da chiedere al backend
  bool _ultima = true; // true = non ci sono altre pagine
  String? _categoria;

  TextEditingController _searchFiledController = TextEditingController();
  TextEditingController _searchByBrandController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search(daCapo: true);
  }

  @override
  void dispose() {
    _searchFiledController.dispose();
    _searchByBrandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          top(),
          Expanded(child: bottom()),
        ],
      ),
    );
  }

  Widget top() {
    return Padding(
      padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Row(
        children: [
          Flexible(
            child: InputField(
              labelText: "Cerca per nome",
              controller: _searchFiledController,
              onSubmit: (value) {
                _search(daCapo: true);
              },
            ),
          ),
          Flexible(
            child: InputField(
              labelText: "Marca",
              controller: _searchByBrandController,
              onSubmit: (value) {
                _search(daCapo: true);
              }
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
            onChanged: _searching
                ? null
                : (valore) {
                    setState(() {
                      _categoria = valore;
                    });
                    _search(daCapo: true);
                  },
          ),
          CircularIconButton(
            icon: Icons.search_rounded,
            onPressed: () {
              _search(daCapo: true);
            },
          ),
        ],
      ),
    );
  }

  Widget bottom() {
    if (_products.isEmpty) {
      return _searching
          ? Center(child: CircularProgressIndicator())
          : noResults();
    }
    return yesResults();
  }

  Widget noResults() {
    return Center(child: Text("Nessun prodotto trovato!"));
  }

  Widget yesResults() {
    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 240,
              childAspectRatio: 0.68,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _products.length,
            itemBuilder: (context, index) {
              return ProductCard(
                product: _products[index],
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          DettaglioProdotto(prodotto: _products[index]),
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (!_ultima)
          StadiumButton(
            title: "Carica altri",
            icon: Icons.expand_more_rounded,
            disabled: _searching,
            onPressed: () {
              _search(daCapo: false);
            },
          ),
      ],
    );
  }

  /// Carica una pagina di prodotti e la aggiunge alla griglia.
  ///   daCapo = true  → nuova ricerca (riparte dalla prima pagina)
  ///   daCapo = false → "Carica altri" (pagina successiva)
  Future<void> _search({bool daCapo = true}) async {
    if (_searching) return;
    if (daCapo) {
      setState(() {
        _pagina = 0;
        _products.clear();
        _ultima = true;
      });
    }
    await esegui(() async {
      Pagina<Prodotto> p = await Model.sharedInstance.cercaProdotti(
        _searchFiledController.text,
        _categoria,
        _searchByBrandController.text,
        _pagina,
      );
      if (!mounted) return;
      setState(() {
        _products.addAll(p.contenuto);
        _ultima = p.ultima;
        _pagina++;
      });
    }, imposta: (v) => _searching = v);
  }
}
