import 'package:flutter/material.dart';
import 'package:psw_frontend/UI/pages/Admin.dart';
import 'package:psw_frontend/UI/pages/Aste.dart';
import 'package:psw_frontend/UI/pages/CarrelloPagina.dart';
import 'package:psw_frontend/UI/pages/Catalogo.dart';
import 'package:psw_frontend/UI/pages/LogIn.dart';
import 'package:psw_frontend/UI/pages/Profilo.dart';
import 'package:psw_frontend/model/Model.dart';
import 'package:psw_frontend/model/support/Constants.dart';


class Layout extends StatefulWidget {
  final String title;


  Layout({required this.title}) : super();

  @override
  _LayoutState createState() => _LayoutState(title);
}

class _LayoutState extends State<Layout> {
  late String title;


  _LayoutState(String title) {
    this.title = title;
  }


  @override
  Widget build(BuildContext context) {
    // le tab dipendono da chi è collegato:
    //   ospite: Catalogo | Aste | (Carrello) | Accedi    cliente: Catalogo | Aste | Carrello | Profilo
    //   admin:  Catalogo | Aste | Admin
    return ListenableBuilder(
      listenable: Model.sharedInstance,
      builder: (context, _) {
        Model model = Model.sharedInstance;
        List<Tab> tabs = [
          Tab(text: "Catalogo", icon: Icon(Icons.storefront_rounded)),
          Tab(text: "Aste", icon: Icon(Icons.gavel_rounded)),
        ];
        List<Widget> pagine = [
          Catalogo(),
          Aste(),
        ];
        if (model.cliente || (!model.loggato && Constants.CARRELLO_OSPITE)) {
          tabs.add(Tab(
            text: "Carrello",
            icon: Badge(
              isLabelVisible: model.articoliNelCarrello > 0,
              label: Text("${model.articoliNelCarrello}"),
              child: Icon(Icons.shopping_cart_rounded),
            ),
          ));
          pagine.add(CarrelloPagina());
        }
        if (model.cliente) {
          tabs.add(Tab(text: "Profilo", icon: Icon(Icons.person_rounded)));
          pagine.add(Profilo());
        }
        else if (model.admin) {
          tabs.add(Tab(text: "Admin", icon: Icon(Icons.admin_panel_settings_rounded)));
          pagine.add(Admin());
        }
        else if (!model.loggato) {
          tabs.add(Tab(text: "Accedi", icon: Icon(Icons.login_rounded)));
          pagine.add(LogIn());
        }
        return DefaultTabController(
          // cambia con il tipo di utente: le tab ripartono dalla prima
          key: ValueKey("${model.loggato}-${model.admin}"),
          length: tabs.length,
          child: Scaffold(
            appBar: AppBar(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(30),
                ),
              ),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              title: Row(
                children: [
                  Icon(Icons.shopping_bag_rounded),
                  SizedBox(width: 10),
                  Text(title),
                ],
              ),
              actions: [
                if (model.loggato) ...[
                  Center(child: Text("Ciao, ${model.nomeUtente ?? ''}")),
                  IconButton(
                    tooltip: "Esci",
                    icon: Icon(Icons.logout_rounded),
                    onPressed: () {
                      model.logOut();
                    },
                  ),
                ],
                SizedBox(width: 12),
              ],
              bottom: TabBar(
                tabs: tabs,
              ),
            ),
            body: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 1200),
                child: TabBarView(
                  children: pagine,
                ),
              ),
            ),
          ),
        );
      },
    );
  }


}
