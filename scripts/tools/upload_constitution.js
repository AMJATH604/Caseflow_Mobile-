// upload_constitution.js
// Reads constitution_full.json, transforms to dashboard-ready format, saves output

const fs = require('fs');

// Read raw data
const rawData = JSON.parse(fs.readFileSync('./data/legal/constitution_full.json', 'utf8'));
console.log(`Read ${rawData.length} entries from constitution_full.json`);

// Transform: array format -> object format (matching dashboard schema)
const transformed = rawData.map((item, index) => ({
  chapter_number: item[0] || '',
  chapter_title: item[1] || '',
  section_number: item[2] || '',
  section_title: item[3] || '',
  section_text: item[4] || ''
}));

console.log(`Transformed ${transformed.length} entries`);
console.log('\nSample entry:');
console.log(JSON.stringify(transformed[0], null, 2));

// Save to file
const outputFile = './data/aggregates/ready_for_dashboard.json';
fs.writeFileSync(outputFile, JSON.stringify(transformed, null, 2));
console.log(`\nSaved to ${outputFile} (${(fs.statSync(outputFile).size / 1024).toFixed(1)} KB)`);
console.log('\nNow paste the contents of ready_for_dashboard.json into the Admin Dashboard bulk upload!');
