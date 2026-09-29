import 'package:flutter/material.dart';
import '../theme/jetons.dart';

/// Fait entrer un élément : il monte de quelques pixels en apparaissant.
///
/// Posé sur plusieurs éléments avec des `ordre` croissants, il les fait
/// arriver **l'un après l'autre** (`Mouvement.cascade` entre deux) — l'œil
/// suit l'ordre de lecture au lieu de recevoir l'écran d'un bloc.
///
/// Le délai n'est pas un minuteur : c'est le début d'une `Interval` sur une
/// seule animation. Un minuteur en attente à la fin d'un test Flutter le fait
/// échouer, et un écran quitté avant l'échéance le déclencherait dans le
/// vide.
///
/// En mouvement réduit, l'élément est posé d'emblée.
class Apparition extends StatefulWidget {
  const Apparition({
    super.key,
    required this.child,
    this.ordre = 0,
    this.decalage = 14,
  });

  final Widget child;

  /// Rang dans la cascade : 0 entre tout de suite, 1 après un pas, etc.
  final int ordre;

  /// De combien de pixels l'élément monte en entrant.
  final double decalage;

  @override
  State<Apparition> createState() => _ApparitionState();
}

class _ApparitionState extends State<Apparition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controleur;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();

    final attente = Mouvement.cascade * widget.ordre;
    final total = attente + Mouvement.ample;

    _controleur = AnimationController(vsync: this, duration: total);
    _t = CurvedAnimation(
      parent: _controleur,
      curve: Interval(
        attente.inMicroseconds / total.inMicroseconds,
        1,
        curve: Mouvement.courbeDouce,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Ici et non dans `initState` : `MediaQuery` n'y est pas encore lisible.
    if (_controleur.status == AnimationStatus.dismissed) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controleur.value = 1;
      } else {
        _controleur.forward();
      }
    }
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, enfant) => Opacity(
        opacity: _t.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, widget.decalage * (1 - _t.value)),
          child: enfant,
        ),
      ),
      child: widget.child,
    );
  }
}
