const token = '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';
async function fetchStatus() {
  const headers = { 'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github.v3+json' };
  
  let res = await fetch('https://api.github.com/repos/AMJATH604/Caseflow_Final/actions/workflows/build-apk.yml/runs?per_page=1', {headers});
  let data = await res.json();
  let run = data.workflow_runs[0];
  console.log(`APK Run Status: ${run.status}, Conclusion: ${run.conclusion}`);
  
  res = await fetch('https://api.github.com/repos/AMJATH604/Caseflow_Final/actions/runs/' + run.id + '/jobs', {headers});
  data = await res.json();
  let jobId = data.jobs[0].id;
  
  if (run.conclusion === 'failure') {
      res = await fetch('https://api.github.com/repos/AMJATH604/Caseflow_Final/actions/jobs/' + jobId + '/logs', {headers});
      let logText = await res.text();
      let lines = logText.split('\n');
      let errorLines = lines.filter(l => l.toLowerCase().includes('error') || l.toLowerCase().includes('failed') || l.toLowerCase().includes('exception') || l.toLowerCase().includes('fatal'));
      console.log('Errors found:');
      console.log(errorLines.slice(-25).join('\n'));
  }
}
fetchStatus();
