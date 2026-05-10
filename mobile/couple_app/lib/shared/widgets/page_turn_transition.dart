// ignore_for_file: prefer_const_constructors_in_immutables
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';

/// go_router page transition — yumuşak fade + hafif yatay translate.
/// "Sayfa çevirme"yi simüle eden minimal hareket; agresif rotateY
/// kullanmıyoruz çünkü modal/keyboard ile aksaklık verir.
class PageTurnPage<T> extends CustomTransitionPage<T> {
  PageTurnPage({
    required super.child,
    super.key,
    super.name,
  }) : super(
          transitionDuration: AppMotion.pageTurn,
          reverseTransitionDuration: AppMotion.med,
          transitionsBuilder: _builder,
        );

  static Widget _builder(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final fadeIn = CurvedAnimation(parent: animation, curve: AppMotion.curveOut);
    final slide = Tween<Offset>(
      begin: const Offset(0.04, 0.02),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: AppMotion.curve));
    final fadeOut = Tween<double>(begin: 1, end: 0.92).animate(
      CurvedAnimation(parent: secondaryAnimation, curve: AppMotion.curve),
    );

    return FadeTransition(
      opacity: fadeIn,
      child: FadeTransition(
        opacity: fadeOut,
        child: SlideTransition(position: slide, child: child),
      ),
    );
  }
}
