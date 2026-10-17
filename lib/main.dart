import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mtg_table/app_state.dart';
import 'package:mtg_table/data/app_log.dart';
import 'package:mtg_table/data/repository.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/theme/app_theme.dart';
import 'package:mtg_table/ui/night/night_hub_screen.dart';
import 'package:mtg_table/ui/night/night_start_sheet.dart';
import 'package:mtg_table/ui/setup/first_player_draw.dart';
import 'package:mtg_table/ui/setup/setup_screen.dart';
import 'package:mtg_table/ui/sheets/privacy_sheet.dart';
import 'package:mtg_table/ui/stats/stats_screen.dart';
import 'package:mtg_table/ui/table/table_screen.dart';
import 'package:mtg_table/ui/tools/card_search_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    AppLog.error(
      'FlutterError',
      details.exception,
      details.stack,
    );
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLog.error('zone', error, stack);
    return true;
  };
  runApp(const TableMtgApp());
}

class TableMtgApp extends StatefulWidget {
  const TableMtgApp({super.key});

  @override
  State<TableMtgApp> createState() => _TableMtgAppState();
}

class _TableMtgAppState extends State<TableMtgApp> {
  final AppController _app = AppController(AppRepository());

  @override
  void initState() {
    super.initState();
    _app.boot();
  }

  @override
  void dispose() {
    _app.dispose();
    super.dispose();
  }

  Future<void> _openNightHub(BuildContext context) async {
    if (_app.night == null) {
      final created = await showCreateOrImportNightSheet(context);
      if (created == null) return;
      if (created.games.isEmpty && created.roster.isEmpty) {
        await _app.startNight(
          title: created.title,
          podCount: created.pods.isEmpty ? 2 : created.pods.length,
        );
      } else {
        await _app.importNight(created);
      }
    }
    if (!context.mounted || _app.night == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ListenableBuilder(
          listenable: _app,
          builder: (context, _) {
            final n = _app.night;
            if (n == null) {
              return const Scaffold(
                body: Center(child: Text('Soirée fermée')),
              );
            }
            return NightHubScreen(
              night: n,
              profiles: _app.profiles,
              settings: _app.settings,
              onChanged: _app.updateNight,
              onStartPod: (podId, game) async {
                await _app.startPodGame(game, podId: podId);
                if (context.mounted) Navigator.pop(context);
              },
              onResumePod: (podId) async {
                await _app.switchPod(podId);
                if (_app.match != null && context.mounted) {
                  Navigator.pop(context);
                }
              },
              onEndNight: _app.endNight,
              onClearNight: _app.clearNight,
              onImportNight: _app.importNight,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Table MTG',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // RGAA : respecter l’agrandissement système, sans casser la table.
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final scale = media.textScaler.clamp(
          minScaleFactor: 1.0,
          maxScaleFactor: 1.6,
        );
        return MediaQuery(
          data: media.copyWith(textScaler: scale),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: ListenableBuilder(
        listenable: _app,
        builder: (context, _) {
          if (!_app.ready) {
            return const Scaffold(
              body: Center(
                child: Text(
                  'Table MTG',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
              ),
            );
          }
          final match = _app.match;
          if (match == null) {
            return SetupScreen(
              settings: _app.settings,
              group: _app.group,
              resumeLabel: _app.resumeLabel,
              nightLabel: _app.night == null
                  ? null
                  : 'Soirée · ${_app.night!.code}',
              profiles: _app.profiles,
              onSaveProfile: _app.upsertProfile,
              onStart: _app.start,
              onResume: _app.resume,
              onOpenSearch: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CardSearchScreen(),
                  ),
                );
              },
              onOpenStats: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ListenableBuilder(
                      listenable: _app,
                      builder: (context, _) => StatsScreen(
                        ledger: _app.ledger,
                        onClear: _app.clearLedger,
                      ),
                    ),
                  ),
                );
              },
              onOpenNight: () => _openNightHub(context),
              onOpenPrivacy: () {
                showPrivacySheet(
                  context,
                  onWipeAll: _app.wipeAllLocalData,
                  onClearCacheOnly: _app.repo.clearCardCache,
                );
              },
              onImportSession: _app.openSession,
            );
          }
          if (_app.awaitingFirstPlayer) {
            return FirstPlayerDraw(
              players: match.game.players,
              onPicked: (index) {
                _app.confirmFirstPlayer(index);
                if (match.game.format == MatchFormat.treachery) {
                  match.dealTreacheryRoles();
                }
              },
              onSkip: () {
                _app.skipFirstPlayerDraw();
                if (match.game.format == MatchFormat.treachery) {
                  match.dealTreacheryRoles();
                }
              },
            );
          }
          return TableScreen(
            controller: match,
            settings: _app.settings,
            onSettings: _app.updateSettings,
            onLeave: () {
              _app.park();
            },
            onCoachDismissed: () {
              _app.updateSettings(_app.settings.copyWith(coachSeen: true));
            },
            onArchiveWin: () => _app.archiveCurrentGame(),
          );
        },
      ),
    );
  }
}
