import 'package:flutter/material.dart';
import 'package:psw_frontend/model/support/Constants.dart';
import 'package:url_launcher/url_launcher.dart';

/// Piè di pagina con copyright, informazioni sul progetto e contatti.
/// Va messo come ultimo elemento del contenuto scorrevole di una pagina. I testi sono in Constants.
class Footer extends StatelessWidget {
  Footer() : super();

  @override
  Widget build(BuildContext context) {
    ThemeData tema = Theme.of(context);
    TextStyle? stile = tema.textTheme.bodySmall?.copyWith(
      color: tema.colorScheme.onSurfaceVariant,
    );
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 32),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tema.colorScheme.outlineVariant)),
      ),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                "© ${DateTime.now().year} ${Constants.APP_NAME} · ${Constants.FOOTER_AUTORE}",
                style: stile,
              ),
              _link(context, Icons.code_rounded, "GitHub", Constants.LINK_GITHUB),
            /*  _link(
                context,
                Icons.mail_outline_rounded,
                Constants.FOOTER_EMAIL,
                "mailto:${Constants.FOOTER_EMAIL}",
              ), */
            ],
          ),
          SizedBox(height: 4),
          Text(
            "Negozio dimostrativo: prodotti, pagamenti e spedizioni non sono reali.",
            style: stile,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _link(BuildContext context, IconData icona, String testo, String indirizzo) {
    return TextButton.icon(
      onPressed: () => launchUrl(Uri.parse(indirizzo)),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        textStyle: Theme.of(context).textTheme.bodySmall,
      ),
      icon: Icon(icona, size: 16),
      label: Text(testo),
    );
  }
}
