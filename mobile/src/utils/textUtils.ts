/**
 * Decode HTML entities that come from the JioSaavn API.
 * Handles &amp; &quot; &#039; &lt; &gt; and numeric entities.
 */
export function decodeHTMLEntities(text: string | undefined | null): string {
  if (!text) return '';
  return text
    .replace(/&quot;/g, '"')
    .replace(/&amp;/g, '&')
    .replace(/&#039;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&nbsp;/g, ' ')
    .replace(/&#(\d+);/g, (_match, dec) => String.fromCharCode(dec))
    .replace(/&#x([0-9A-Fa-f]+);/g, (_match, hex) => String.fromCharCode(parseInt(hex, 16)));
}

/**
 * Clean a song title/artist name by decoding HTML entities 
 * and removing trailing junk like "From &quot;MovieName&quot;"
 */
export function cleanSongTitle(text: string | undefined | null): string {
  if (!text) return 'Unknown';
  let cleaned = decodeHTMLEntities(text);
  // Remove "From "MovieName"" pattern at the end
  cleaned = cleaned.replace(/\s*\(From\s+"[^"]*"\)\s*$/i, '');
  cleaned = cleaned.replace(/\s*\(From\s+[^)]*\)\s*$/i, '');
  return cleaned.trim() || 'Unknown';
}
