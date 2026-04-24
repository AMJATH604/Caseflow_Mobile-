const fs = require('fs');

const actId = '04ac82bd-f734-4fa8-9dbd-d697cfbfcadb';
const data = JSON.parse(fs.readFileSync('data/aggregates/ready_for_dashboard_ni.json', 'utf8'));

let sql = 'INSERT INTO bare_act_sections (act_id, chapter_number, chapter_title, section_number, section_title, section_text, sequence_order) VALUES\n';

const values = data.map((s, index) => {
    const escape = (str) => str ? str.replace(/'/g, "''") : '';
    return `('${actId}', '${escape(s.chapter_number)}', '${escape(s.chapter_title)}', '${escape(s.section_number)}', '${escape(s.section_title)}', '${escape(s.section_text)}', ${index})`;
});

sql += values.join(',\n') + ';';

fs.writeFileSync('scratch/insert_ni_sections.sql', sql);
console.log('SQL generated in scratch/insert_ni_sections.sql');
