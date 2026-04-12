const fs = require('fs');

const data = JSON.parse(fs.readFileSync('c:/Users/amjat/OneDrive/Desktop/CASEFLOW/constitution_full.json', 'utf8'));
const presentArticles = [];

data.forEach(row => {
    if (row.length >= 5) {
        const num = row[2];
        if (num && !isNaN(parseInt(num)) || num.match(/^\d+[A-Z]$/)) {
            presentArticles.push(num);
        }
    }
});

fs.writeFileSync('c:/Users/amjat/OneDrive/Desktop/CASEFLOW/present_articles.txt', presentArticles.join(', '));
console.log('Done mapping present articles.');
