const fs = require('fs');

const FILE_PATH = 'ni_act.json';
const ACT_ID = '04ac82bd-f734-4fa8-9dbd-d697cfbfcadb';

const rawData = JSON.parse(fs.readFileSync(FILE_PATH, 'utf8'));

let sql = `DELETE FROM bare_act_sections WHERE act_id = '${ACT_ID}';\n\n`;
sql += `INSERT INTO bare_act_sections (act_id, chapter_number, chapter_title, section_number, section_title, section_text, sequence_order) VALUES\n`;

const values = rawData.map((item, index) => {
  const chapter_number = (item[1] || '').replace(/'/g, "''");
  const chapter_title = (item[2] || '').replace(/'/g, "''");
  const section_number = (item[3] || '').replace(/'/g, "''");
  const section_title = (item[4] || '').replace(/'/g, "''");
  const section_text = (item[5] || '').replace(/'/g, "''");
  const sequence_order = index + 1;

  return `('${ACT_ID}', '${chapter_number}', '${chapter_title}', '${section_number}', '${section_title}', '${section_text}', ${sequence_order})`;
});

sql += values.join(',\n') + ';';

fs.writeFileSync('scratch/restore_ni_full.sql', sql);
console.log('Generated scratch/restore_ni_full.sql with ' + rawData.length + ' entries.');
