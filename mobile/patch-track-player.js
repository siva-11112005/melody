const fs = require('fs');
const path = require('path');

const targetPath = path.join(
  __dirname,
  'node_modules',
  'react-native-track-player',
  'android',
  'src',
  'main',
  'java',
  'com',
  'doublesymmetry',
  'trackplayer',
  'module',
  'MusicModule.kt'
);

if (fs.existsSync(targetPath)) {
  let content = fs.readFileSync(targetPath, 'utf8');

  // Fix 1: Kotlin 2.0 Null-safety (line 548)
  content = content.replace(
    'callback.resolve(Arguments.fromBundle(musicService.tracks[index].originalItem))',
    'val item = musicService.tracks[index].originalItem\n            callback.resolve(if (item != null) Arguments.fromBundle(item) else null)'
  );

  // Fix 2: Kotlin 2.0 Null-safety (line 588)
  content = content.replace(
    'else Arguments.fromBundle(\n                musicService.tracks[musicService.getCurrentTrackIndex()].originalItem\n            )',
    'else {\n                val item = musicService.tracks[musicService.getCurrentTrackIndex()].originalItem\n                if (item != null) Arguments.fromBundle(item) else null\n            }'
  );

  // Fix 3: New Architecture TurboModuleInteropUtils$ParsingException
  // Replace `= scope.launch {` with `{ scope.launch {` and close brace.
  const regex = /(@ReactMethod\s*(?:@Deprecated\([^\)]+\)\s*)?)fun\s+(\w+)\((.*?)\)\s*=\s*scope\.launch\s*\{/g;
  let modified = '';

  function findMatchingBrace(str, startIndex) {
      let count = 1;
      let i = startIndex;
      while (count > 0 && i < str.length) {
          if (str[i] === '{') count++;
          else if (str[i] === '}') count--;
          i++;
      }
      return i;
  }

  let result;
  let prevIndex = 0;
  while ((result = regex.exec(content)) !== null) {
      const startMatch = result.index;
      const endMatch = regex.lastIndex; // index of character after '{'
      modified += content.substring(prevIndex, startMatch);
      
      const signature = result[0];
      const newSignature = signature.replace(/=\s*scope\.launch\s*\{/, '{ scope.launch {');
      modified += newSignature;
      
      const endBraceIndex = findMatchingBrace(content, endMatch);
      
      modified += content.substring(endMatch, endBraceIndex - 1);
      modified += '} \n    }';
      
      prevIndex = endBraceIndex;
      regex.lastIndex = endBraceIndex;
  }
  modified += content.substring(prevIndex);

  fs.writeFileSync(targetPath, modified, 'utf8');
  console.log('Successfully patched react-native-track-player MusicModule.kt');
} else {
  console.log('MusicModule.kt not found, skipping patch.');
}
