const fs = require('fs');

const TARGET_ACT_ID = '87bbd472-6d1f-486d-bf75-9a9703366631';
const inputFile = process.argv[2] || 'bsa.json';
const outputFile = 'ready_for_dashboard_bsa.json';

try {
  const rawData = JSON.parse(fs.readFileSync(inputFile, 'utf8'));

  const transformed = rawData.map((item, index) => {
    return {
      act_id: TARGET_ACT_ID,
      section_number: item[2],
      section_title: item[3],
      section_text: item[4],
      chapter_number: item[0], // Using Part as Chapter Number
      chapter_title: item[1],
      sequence_order: index + 1
    };
  });

  fs.writeFileSync(outputFile, JSON.stringify(transformed, null, 2));
  console.log(`Successfully transformed ${transformed.length} records into ${outputFile}`);
} catch (error) {
  console.error('Error during transformation:', error.message);
  process.exit(1);
}
