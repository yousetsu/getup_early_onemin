import 'dart:io';

import 'package:google_mobile_ads/google_mobile_ads.dart';
// class AdState{
//   Future<InitializationStatus> initialization;
//   AdState(this.initialization);
//   String get bannerAdUnitId => Platform.isAndroid
//       ? '	ca-app-pub-3940256099942544/6300978111'
//       : 'ca-app-pub-8759269867859745/2745032231';
//
//   //AdListener get adListener => _adListener;
//
//   //AdListener _adListener = AdListener(
//     onAdLoaded: (ad) => print('Ad loaded: ${ad.adUnitID}'),
//     onAdClosed: (ad) => print('Ad closed: ${ad.adUnitID}'),
//     onFailedToLoad: (ad, error) =>
//           print('Ad faile to load: ${ad.adUnitID}, $error.')
//   );
//
// }