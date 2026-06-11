const token = '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';
async function fetchStatus() {
  const headers = { 'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github.v3+json' };
  
  let res = await fetch('https://api.github.com/repos/AMJATH604/Caseflow_Final/actions/workflows/build-apk.yml/runs?per_page=1', {headers});
  let data = await res.json();
  let runId = data.workflow_runs[0].id;
  
  res = await fetch('https://api.github.com/repos/AMJATH604/Caseflow_Final/actions/runs/' + runId + '/jobs', {headers});
  data = await res.json();
  let jobId = data.jobs[0].id;
  
  res = await fetch('https://api.github.com/repos/AMJATH604/Caseflow_Final/actions/jobs/' + jobId + '/logs', {headers});
  let logText = await res.text();
  
  let lines = logText.split('\n');
  let errLines = lines.filter(l => l.includes('FAILURE: Build failed with an exception') || l.includes('Execution failed for task') || l.includes('What went wrong:'));
  
  if (errLines.length > 0) {
     let index = lines.findIndex(l => l === errLines[0]);
     console.log(lines.slice(Math.max(0, index - 5), index + 25).join('\n'));
  } else {
     let errorLines = lines.filter(l => l.toLowerCase().includes('error') || l.toLowerCase().includes('failed'));
     console.log('Errors found:');
     console.log(errorLines.slice(-30).join('\n'));
  }
}
fetchStatus();
