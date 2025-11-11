import 'package:flutter/material.dart';
import 'package:cndlclar/utils/constants.dart';

class TradingButtonsRowWidget extends StatefulWidget {
  final String tokenName;
  final VoidCallback onQuickBuy;
  final VoidCallback onBuy;
  final VoidCallback onSell;

  const TradingButtonsRowWidget({
    super.key,
    required this.tokenName,
    required this.onQuickBuy,
    required this.onBuy,
    required this.onSell,
  });

  @override
  State<TradingButtonsRowWidget> createState() =>
      _TradingButtonsRowWidgetState();
}

class _TradingButtonsRowWidgetState extends State<TradingButtonsRowWidget>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: KSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _AnimatedTradeButton(
            label: "Buy + OCO",
            gradient: KGradients.tradingBuy,
            onPressed: widget.onBuy,
          ),
          _AnimatedTradeButton(
            label: "Quick Buy",
            gradient: KGradients.tradingQuickBuy,
            onPressed: widget.onQuickBuy,
          ),
          _AnimatedTradeButton(
            label: "Sell",
            gradient: KGradients.tradingSell,
            onPressed: widget.onSell,
          ),
        ],
      ),
    );
  }
}

class _AnimatedTradeButton extends StatefulWidget {
  final String label;
  final Gradient gradient;
  final VoidCallback onPressed;

  const _AnimatedTradeButton({
    required this.label,
    required this.gradient,
    required this.onPressed,
  });

  @override
  State<_AnimatedTradeButton> createState() => _AnimatedTradeButtonState();
}

class _AnimatedTradeButtonState extends State<_AnimatedTradeButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.96 : 1.0,
      duration: KDurations.tradingPressAnimation,
      curve: Curves.easeOut,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          Future.delayed(const Duration(milliseconds: 60), widget.onPressed);
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: KDurations.tradingGlowAnimation,
          width: KSizes.tradingButtonMinWidth,
          height: KSizes.tradingButtonHeight,
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(
              KSizes.tradingButtonBorderRadius,
            ),
            boxShadow: _pressed ? [] : [KShadows.tradingButton],
          ),
          child: Center(
            child: Text(widget.label, style: KTextStyles.tradingButtonLabel),
          ),
        ),
      ),
    );
  }
}
