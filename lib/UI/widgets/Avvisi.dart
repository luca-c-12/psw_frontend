import 'package:flutter/material.dart';
import 'package:psw_frontend/UI/widgets/dialogs/MessageDialog.dart';


/// Mostra un errore in una finestra. Per un ErroreApi compare il messaggio del backend.
void mostraErrore(BuildContext context, Object errore) {
  if (!context.mounted) return;
  showDialog(
    context: context,
    builder: (context) => MessageDialog(
      titleText: "Ops...",
      bodyText: errore.toString(),
    ),
  );
}

/// Mostra un messaggio breve in basso (es. "Aggiunto al carrello").
void mostraMessaggio(BuildContext context, String testo) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(testo), behavior: SnackBarBehavior.floating),
  );
}

/// Chiede conferma con una finestra "Annulla / Conferma". Restituisce true se l'utente conferma.
Future<bool> chiediConferma(BuildContext context, String domanda) async {
  bool? risposta = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text("Conferma"),
      content: Text(domanda),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text("Annulla"),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text("Conferma"),
        ),
      ],
    ),
  );
  return risposta ?? false;
}

/// Schema comune alle operazioni asincrone di una pagina: accende un indicatore, esegue l'operazione,
/// mostra il messaggio o l'errore, spegne l'indicatore.
///   class _XxxState extends State<Xxx> with AzioniPagina<Xxx> { ... }
///   esegui(() => Model.sharedInstance.rimuoviDalCarrello(codice), imposta: (v) => _invio = v);
mixin AzioniPagina<T extends StatefulWidget> on State<T> {

  /// [azione]     l'operazione; se dopo il suo await tocca la pagina, lo fa con "if (mounted)".
  /// [imposta]    accende/spegne l'indicatore della pagina, es. (v) => _invio = v.
  /// [messaggio]  mostrato solo se l'azione va a buon fine.
  /// [dopoErrore] chiamata dopo aver mostrato l'errore (es. per ricaricare i dati).
  Future<void> esegui(Future<void> Function() azione,
      {required void Function(bool) imposta, String? messaggio, VoidCallback? dopoErrore}) async {
    setState(() => imposta(true));
    try {
      await azione();
      if (!mounted) return;
      if (messaggio != null) {
        mostraMessaggio(context, messaggio);
      }
    } catch (e) {
      if (mounted) {
        mostraErrore(context, e);
        dopoErrore?.call();
      }
    } finally {
      if (mounted) {
        setState(() => imposta(false));
      }
    }
  }


}


/// Cinque stelle per scegliere un voto (se [onChanged] è null sono solo da leggere).
class StelleVoto extends StatelessWidget {
  final int voto;
  final ValueChanged<int>? onChanged;
  final double dimensione;


  StelleVoto({required this.voto, this.onChanged, this.dimensione = 30}) : super();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        Icon stella = Icon(
          i < voto ? Icons.star_rounded : Icons.star_outline_rounded,
          color: Colors.amber,
          size: dimensione,
        );
        if (onChanged == null) return stella;
        return IconButton(
          onPressed: () => onChanged!(i + 1),
          icon: stella,
        );
      }),
    );
  }


}
