import 'package:flutter/material.dart';
import 'package:psw_frontend/model/objects/Prodotto.dart';
import 'package:psw_frontend/model/support/Formati.dart';


class ProductCard extends StatelessWidget {
  final Prodotto product;
  final VoidCallback? onTap;
  final double? prezzo;              // se diverso da quello del prodotto (es. offerta attuale di un'asta)
  final String? etichetta;           // riga in più sotto il prezzo (es. "Termina il ...")
  final bool mostraDisponibilita;


  ProductCard({required this.product, this.onTap, this.prezzo, this.etichetta, this.mostraDisponibilita = true}) : super();

  @override
  Widget build(BuildContext context) {
    ThemeData tema = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ImmagineProdotto(url: product.urlImmagine),
            ),
            Padding(
              padding: EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.nome,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tema.textTheme.titleSmall,
                  ),
                  if (product.brand != null)
                    Text(
                      product.brand!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                    ),
                  SizedBox(height: 6),
                  Text(
                    formattaEuro(prezzo ?? product.prezzo),
                    style: tema.textTheme.titleMedium?.copyWith(color: tema.colorScheme.primary, fontWeight: FontWeight.bold),
                  ),
                  if (etichetta != null)
                    Text(etichetta!, style: tema.textTheme.bodySmall),
                  if (mostraDisponibilita && !product.disponibile)
                    Text("Non disponibile", style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.error)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


}


/// Immagine di un prodotto, con un segnaposto se manca o non si carica.
class ImmagineProdotto extends StatelessWidget {
  final String? url;
  final double? altezza;


  ImmagineProdotto({this.url, this.altezza}) : super();

  @override
  Widget build(BuildContext context) {
    String? indirizzo = url;
    Widget segnaposto = Center(
      child: Icon(Icons.image_not_supported_outlined, size: 36, color: Theme.of(context).colorScheme.outline),
    );
    return Container(
      width: double.infinity,
      height: altezza,
      padding: EdgeInsets.all(4),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: indirizzo == null || indirizzo.isEmpty
          ? segnaposto
          : Image.network(
              indirizzo,
              fit: BoxFit.contain,
              // se il sito delle immagini non permette il CORS, il browser le mostra con un <img>
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              errorBuilder: (context, error, stackTrace) => segnaposto,
            ),
    );
  }


}
