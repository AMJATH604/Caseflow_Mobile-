const token = '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';
async function fetchAnalyzeErrors() {
  const headers = { 'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github.v3+json' };
  const jobId = '78652692583'; // The Flutter Analyze & Test job ID
  
  console.log("Fetching Flutter Analyze job logs...");
  let res = await fetch(`https://api.github.com/repos/AMJATH604/Caseflow_Final/actions/jobs/${jobId}/logs`, {headers});
  let logText = await res.text();
  let lines = logText.split('\n');
  
  console.log("=== FLUTTER ANALYZE ERRORS AND WARNINGS ===");
  // Filter for lines containing 'error •' or 'warning •' or 'info •'
  let analyzeLines = lines.filter(l => l.includes('error •') || l.includes('warning •'));
  console.log(analyzeLines.join('\n'));
}
fetchAnalyzeErrors();
