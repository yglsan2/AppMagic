import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mtg_table/data/app_log.dart';
import 'package:mtg_table/data/card_lookup.dart';
import 'package:mtg_table/data/repository.dart';
import 'package:mtg_table/data/safe_image.dart';
import 'package:mtg_table/data/scryfall_card.dart';
import 'package:mtg_table/domain/card_effect_engine.dart';
import 'package:mtg_table/domain/game_controller.dart';
import 'package:mtg_table/domain/journal_event.dart';
import 'package:mtg_table/domain/models.dart';
import 'package:mtg_table/theme/app_theme.dart';

Future<void> showCardJournalSheet(
  BuildContext context,
  GameController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.92,
        child: CardJournalSheet(controller: controller),
      );
    },
  );
}

class CardJournalSheet extends StatefulWidget {
  const CardJournalSheet({super.key, required this.controller});

  final GameController controller;

  @override
  State<CardJournalSheet> createState() => _CardJournalSheetState();
}

class _CardJournalSheetState extends State<CardJournalSheet> {
  final _query = TextEditingController();
  final _lookup = CardLookup(AppRepository());
  Timer? _debounce;

  bool _loading = false;
  String? _error;
  List<ScryfallCard> _hits = const [];
  ScryfallCard? _card;
  List<EffectSuggestion> _suggestions = const [];
  int _pickedIndex = 0;

  EffectSuggestion? get _picked =>
      _suggestions.isEmpty || _pickedIndex >= _suggestions.length
      ? null
      : _suggestions[_pickedIndex];
  String? _sourceId;
  final Set<String> _targets = {};
  int _amount = 3;
  bool _asCommander = false;
  String? _commanderId;
  String _note = '';

  @override
  void initState() {
    super.initState();
    final game = widget.controller.game;
    _sourceId = game.players[game.activeIndex].id;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _schedule(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(value));
  }

  Future<void> _search(String value) async {
    final q = value.trim();
    if (q.length < 2) {
      setState(() {
        _hits = const [];
        _error = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _lookup.searchResult(q);
    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        _hits = const [];
        _loading = false;
        _error = result.errorMessage;
      });
      return;
    }
    final hits = result.value ?? const <ScryfallCard>[];
    setState(() {
      _hits = hits;
      _loading = false;
      _error = hits.isEmpty ? 'Aucune carte trouvée.' : null;
    });
  }

  Future<void> _select(ScryfallCard hit) async {
    setState(() {
      _loading = true;
      _error = null;
      _card = null;
      _suggestions = const [];
      _pickedIndex = 0;
    });
    final named = await _lookup.namedResult(hit.name);
    if (!mounted) return;
    final full = named.value ?? hit;
    if (!named.ok && named.value == null) {
      setState(() {
        _loading = false;
        _error = named.errorMessage;
        _card = hit;
        _suggestions = cardEffectEngine.suggest(hit);
        _pickedIndex = 0;
      });
      return;
    }
    final suggestions = cardEffectEngine.suggest(full);
    setState(() {
      _card = full;
      _suggestions = suggestions;
      _pickedIndex = 0;
      _loading = false;
      _hits = const [];
      _query.text = full.displayName;
      final first = suggestions.isNotEmpty ? suggestions.first : null;
      if (first != null && !first.needsAmount && first.amount != 0) {
        _amount = first.amount.abs();
      }
      _asCommander = false;
      _commanderId = null;
    });
  }

  List<AppliedDelta> _buildDeltas() {
    final card = _card;
    final picked = _picked;
    if (card == null || picked == null || picked.kind == EffectKind.noteOnly) {
      return const [];
    }
    final source = _sourceId;
    if (source == null) return const [];
    final players = widget.controller.game.players;
    return cardEffectEngine.resolveDeltas(
      suggestion: picked,
      controllerId: source,
      allPlayerIds: [for (final p in players) p.id],
      targetIds: _targets.toList(),
      resolvedAmount: _amount,
      commanderId: _commanderId,
      asCommanderDamage: _asCommander,
    );
  }

  void _apply({bool lifeOnly = false}) {
    final card = _card;
    if (card == null) return;
    try {
      final source = _sourceId;
      if (source == null ||
          widget.controller.game.indexOf(source) < 0) {
        setState(() => _error = 'Choisissez le lanceur.');
        return;
      }
      final sourceName = widget.controller.playerById(source).name;
      final deltas = lifeOnly ? const <AppliedDelta>[] : _buildDeltas();
      final picked = _picked;
      if (!lifeOnly &&
          picked != null &&
          picked.scope == EffectScope.target &&
          picked.kind != EffectKind.noteOnly &&
          _targets.isEmpty) {
        setState(() => _error = 'Choisissez au moins une cible.');
        return;
      }
      if (!lifeOnly &&
          _asCommander &&
          (picked?.kind == EffectKind.life) &&
          (_commanderId == null || _commanderId!.isEmpty)) {
        setState(() => _error = 'Choisissez le commandant source.');
        return;
      }
      final kind = card.isLand ? JournalKind.landPlayed : JournalKind.cardPlayed;
      final effectBit = picked == null || picked.kind == EffectKind.noteOnly
          ? 'journal'
          : picked.label;
      final label = deltas.isEmpty
          ? '$sourceName · ${card.displayName}'
            '${_note.trim().isEmpty ? '' : ' — ${_note.trim()}'}'
          : '$sourceName · ${card.displayName} · $effectBit';

      final event = JournalEvent(
        id: newId('evt'),
        kind: deltas.isEmpty ? kind : JournalKind.assistedEffect,
        label: label,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        roundNumber: widget.controller.game.roundNumber,
        turnCount: widget.controller.game.turnCount,
        sourcePlayerId: source,
        cardName: card.displayName,
        cardTypeLine: card.typeLine,
        manaValue: card.cmc,
        oracleText: card.effectText,
        artUrl: card.artUrl,
        scryfallId: card.id,
        note: _note.trim().isEmpty ? null : _note.trim(),
        suggestions: _suggestions,
        deltas: deltas,
        assisted: deltas.isNotEmpty,
      );

      if (deltas.isEmpty) {
        widget.controller.logJournalNote(event);
      } else {
        widget.controller.commitJournalEvent(event);
      }
      Navigator.of(context).pop();
    } on Object catch (error, stack) {
      AppLog.error('cardJournal.apply', error, stack);
      setState(
        () => _error =
            'Action impossible. Vérifiez le lanceur, les cibles et réessayez.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.controller.game;
    final card = _card;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          const Text(
            'Journal · carte jouée',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Recherche Scryfall → suggestions d’effets → confirmation. '
            'Les interactions complexes restent manuelles. Annuler recalcule les PV.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _query,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              labelText: 'Nom de carte ou terrain',
              hintText: 'Lightning Bolt, Sol Ring…',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: _schedule,
            onSubmitted: _search,
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFFFF8FA3)),
              ),
            ),
          if (_hits.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final hit in _hits)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: hit.artUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SafeNetworkImage(
                          url: hit.artUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.style_outlined),
                        ),
                      )
                    : const Icon(Icons.style_outlined),
                title: Text(hit.displayName),
                subtitle: Text(hit.typeLine, maxLines: 1),
                onTap: () => _select(hit),
              ),
          ],
          if (card != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (card.artUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SafeNetworkImage(
                      url: card.artUrl,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  ),
                if (card.artUrl != null) const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        '${card.manaCost}  ${card.typeLine}'.trim(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              card.effectText.isEmpty
                  ? '(Pas de texte d’oracle)'
                  : card.effectText,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Lanceur',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final player in game.players)
                  ChoiceChip(
                    label: Text(player.name),
                    selected: _sourceId == player.id,
                    onSelected: (_) => setState(() => _sourceId = player.id),
                    avatar: CircleAvatar(
                      backgroundColor: playerColor(player.color),
                      radius: 8,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Effet proposé',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < _suggestions.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                selected: _pickedIndex == i,
                leading: Icon(
                  _pickedIndex == i
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 22,
                ),
                title: Text(_suggestions[i].label),
                subtitle: Text(
                  _suggestions[i].confidence >= 0.85
                      ? 'Suggestion fiable'
                      : _suggestions[i].confidence >= 0.5
                      ? 'À vérifier'
                      : 'Manuelle',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                onTap: () => setState(() {
                  _pickedIndex = i;
                  final suggestion = _suggestions[i];
                  if (!suggestion.needsAmount && suggestion.amount != 0) {
                    _amount = suggestion.amount.abs();
                  }
                }),
              ),
            if (_picked != null &&
                (_picked!.needsAmount ||
                    (_picked!.amount == 0 &&
                        _picked!.kind != EffectKind.noteOnly))) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(child: Text('Montant (X)')),
                  IconButton(
                    onPressed: _amount > 1
                        ? () => setState(() => _amount--)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Text(
                    '$_amount',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  IconButton(
                    onPressed: _amount < 99
                        ? () => setState(() => _amount++)
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
            if (_picked != null &&
                _picked!.scope == EffectScope.target &&
                _picked!.kind != EffectKind.noteOnly) ...[
              const SizedBox(height: 8),
              const Text(
                'Cible(s)',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final player in game.players)
                    FilterChip(
                      label: Text(player.name),
                      selected: _targets.contains(player.id),
                      onSelected: (on) => setState(() {
                        if (on) {
                          _targets.add(player.id);
                        } else {
                          _targets.remove(player.id);
                        }
                      }),
                    ),
                ],
              ),
            ],
            if (game.trackCommanderDamage &&
                _picked != null &&
                _picked!.kind == EffectKind.life) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Compter comme dégâts de commandant'),
                subtitle: const Text(
                  'Combat de commandant uniquement (pas un sort).',
                ),
                value: _asCommander,
                onChanged: (value) => setState(() {
                  _asCommander = value;
                  if (!value) _commanderId = null;
                }),
              ),
              if (_asCommander)
                Wrap(
                  spacing: 8,
                  children: [
                    for (final player in game.players)
                      for (final commander in player.commanders)
                        ChoiceChip(
                          label: Text('${player.name} · ${commander.name}'),
                          selected: _commanderId == commander.id,
                          onSelected: (_) =>
                              setState(() => _commanderId = commander.id),
                        ),
                  ],
                ),
            ],
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Note (facultatif)',
                hintText: 'Pile, choix, stack…',
              ),
              onChanged: (value) => _note = value,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _apply(),
              icon: const Icon(Icons.check),
              label: Text(
                _picked == null || _picked!.kind == EffectKind.noteOnly
                    ? 'Ajouter au journal'
                    : 'Confirmer et appliquer les PV',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _apply(lifeOnly: true),
              child: const Text('Journal seulement (sans toucher aux PV)'),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Données de cartes : Scryfall · cache local sur cet appareil. '
            'Images © Wizards of the Coast.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
