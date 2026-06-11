const token = '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';
async function fetchLogs() {
  const headers = { 'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github.v3+json' };
  
  // APK Build
  let res = await fetch('https://api.github.com/repos/AMJATH604/Caseflow_Final/actions/workflows/build-apk.yml/runs?per_page=1', {headers});
  let data = await res.json();
  let runId = data.workflow_runs[0].id;
  
  res = await fetch('https://api.github.com/repos/AMJATH604/Caseflow_Final/actions/runs/' + runId + '/jobs', {headers});
  data = await res.json();
  let jobId = data.jobs[0].id;
  
  res = await fetch('https://api.github.com/repos/AMJATH604/Caseflow_Final/actions/jobs/' + jobId + '/logs', {headers});
  let logText = await res.text();
  
  console.log('--- APK BUILD ERRORS ---');
  let lines = logText.split('\n');
  
  let errIndex = lines.findIndex(l => l.includes('version solving failed'));
  if (errIndex !== -1) {
    console.log(lines.slice(Math.max(0, errIndex - 10), errIndex + 10).join('\n'));
    return;
  }
  
  let errorLines = lines.filter(l => l.toLowerCase().includes('error') || l.toLowerCase().includes('failed') || l.toLowerCase().includes('exception') || l.toLowerCase().includes('fatal'));
  console.log(errorLines.slice(-20).join('\n'));
}
fetchLogs();
