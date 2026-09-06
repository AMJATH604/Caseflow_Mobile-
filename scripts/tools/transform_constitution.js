const fs = require('fs');

// 1. Copy YOUR raw data (the array of arrays) and save it as 'my_data.json' in this folder.
// 2. Then run: node transform_constitution.js
// 3. Copy the content of 'final_upload.json' and paste it into the dashboard.

try {
    const rawData = JSON.parse(fs.readFileSync('my_data.json', 'utf8'));
    
    const formatted = rawData.map((row, index) => ({
        chapter_number: row[0] || "",
        chapter_title: row[1] || "",
        section_number: row[2] || "",
        section_title: row[3] || "",
        section_text: row[4] || "",
        sequence_order: index
    }));

    fs.writeFileSync('final_upload.json', JSON.stringify(formatted, null, 2));
    console.log(`Successfully converted ${formatted.length} articles!`);
    console.log("Please copy 'final_upload.json' into the Dashboard now.");
} catch (e) {
    console.error("Error: Please make sure 'my_data.json' contains your array data.");
}
