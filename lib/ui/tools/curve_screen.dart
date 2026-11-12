import 'package:flutter/material.dart';
import 'package:mtg_table/data/scryfall_client.dart';
import 'package:mtg_table/domain/deck_audit.dart';
import 'package:mtg_table/domain/mana_curve.dart';
import 'package:mtg_table/domain/stats.dart';
import 'package:mtg_table/theme/app_theme.dart';

class CurveScreen extends StatefulWidget {
  const CurveScreen({super.key, required this.ledger});

  final LocalLedger ledger;

  @override
  State<CurveScreen> createState() => _CurveScreenState();
}

class _CurveScreenState extends State<CurveScreen> {
  final _list = TextEditingController();
  final _commander = TextEditingController();
  var _busy = false;
  String? _error;
  DeckAudit? _audit;

  @override
  void dispose() {
    _list.dispose();
    _commander.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final zoned = parseZonedDeck(_list.text);
    if (zoned.isEmpty) {
      setState(() {
        _error = 'Collez le deck : une carte par ligne, avec le nombre devant.';
        _audit = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final counts = <String, int>{};
    for (final line in [...zoned.commander, ...zoned.main, ...zoned.sideboard]) {
      if (basicCurveCard(line.name, line.count) != null) continue;
      counts[line.name] = (counts[line.name] ?? 0) + line.count;
    }
    var found = <String, CurveCard>{};
    if (counts.isNotEmpty) {
      try {
        final looked = await fetchCurveCards(counts);
        found = looked.found;
      } on Object {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = 'Scryfall ne répond pas. Les terrains de base restent lisibles.';
          _audit = _auditOf(zoned, const {});
        });
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _audit = _auditOf(zoned, found);
    });
  }

  List<CurveCard> _cards(List<DeckLine> lines, Map<String, CurveCard> found) {
    final cards = <CurveCard>[];
    for (final line in lines) {
      final basic = basicCurveCard(line.name, line.count);
      if (basic != null) {
        cards.add(basic);
        continue;
      }
      final known = found[line.name.toLowerCase()];
      if (known == null) {
        cards.add(CurveCard(name: line.name, count: line.count, mv: 0, unknown: true));
        continue;
      }
      cards.add(copyCount(known, line.count));
    }
    return cards;
  }

  DeckAudit _auditOf(ZonedDeck zoned, Map<String, CurveCard> found) {
    final commanderName = zoned.commander.isEmpty
        ? _commander.text
        : zoned.commander.first.name;
    final record = widget.ledger.commanderNamed(commanderName);
    return auditDeck(
      commander: _cards(zoned.commander, found),
      main: _cards(zoned.main, found),
      side: _cards(zoned.sideboard, found),
      dropped: zoned.dropped,
      context: CurveContext(
        averageGameSec: widget.ledger.averageDurationSec(),
        commanderName: record?.commander,
        commanderWins: record?.wins,
        commanderGames: record?.games,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audit = _audit;
    return Scaffold(
      appBar: AppBar(title: const Text('Analyse de deck')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const Text(
            'Outil à part, hors de la partie. Collez jusqu’à 110 cartes : '
            'le commandant, le deck, puis la réserve. '
            'Une liste Arena, avec le code d’édition, passe aussi. '
            'Les cartes inconnues restent dans la taille. '
            'Les cartes rares ou peu vues en commandant sont signalées à part. '
            'Les repères décrivent la construction, sans proposer d’achats. '
            'Ça reste fermé pendant un match de tournoi.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commander,
            decoration: const InputDecoration(
              labelText: 'Commandant, si la liste n’a pas de section',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _list,
            minLines: 10,
            maxLines: 16,
            decoration: const InputDecoration(
              alignLabelWithHint: true,
              labelText: 'Deck complet',
              hintText: 'Commandant\n1 Atraxa, Praetors\' Voice\n\nDeck\n1 Sol Ring\n36 Forest\n\nRéserve\n1 Swords to Plowshares',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _analyze,
            child: Text(_busy ? 'Lecture…' : 'Analyser'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: dangerCrit)),
          ],
          if (audit != null) ...[
            const SizedBox(height: 16),
            Text(
              '${audit.commanderCards} commandant · ${audit.mainCards} deck · '
              '${audit.sideCards} réserve · ${audit.recognized} reconnues · '
              '${audit.unknown} inconnues',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if (audit.dropped > 0)
              Text(
                '${audit.dropped} cartes au-delà de 110 n’ont pas été lues.',
                style: const TextStyle(color: dangerWarn),
              ),
            const SizedBox(height: 8),
            Text(
              '${audit.curve.lands} terrains · ${audit.curve.spells} sorts · '
              'moyenne ${audit.curve.averageSpellMv.toStringAsFixed(1)} · '
              '${audit.ramp} accélérations · ${audit.draw} pioches · '
              '${audit.interaction} interactions · ${audit.wipes} vidages · '
              '${audit.fixing} terrains multicolores · ${audit.threats} gros sorts',
            ),
            if (audit.manaLine.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(audit.manaLine),
            ],
            if (audit.rarityLine.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(audit.rarityLine),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: CustomPaint(
                painter: _CurvePainter(audit.curve.buckets),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < audit.curve.buckets.length; i++)
                  Expanded(
                    child: Text(
                      i == 7 ? '7+' : '$i',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Répartition',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text(
              '${audit.creatures} créatures · ${audit.instants} éphémères · '
              '${audit.sorceries} rituels · ${audit.artifacts} artefacts · '
              '${audit.enchantments} enchantements · '
              '${audit.planeswalkers} planeswalkers',
            ),
            const SizedBox(height: 16),
            const Text(
              'Lecture',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text(audit.portrait),
            const SizedBox(height: 16),
            const Text(
              'Conseils',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            for (var i = 0; i < audit.advice.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('${i + 1}. ${audit.advice[i]}'),
              ),
            const SizedBox(height: 16),
            const Text(
              'Points forts',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            for (final line in audit.strengths)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(line),
              ),
            const SizedBox(height: 16),
            const Text(
              'Points faibles',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            if (audit.weaknesses.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Rien de net sur cette liste.'),
              ),
            for (final line in audit.weaknesses)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(line),
              ),
            ..._nameBlock('Hors identité', audit.offIdentity),
            ..._nameBlock('Doublons', audit.duplicates),
            ..._nameBlock('Illégales en commandant', audit.illegal),
            ..._nameBlock(
              'Peu jouées en commandant',
              audit.rarelyPlayed,
            ),
            ..._nameBlock('Inconnues', audit.unknownNames),
          ],
        ],
      ),
    );
  }
}

List<Widget> _nameBlock(String title, List<String> names) {
  if (names.isEmpty) return const [];
  return [
    const SizedBox(height: 16),
    Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
    ),
    const SizedBox(height: 6),
    Text(names.join(', ')),
  ];
}

class _CurvePainter extends CustomPainter {
  _CurvePainter(this.buckets);

  final List<int> buckets;

  @override
  void paint(Canvas canvas, Size size) {
    final maxCount = buckets.fold<int>(1, (max, value) => value > max ? value : max);
    final slot = size.width / buckets.length;
    final paint = Paint()..color = accent;
    for (var i = 0; i < buckets.length; i++) {
      final height = size.height * buckets[i] / maxCount;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(slot * i + 4, size.height - height, slot - 8, height),
          const Radius.circular(3),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CurvePainter oldDelegate) => true;
}
