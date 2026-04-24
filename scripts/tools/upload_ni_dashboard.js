const fs = require('fs');

const FILE_PATH = 'ni_act.json';
const OUTPUT_PATH = 'data/aggregates/ready_for_dashboard_ni.json';

if (!fs.existsSync(FILE_PATH)) {
  console.error(`File not found: ${FILE_PATH}`);
  process.exit(1);
}

const rawData = JSON.parse(fs.readFileSync(FILE_PATH, 'utf8'));
console.log(`Read ${rawData.length} entries from ${FILE_PATH}`);

// Transform: array format -> object format (matching dashboard schema)
const transformed = rawData.map((item, index) => ({
  chapter_number: item[1] || '',
  chapter_title: item[2] || '',
  section_number: item[3] || '',
  section_title: item[4] || '',
  section_text: item[5] || ''
}));

console.log(`Transformed ${transformed.length} entries`);
console.log('\nSample entry:');
console.log(JSON.stringify(transformed[0], null, 2));

// Save to file
fs.writeFileSync(OUTPUT_PATH, JSON.stringify(transformed, null, 2));
console.log(`\nSaved to ${OUTPUT_PATH} (${(fs.statSync(OUTPUT_PATH).size / 1024).toFixed(1)} KB)`);
console.log('\nNow paste the contents of ready_for_dashboard_ni.json into the Admin Dashboard bulk upload!');
