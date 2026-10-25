import 'package:flutter/material.dart';

/// App-wide roles from the approved TikTok Create Ad reference.
/// Logical pixels remain responsive to the user's text scaler.
abstract final class ProxoDesign {
  static const font = 'RabarAuthRegular';
  static const blue = Color(0xFF0278FE);
  static const blueSoft = Color(0xFFEEF7FF);
  static const blueInk = Color(0xFF2663B4);
  static const secondaryBlue = Color(0xFF3D7EC2);
  static const ink = Color(0xFF121215);
  static const muted = Color(0xFF747578);
  static const line = Color(0xFFEEEEEE);
  static const surface = Color(0xFFFFFFFF);
  static const softSurface = Color(0xFFF6F9FE);
  static const gutter = 20.0;
  static const maxWidth = 600.0;
  static const headingGap = 16.0;
  static const controlGap = 12.0;
  static const sectionGap = 32.0;
  static const cardPadding = 16.0;
  static const iconGap = 12.0;
  static const helperGap = 8.0;
  static const controlHeight = 50.0;
  static const fieldHeight = 56.0;
  static const toolbarHeight = 56.0;
  static const tapTarget = 48.0;
  static const radius = 12.0;
  static const cardRadius = 16.0;
  static const iconSize = 24.0;
  static const border = BorderRadius.all(Radius.circular(radius));
  static const transition = Duration(milliseconds: 180);
  static const shadow = [
    BoxShadow(color: Color(0x08000000), blurRadius: 5, offset: Offset(0, 2))
  ];
  static const appBar = TextStyle(
      fontFamily: font,
      fontSize: 18,
      fontWeight: FontWeight.w500,
      height: 1.5,
      color: ink);
  static const screenTitle = TextStyle(
      fontFamily: font,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.5,
      color: ink);
  static const heading = TextStyle(
      fontFamily: font,
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.5,
      color: ink);
  static const label = TextStyle(
      fontFamily: font,
      fontSize: 15,
      fontWeight: FontWeight.w500,
      height: 1.5,
      color: ink);
  static const field = TextStyle(
      fontFamily: font,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: ink);
  static const button = TextStyle(
      fontFamily: font,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.5,
      color: ink);
  static const body = TextStyle(
      fontFamily: font,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: ink);
  static const helper = TextStyle(
      fontFamily: font,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: muted);
  static const status = TextStyle(
      fontFamily: font,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      height: 1.5,
      color: muted);
  static const emptyTitle = heading;
  static const emptyDescription = helper;
  static const amount = TextStyle(
      fontFamily: font,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.5,
      color: blue);
}
