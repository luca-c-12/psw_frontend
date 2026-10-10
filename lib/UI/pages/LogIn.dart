import 'package:flutter/material.dart';
import 'package:psw_frontend/UI/widgets/buttons/ExpandableLoginButton.dart';
import 'package:psw_frontend/UI/widgets/dialogs/MessageDialog.dart';
import 'package:psw_frontend/model/Model.dart';
import 'package:psw_frontend/model/support/Constants.dart';
import 'package:psw_frontend/model/support/LogInResult.dart';
import 'package:url_launcher/url_launcher.dart';


class LogIn extends StatefulWidget {
  LogIn() : super();

  @override
  _LogInState createState() => _LogInState();
}

class _LogInState extends State<LogIn> {
  bool _isLoading = false;


  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _isLoading ?
          Center(
            child: CircularProgressIndicator(),
          ) :
          Padding(padding: EdgeInsets.all(0)),
          IgnorePointer(
            ignoring: _isLoading,
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.fromLTRB(0, 10, 0, 20),
                      child: Text(
                        "Accedi",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 42, fontWeight: FontWeight.w300),
                      ),
                    ),
                    ExpandableLogInButton(
                      textOuterButton: "Accedi con il tuo account",
                      onSubmit: (String email, String password) async {
                        print("login: email='$email' password lunga ${password.length}");
                        setState(() {
                          _isLoading = true;
                        });
                        if ( email == "" || password == "" ) {
                          showDialog(
                            context: context,
                            builder: (context) => MessageDialog(
                              titleText: "Ops...",
                              bodyText: "Tutti i campi sono necessari!",
                            ),
                          );
                          setState(() {
                            _isLoading = false;
                          });
                          return;
                        }
                        LogInResult result = await Model.sharedInstance.logIn(email, password);
                        // dopo il login questa tab sparisce, quindi la pagina potrebbe non esistere più
                        if ( !mounted ) return;
                        setState(() {
                          _isLoading = false;
                        });
                        if ( result == LogInResult.logged ) {
                          // niente da fare: il Layout si aggiorna da solo
                        }
                        else if ( result == LogInResult.error_wrong_credentials ) {
                          showDialog(
                            context: context,
                            builder: (context) => MessageDialog(
                              titleText: "Ops...",
                              bodyText: "Utente o password errati!",
                            ),
                          );
                        }
                        else if ( result == LogInResult.error_not_fully_setupped ) {
                          await launchUrl(Uri.parse(Constants.LINK_ACCOUNT));
                        }
                        else {
                          showDialog(
                            context: context,
                            builder: (context) => MessageDialog(
                              titleText: "Ops...",
                              bodyText: "Errore sconosciuto!\n${Model.sharedInstance.ultimoErroreLogin ?? ''}",
                            ),
                          );
                        }
                      },
                    ),
                    // la registrazione si fa sulla pagina di Keycloak, che poi riporta qui
                    Padding(
                      padding: EdgeInsets.fromLTRB(0, 30, 0, 0),
                      child: Text("Non hai un account?"),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        launchUrl(Uri.parse(Constants.LINK_REGISTRAZIONE), webOnlyWindowName: "_self");
                      },
                      icon: Icon(Icons.person_add_alt_1_rounded),
                      label: Text("Registrati"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


}
