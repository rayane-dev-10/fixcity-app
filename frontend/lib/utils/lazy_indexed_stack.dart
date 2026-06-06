import 'package:flutter/material.dart';

class LazyIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  late List<bool> _activatedList;

  @override
  void initState() {
    super.initState();
    // Au démarrage, seul l'index initial (généralement 0) est activé
    _activatedList = List.generate(widget.children.length, (i) => i == widget.index);
  }

  @override
  void didUpdateWidget(LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Lorsqu'on change d'onglet, on active le nouvel index
    if (oldWidget.index != widget.index) {
      _activateIndex(widget.index);
    }
  }

  void _activateIndex(int index) {
    if (!_activatedList[index]) {
      setState(() {
        _activatedList[index] = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      children: List.generate(widget.children.length, (i) {
        // Si l'onglet a été visité au moins une fois, on construit le vrai widget
        if (_activatedList[i]) {
          return widget.children[i];
        } else {
          // Sinon, on renvoie une boîte vide qui ne déclenche aucun initState ni appel API
          return const SizedBox.shrink(); 
        }
      }),
    );
  }
}