const fs = require('fs');
const { v4: uuidv4 } = require('crypto'); // not installed? Then let's use custom function
function generateUUID() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        var r = Math.random() * 16 | 0, v = c === 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
    });
}

const data = JSON.parse(fs.readFileSync('ni_act.json', 'utf8'));
const act_id = '04ac82bd-f734-4fa8-9dbd-d697cfbfcadb';
let values = [];

data.forEach((item, index) => {
    if (item.length >= 6) {
        const chapter_number = item[1].replace(/'/g, "''");
        const chapter_title = item[2].replace(/'/g, "''");
        const section_number = item[3].replace(/'/g, "''");
        const section_title = item[4].replace(/'/g, "''");
        const section_text = item[5].replace(/'/g, "''");
        const title = section_title;
        const content = section_text;
        
        const sequence_order = index + 1;
        const section_id = generateUUID();
        
        values.push(`('${section_id}', '${act_id}', ${sequence_order}, '${chapter_number}', '${chapter_title}', '${section_number}', '${section_title}', '${section_text}', '${title}', '${content}')`);
    }
});

const sql = `INSERT INTO bare_act_sections (id, act_id, sequence_order, chapter_number, chapter_title, section_number, section_title, section_text, title, content) VALUES\n` + values.join(',\n') + `;`;

fs.writeFileSync('scripts/db/import_ni_act_sections.sql', sql, 'utf8');
console.log('Successfully generated scripts/db/import_ni_act_sections.sql');
