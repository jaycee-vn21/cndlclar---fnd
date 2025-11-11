import 'package:flutter/material.dart';
import 'package:cndlclar/models/token.dart';
import 'package:cndlclar/utils/constants.dart';
import 'package:cndlclar/widgets/token_list_view_section.dart';

class IndividualTokenScreen extends StatelessWidget {
  final Token token;

  final VoidCallback onBuyPressed;
  final VoidCallback onQuickBuyPressed;
  final VoidCallback onSellPressed;

  const IndividualTokenScreen({
    super.key,
    required this.token,
    required this.onBuyPressed,
    required this.onQuickBuyPressed,
    required this.onSellPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColors.background,
      appBar: AppBar(
        title: Text(token.name, style: KTextStyles.appBarTitle),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
      ),
      body: TokenListViewSection(
        showList: false,
        singleToken: token,
        onBuyPressed: (_) => onBuyPressed(),
        onQuickBuyPressed: (_) => onQuickBuyPressed(),
        onSellPressed: (_) => onSellPressed(),
      ),
    );
  }
}
