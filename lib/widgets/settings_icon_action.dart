import 'package:flutter/material.dart';
import 'package:daily_you/widgets/glass_container.dart';

class SettingsIconAction extends StatelessWidget {
  final String title;
  final String? hint;
  final Icon icon;
  final Icon? secondaryIcon;
  final Function() onPressed;
  final Function()? onSecondaryPressed;

  const SettingsIconAction(
      {super.key,
      required this.title,
      this.hint,
      required this.icon,
      this.secondaryIcon,
      required this.onPressed,
      this.onSecondaryPressed});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      margin: const EdgeInsets.only(top: 8.0, bottom: 8.0),
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0, left: 16.0, right: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                if (hint != null)
                  Text(
                    hint!,
                    style: TextStyle(fontSize: 14),
                  ),
              ],
            ),
          ),
          IconButton(onPressed: onPressed, icon: icon),
          if (secondaryIcon != null && onSecondaryPressed != null)
            IconButton(onPressed: onSecondaryPressed, icon: secondaryIcon!)
        ],
      ),
    );
  }
}
