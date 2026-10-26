import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/proxo_design_tokens.dart';
import 'proxo_symbol.dart';

/// Licensed, original PNG artwork. Alpha bounds normalize visible ink, rather
/// than treating transparent padding as part of an icon's perceived size.
/// Source, licence, hashes and measured bounds: assets/icons/proxo_png/.
class ProxoPngIcon extends StatelessWidget {
  const ProxoPngIcon(this.symbol,
      {super.key,
      this.size = ProxoDesign.iconSize,
      this.color,
      this.semanticLabel});
  final ProxoSymbolName symbol;
  final double size;
  final Color? color;
  final String? semanticLabel;
  static const _assets = <ProxoSymbolName, _PngAsset>{
    ProxoSymbolName.home: _PngAsset('home-2', Rect.fromLTRB(0, 10, 240, 240)),
    ProxoSymbolName.ads:
        _PngAsset('megaphone-2', Rect.fromLTRB(0, 30, 240, 220)),
    ProxoSymbolName.tools: _PngAsset('file-20', Rect.fromLTRB(20, 0, 220, 240)),
    ProxoSymbolName.user: _PngAsset('user-6', Rect.fromLTRB(0, 0, 240, 240)),
    ProxoSymbolName.bell: _PngAsset('bell-2', Rect.fromLTRB(20, 0, 220, 240)),
    ProxoSymbolName.wallet:
        _PngAsset('banknote-2', Rect.fromLTRB(0, 50, 240, 190)),
    ProxoSymbolName.history: _PngAsset('time-3', Rect.fromLTRB(0, 0, 240, 240)),
    ProxoSymbolName.settings:
        _PngAsset('gear-2', Rect.fromLTRB(0, 0, 240, 240)),
    ProxoSymbolName.help: _PngAsset('help-3', Rect.fromLTRB(0, 0, 240, 240)),
    ProxoSymbolName.logout:
        _PngAsset('log-out-2', Rect.fromLTRB(0, 20, 240, 220)),
    ProxoSymbolName.discount: _PngAsset('tag-2', Rect.fromLTRB(0, 0, 240, 240)),
    ProxoSymbolName.info: _PngAsset('info-2', Rect.fromLTRB(0, 0, 240, 240)),
    ProxoSymbolName.lock: _PngAsset('lock-6', Rect.fromLTRB(30, 0, 210, 240)),
    ProxoSymbolName.verified:
        _PngAsset('shield-20', Rect.fromLTRB(30, 0, 210, 240)),
    ProxoSymbolName.email: _PngAsset('email-2', Rect.fromLTRB(0, 30, 240, 210)),
    ProxoSymbolName.phone:
        _PngAsset('smartphone-3', Rect.fromLTRB(50, 0, 190, 240)),
    ProxoSymbolName.chat:
        _PngAsset('speech-bubble-18', Rect.fromLTRB(0, 10, 240, 230)),
    ProxoSymbolName.document:
        _PngAsset('file-20', Rect.fromLTRB(20, 0, 220, 240)),
    ProxoSymbolName.trash:
        _PngAsset('trash-can-2', Rect.fromLTRB(20, 0, 220, 240)),
    ProxoSymbolName.edit: _PngAsset('pencil-9', Rect.fromLTRB(0, 0, 240, 240)),
    ProxoSymbolName.language:
        _PngAsset('globe-2', Rect.fromLTRB(0, 0, 240, 240)),
    ProxoSymbolName.refresh:
        _PngAsset('refresh-3', Rect.fromLTRB(0, 30, 240, 210)),
    ProxoSymbolName.download:
        _PngAsset('download-2', Rect.fromLTRB(30, 0, 210, 240)),
  };
  static bool supports(ProxoSymbolName symbol) => _assets.containsKey(symbol);
  @override
  Widget build(BuildContext context) {
    final asset = _assets[symbol];
    if (asset == null) {
      // Inline arrows, visibility and close controls retain the existing family.
      return ProxoSymbol(symbol,
          size: size, color: color, semanticLabel: semanticLabel);
    }
    final scale =
        size * (22 / 24) / math.max(asset.bounds.width, asset.bounds.height);
    // Decode close to the physical draw size. Android profile captures exposed
    // faint rectangular seams when the full-size PNG used mipmap filtering.
    final decodeSize =
        (240 * scale * MediaQuery.devicePixelRatioOf(context)).ceil();
    final art = SizedBox.square(
        dimension: size,
        child: Stack(clipBehavior: Clip.hardEdge, children: [
          Positioned(
              left: (size - asset.bounds.width * scale) / 2 -
                  asset.bounds.left * scale,
              top: (size - asset.bounds.height * scale) / 2 -
                  asset.bounds.top * scale,
              width: 240 * scale,
              height: 240 * scale,
              child: Image.asset('assets/icons/proxo_png/${asset.name}.png',
                  cacheWidth: decodeSize,
                  cacheHeight: decodeSize,
                  filterQuality: FilterQuality.low,
                  fit: BoxFit.fill,
                  color:
                      color ?? IconTheme.of(context).color ?? ProxoDesign.muted,
                  colorBlendMode: BlendMode.srcIn,
                  excludeFromSemantics: true)),
        ]));
    return Semantics(
        label: semanticLabel,
        excludeSemantics: semanticLabel == null,
        child: Transform.flip(
            flipX: symbol == ProxoSymbolName.logout &&
                Directionality.of(context) == TextDirection.rtl,
            child: Center(widthFactor: 1, heightFactor: 1, child: art)));
  }
}

class _PngAsset {
  const _PngAsset(this.name, this.bounds);
  final String name;
  final Rect bounds;
}
