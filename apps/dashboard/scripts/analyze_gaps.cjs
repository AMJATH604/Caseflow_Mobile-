const fs = require('fs');

const data = JSON.parse(fs.readFileSync('c:/Users/amjat/OneDrive/Desktop/CASEFLOW/constitution_full.json', 'utf8'));
const articles = data.filter(row => row.length >= 5).map(row => row[2]);

console.log('Total Articles found:', articles.length);
console.log('Articles List:', articles.join(', '));

// Find gaps
const gaps = [];
let lastNum = 0;
articles.forEach(numStr => {
  const num = parseInt(numStr);
  if (!isNaN(num)) {
    if (num > lastNum + 1) {
      gaps.push(`${lastNum + 1}-${num - 1}`);
    }
    lastNum = num;
  }
});

console.log('Major Gaps detected:', gaps.join(', '));
