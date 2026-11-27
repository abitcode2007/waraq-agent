const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const dest = path.join(root, 'www');
fs.mkdirSync(dest, { recursive: true });

for (const name of ['index.html', 'config.js']) {
  fs.copyFileSync(path.join(root, name), path.join(dest, name));
  console.log('copied', name);
}

for (const name of ['manifest.webmanifest', 'sw.js', 'icon-192.png', 'icon-512.png']) {
  const src = path.join(root, name);
  if (fs.existsSync(src)) {
    fs.copyFileSync(src, path.join(dest, name));
    console.log('copied', name);
  }
}
