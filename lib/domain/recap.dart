import 'package:mtg_table/domain/game_controller.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/domain/stats.dart';

/// Texte de récap partageable en fin de partie.
String buildGameRecap({
  required Game game,
  required Duration duration,
  List<String> lifeFeed = const [],
}) {
  final standing = game.alive;
  final winner = game.winnerLabel();
  final buf = StringBuffer();
  buf.writeln('📜 Récap LifeStack');
  buf.writeln(formatInfo(game.format).label);
  buf.writeln(
    'Durée · ${_formatDuration(duration)} · manche ${game.roundNumber}',
  );
  if (winner != null) {
    buf.writeln('Vainqueur · $winner');
  } else {
    final names = standing.map((p) => p.name).join(', ');
    buf.writeln('Fin · ${names.isEmpty ? '—' : names}');
  }
  buf.writeln('');
  buf.writeln('Table :');
  for (final player in game.players) {
    final cmds = player.commanders.map((c) => c.name).join(' / ');
    final defeated = game.isDefeated(player);
    final status = defeated ? 'éliminé' : '${player.life} PV';
    final cmdBit = cmds.isEmpty ? '' : ' ($cmds)';
    final poisonBit = player.poison > 0 ? ' · poison ${player.poison}' : '';
    final lethal = defeated ? game.lethalBanner(player) : null;
    final reasonBit = lethal == null ? '' : ' · $lethal';
    buf.writeln('• ${player.name}$cmdBit · $status$poisonBit$reasonBit');
  }
  if (game.planechase) {
    buf.writeln('');
    buf.writeln('Plan · ${game.currentPlane}');
  }
  if (game.archenemy) {
    buf.writeln('Stratagème · ${game.currentScheme}');
  }
  if (game.bounty) {
    buf.writeln('Prime · ${game.currentBounty.name}');
  }
  if (lifeFeed.isNotEmpty) {
    buf.writeln('');
    buf.writeln('Derniers coups :');
    for (final line in lifeFeed.take(8)) {
      buf.writeln('· $line');
    }
  }
  buf.writeln('');
  buf.writeln('— LifeStack · sans pub, local');
  return buf.toString();
}

String buildArchivedRecap(ArchivedGame game) {
  final buf = StringBuffer();
  buf.writeln('📜 Récap LifeStack');
  buf.writeln(game.format);
  buf.writeln(
    'Durée · ${_formatDuration(Duration(seconds: game.durationSec))}',
  );
  if (game.winner != null) {
    buf.writeln('Vainqueur · ${game.winner}');
  }
  buf.writeln('Joueurs · ${game.players.join(', ')}');
  if (game.commanders.isNotEmpty) {
    buf.writeln('Commandants · ${game.commanders.join(' · ')}');
  }
  return buf.toString();
}

String buildControllerRecap(GameController controller) {
  return buildGameRecap(
    game: controller.game,
    duration: controller.matchElapsed,
    lifeFeed: controller.lifeFeed,
  );
}

/// Export texte du journal + fil PV (presse-papiers).
String buildJournalExport(GameController controller) {
  final game = controller.game;
  final buf = StringBuffer();
  buf.writeln('Journal LifeStack');
  buf.writeln(formatInfo(game.format).label);
  buf.writeln(
    'Manche ${game.roundNumber} · tour ${game.turnCount} · '
    '${_formatDuration(controller.matchElapsed)}',
  );
  buf.writeln('');
  if (controller.journal.isNotEmpty) {
    buf.writeln('Journal de cartes :');
    for (final event in controller.journal) {
      final at = event.createdAt;
      final clock =
          '${at.hour.toString().padLeft(2, '0')}:'
          '${at.minute.toString().padLeft(2, '0')}';
      buf.writeln('· $clock · ${event.label}');
    }
    buf.writeln('');
  }
  if (controller.lifeFeed.isNotEmpty) {
    buf.writeln('Fil PV :');
    for (final line in controller.lifeFeed) {
      buf.writeln('· $line');
    }
    buf.writeln('');
  }
  if (controller.historyLength > 0) {
    buf.writeln('Actions (récentes → anciennes) :');
    for (var i = controller.historyLength - 1; i >= 0; i--) {
      buf.writeln('· ${controller.historyLabel(i)}');
    }
  }
  buf.writeln('');
  buf.writeln('— LifeStack · local');
  return buf.toString();
}

String _formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
  return '${m}m ${s.toString().padLeft(2, '0')}s';
}
