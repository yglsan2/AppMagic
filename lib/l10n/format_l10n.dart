import 'package:mtg_table/domain/models.dart';

String formatL10nLabel(MatchFormat format) => switch (format) {
  MatchFormat.commander => 'format_commander_label',
  MatchFormat.treachery => 'format_treachery_label',
  MatchFormat.duel => 'format_duel_label',
  MatchFormat.brawl => 'format_brawl_label',
  MatchFormat.constructed => 'format_constructed_label',
  MatchFormat.limited => 'format_limited_label',
  MatchFormat.twoHeaded => 'format_2hg_label',
  MatchFormat.oathbreaker => 'format_oathbreaker_label',
  MatchFormat.custom => 'format_custom_label',
};

String formatL10nDetail(MatchFormat format) => switch (format) {
  MatchFormat.commander => 'format_commander_detail',
  MatchFormat.treachery => 'format_treachery_detail',
  MatchFormat.duel => 'format_duel_detail',
  MatchFormat.brawl => 'format_brawl_detail',
  MatchFormat.constructed => 'format_constructed_detail',
  MatchFormat.limited => 'format_limited_detail',
  MatchFormat.twoHeaded => 'format_2hg_detail',
  MatchFormat.oathbreaker => 'format_oathbreaker_detail',
  MatchFormat.custom => 'format_custom_detail',
};

String formatL10nHelp(MatchFormat format) => switch (format) {
  MatchFormat.commander => 'format_commander_help',
  MatchFormat.treachery => 'format_treachery_help',
  MatchFormat.duel => 'format_duel_help',
  MatchFormat.brawl => 'format_brawl_help',
  MatchFormat.constructed => 'format_constructed_help',
  MatchFormat.limited => 'format_limited_help',
  MatchFormat.twoHeaded => 'format_2hg_help',
  MatchFormat.oathbreaker => 'format_oathbreaker_help',
  MatchFormat.custom => 'format_custom_help',
};
