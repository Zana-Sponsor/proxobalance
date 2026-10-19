import 'package:solar_icons/solar_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Original Solar Outline artwork by 480 Design, CC BY 4.0.
/// See assets/icons/solar/SOURCES.json. All assets are bundled; no network I/O.
enum ProxoSymbolName {
  home('home_2'),
  ads('clapperboard_play'),
  tools('widget_2'),
  user('user_rounded'),
  signup('user_plus_rounded'),
  login('login_2'),
  password('lock_password'),
  lock('lock_keyhole'),
  recovery('key'),
  verified('shield_check'),
  email('letter'),
  phone('phone'),
  eye('eye'),
  eyeClosed('eye_closed'),
  add('add_circle'),
  back('alt_arrow_right'),
  forward('alt_arrow_left'),
  menu('hamburger_menu'),
  bell('bell'),
  search('magnifer'),
  wallet('wallet_2'),
  gallery('gallery_add'),
  upload('upload'),
  history('history'),
  settings('settings'),
  help('question_circle'),
  logout('logout_2'),
  discount('tag_price'),
  check('check_circle'),
  close('close_circle'),
  info('info_circle'),
  warning('danger_circle'),
  language('global'),
  copy('copy'),
  graph('chart_square'),
  trophy('cup_star'),
  target('target'),
  click('cursor_square'),
  refresh('refresh'),
  play('play_circle'),
  chevronDown('alt_arrow_down'),
  camera('camera'),
  download('download');

  const ProxoSymbolName(this.file);
  final String file;
}

class ProxoSymbol extends StatelessWidget {
  const ProxoSymbol(this.symbol,
      {super.key,
      this.size = 24,
      this.color,
      this.semanticLabel,
      this.mirrorInRtl = false});
  final ProxoSymbolName symbol;
  final double size;
  final Color? color;
  final String? semanticLabel;
  final bool mirrorInRtl;

  @override
  Widget build(BuildContext context) => Center(
        // Like Icon, keep the painted glyph at `size` inside a larger tap target.
        // SVG width/height alone are overridden by a tight 40/48dp parent.
        widthFactor: 1,
        heightFactor: 1,
        child: SvgPicture.asset(
          'assets/icons/solar/${symbol.file}.svg',
          width: size,
          height: size,
          fit: BoxFit.contain,
          colorFilter: ColorFilter.mode(
              color ?? IconTheme.of(context).color ?? const Color(0xFF64748B),
              BlendMode.srcIn),
          semanticsLabel: semanticLabel,
          excludeFromSemantics: semanticLabel == null,
          matchTextDirection: mirrorInRtl,
        ),
      );
}

/// Preserve suitable Solar Outline glyphs while selected shared controls use
/// the locally bundled original vectors. Both render the same icon family.
class ProxoSolarIcon extends StatelessWidget {
  const ProxoSolarIcon(this.icon, {super.key, this.size = 24, this.color});
  final IconData icon;
  final double size;
  final Color? color;
  static final symbols = <IconData, ProxoSymbolName>{
    SolarIconsOutline.checkCircle: ProxoSymbolName.check,
    SolarIconsOutline.copy: ProxoSymbolName.copy,
    SolarIconsOutline.home2: ProxoSymbolName.home,
    SolarIconsOutline.clapperboardPlay: ProxoSymbolName.ads,
    SolarIconsOutline.widget_2: ProxoSymbolName.tools,
    SolarIconsOutline.userRounded: ProxoSymbolName.user,
    SolarIconsOutline.history: ProxoSymbolName.history,
    SolarIconsOutline.tagPrice: ProxoSymbolName.discount,
    SolarIconsOutline.wallet2: ProxoSymbolName.wallet,
    SolarIconsOutline.bell: ProxoSymbolName.bell,
    SolarIconsOutline.settings: ProxoSymbolName.settings,
    SolarIconsOutline.questionCircle: ProxoSymbolName.help,
    SolarIconsOutline.logout: ProxoSymbolName.logout,
    SolarIconsOutline.altArrowRight: ProxoSymbolName.back,
    SolarIconsOutline.altArrowLeft: ProxoSymbolName.forward,
    SolarIconsOutline.hamburgerMenu: ProxoSymbolName.menu,
    SolarIconsOutline.magnifier: ProxoSymbolName.search,
    SolarIconsOutline.eye: ProxoSymbolName.eye,
    SolarIconsOutline.eyeClosed: ProxoSymbolName.eyeClosed,
    SolarIconsOutline.letter: ProxoSymbolName.email,
    SolarIconsOutline.lock: ProxoSymbolName.lock,
    SolarIconsOutline.smartphone: ProxoSymbolName.phone,
  };
  @override
  Widget build(BuildContext context) {
    final symbol = symbols[icon];
    return symbol == null
        ? Icon(icon, size: size, color: color)
        : ProxoSymbol(symbol, size: size, color: color);
  }
}
