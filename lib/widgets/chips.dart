import 'package:flutter/material.dart';
import '../theme/tokens.dart';

class StatusChip extends StatelessWidget{
  const StatusChip(this.text,{super.key, this.tone='info'});
  final String text; final String tone;
  Color get color => switch(tone){
    'success'=> AppColors.brandPrimary,
    'warn'   => AppColors.warn,
    'danger' => AppColors.danger,
    _        => AppColors.info,
  };
  @override Widget build(BuildContext context){
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}
