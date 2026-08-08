import 'package:flutter/material.dart';

import '../theme.dart';

/// 品牌标识：蓝绿渐变圆角方块＋π。
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330B7E82),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        'π',
        style: TextStyle(
          fontSize: size * 0.52,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}
