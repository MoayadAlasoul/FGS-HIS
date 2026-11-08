// Copies supabase-js into web/vendor so the app no longer loads code from a public CDN.
// Run: npm install && npm run vendor ; then change index.html to <script src="vendor/supabase.js"> and remove jsdelivr from web/_headers.
import { mkdirSync, copyFileSync } from 'node:fs';
mkdirSync('web/vendor', { recursive: true });
copyFileSync('node_modules/@supabase/supabase-js/dist/umd/supabase.js', 'web/vendor/supabase.js');
console.log('vendored web/vendor/supabase.js');
