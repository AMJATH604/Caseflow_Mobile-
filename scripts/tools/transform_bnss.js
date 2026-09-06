const fs = require('fs');

const TARGET_ACT_ID = 'b8cd8ff9-5e27-411b-8a6d-73a68173bbdb'; // BNSS Act UUID
const inputFile = process.argv[2] || 'bnss_part1.json';
const outputFile = 'ready_for_dashboard_bnss.json';

try {
  const rawData = JSON.parse(fs.readFileSync(inputFile, 'utf8'));

  const transformed = rawData.map((item, index) => {
    return {
      act_id: TARGET_ACT_ID,
      section_number: item[2],
      section_title: item[3],
      section_text: item[4],
      chapter_number: item[0], // Using Part/Chapter string as Chapter Number
      chapter_title: item[1],
      sequence_order: index + 1
    };
  });

  fs.writeFileSync(outputFile, JSON.stringify(transformed, null, 2));
  console.log(`Successfully transformed ${transformed.length} BNSS records into ${outputFile}`);
} catch (error) {
  console.error('Error during transformation:', error.message);
  process.exit(1);
}
