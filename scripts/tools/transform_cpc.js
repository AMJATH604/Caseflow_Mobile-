const fs = require('fs');

const TARGET_ACT_ID = '17caffb2-5ee4-40f0-9692-221a51858382';
const rawData = JSON.parse(fs.readFileSync('cpc.json', 'utf8'));

const transformed = rawData.map(item => {
  return {
    act_id: TARGET_ACT_ID,
    section_number: item[2],
    section_title: item[3],
    section_text: item[4],
    chapter_number: item[0], // Using Part as Chapter Number for mapping
    chapter_title: item[1]
  };
});

fs.writeFileSync('ready_for_dashboard_cpc.json', JSON.stringify(transformed, null, 2));
console.log('Transformed ' + transformed.length + ' records into ready_for_dashboard_cpc.json');
