const token = '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';
async function fetchFlutterLogs() {
  const headers = { 'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github.v3+json' };
  
  console.log("Fetching CaseFlow CI runs...");
  let res = await fetch('https://api.github.com/repos/AMJATH604/Caseflow_Final/actions/workflows/ci.yml/runs?per_page=1', {headers});
  let data = await res.json();
  let run = data.workflow_runs[0];
  console.log(`Latest Run ID: ${run.id}, Status: ${run.status}, Conclusion: ${run.conclusion}`);
  
  res = await fetch('https://api.github.com/repos/AMJATH604/Caseflow_Final/actions/runs/' + run.id + '/jobs', {headers});
  data = await res.json();
  
  let flutterJob = data.jobs.find(j => j.name.includes("Flutter"));
  if (!flutterJob) {
    console.log("Could not find Flutter job");
    return;
  }
  
  console.log(`Flutter Job Status: ${flutterJob.status}, Conclusion: ${flutterJob.conclusion}`);
  if (flutterJob.conclusion === 'failure') {
    res = await fetch('https://api.github.com/repos/AMJATH604/Caseflow_Final/actions/jobs/' + flutterJob.id + '/logs', {headers});
    let logText = await res.text();
    let lines = logText.split('\n');
    
    // Find where the error or failure steps are
    let failedLines = lines.filter(l => l.includes('error') || l.includes('failed') || l.includes('Exception') || l.includes('FATAL') || l.includes('Failure'));
    console.log("--- FAILED LINES DETECTED ---");
    console.log(failedLines.slice(-30).join('\n'));
    
    console.log("\n--- LAST 300 LINES OF FLUTTER JOB LOGS ---");
    console.log(lines.slice(-300).join('\n'));
  } else {
    console.log("Flutter job succeeded!");
  }
}
fetchFlutterLogs();
