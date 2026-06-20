const fs = require('fs');
const path = require('path');

const inputPath = path.join(__dirname, '../../data/legal/dvc.json');
const outputPath = path.join(__dirname, '../db/import_dvc.sql');
const DVC_ACT_ID = '4400cfc2-2e21-477d-844a-9e1e4a1f6d4d';

try {
  const sections = JSON.parse(fs.readFileSync(inputPath, 'utf8'));

  let sqlLines = [
    `-- PROTECTION OF WOMEN FROM DOMESTIC VIOLENCE ACT, 2005 - REGISTRATION & IMPORT`,
    `INSERT INTO bare_acts (id, title, short_title, year, is_active)`,
    `VALUES (`,
    `    '${DVC_ACT_ID}', `,
    `    'Protection of Women from Domestic Violence Act, 2005', `,
    `    'DVC',`,
    `    2005,`,
    `    true`,
    `) ON CONFLICT (id) DO NOTHING;`,
    ``,
    `-- Purge old sections if any`,
    `DELETE FROM bare_act_sections WHERE act_id = '${DVC_ACT_ID}';`,
    ``,
    `-- SECTIONS`,
    `INSERT INTO bare_act_sections (section_number, section_title, section_text, chapter_number, chapter_title, sequence_order, act_id, title, content)`,
    `VALUES`
  ];

  const valueLines = sections.map((s, index) => {
    // Helper to escape single quotes for Postgres
    const esc = (str) => {
      if (!str) return '';
      return str.replace(/'/g, "''");
    };

    const sectionNumber = esc(s.section_number);
    const sectionTitle = esc(s.section_title);
    const sectionText = esc(s.section_text);
    const chapterNumber = esc(s.chapter_number);
    const chapterTitle = esc(s.chapter_title);
    const sequenceOrder = index + 1;

    return `('${sectionNumber}', '${sectionTitle}', '${sectionText}', '${chapterNumber}', '${chapterTitle}', ${sequenceOrder}, '${DVC_ACT_ID}', '${sectionTitle}', '${sectionText}')`;
  });

  const finalSql = sqlLines.join('\n') + '\n' + valueLines.join(',\n') + ';';

  fs.writeFileSync(outputPath, finalSql);
  console.log(`Successfully generated SQL file at: ${outputPath}`);
} catch (e) {
  console.error('Error generating SQL:', e);
}
