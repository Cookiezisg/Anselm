/// The active @-token under the caret: [start] = the '@' index, [query] = the text between '@' and the
/// caret. Null when the caret isn't inside one. Trigger rules (the TipTap-suggestion vocabulary the
/// industry shares): the '@' must sit at line start or after whitespace (a word-internal '@' — an email
/// — never triggers), and the query runs to the caret without whitespace/newline/another '@' (typing a
/// space exits the token — the "no match + space = stop re-opening" heuristic falls out of this).
///
/// 光标下的活跃 @-token:[start]='@' 下标,[query]='@' 到光标段。不在其中=null。触发规则(业界共识):
/// '@' 须在行首或空白后(词中 @ 如邮箱不触发);query 到光标不含空白/换行/另一个 '@'(打空格即退出 token)。
({int start, String query})? activeMentionQuery(String text, int cursor) {
  if (cursor <= 0 || cursor > text.length) return null;
  for (var i = cursor - 1; i >= 0; i--) {
    final ch = text[i];
    if (ch == '@') {
      if (i > 0 && !_isWhitespace(text[i - 1])) return null; // word-internal 词中 @
      return (start: i, query: text.substring(i + 1, cursor));
    }
    if (_isWhitespace(ch)) return null; // token broken by whitespace 被空白断开
  }
  return null;
}

bool _isWhitespace(String ch) => ch == ' ' || ch == '\n' || ch == '\t';

