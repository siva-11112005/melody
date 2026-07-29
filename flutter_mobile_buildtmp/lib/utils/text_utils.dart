class TextUtils {
  static String cleanSongTitle(String title) {
    return title
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'")
        .replaceAll('(', '')
        .replaceAll(')', '')
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('Official Video', '')
        .replaceAll('Lyrics', '')
        .replaceAll('Full Video', '')
        .replaceAll('Video Song', '')
        .replaceAll('Full Song', '')
        .trim();
  }
}
