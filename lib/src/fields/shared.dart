import 'package:flutter/material.dart';

class CustomErrorText extends StatelessWidget {
  const CustomErrorText({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5, bottom: 5),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .bodyMedium!
            .apply(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
