const token = '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';
async function fetchCIErrors() {
  const headers = { 'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github.v3+json' };
  
  console.log("Fetching CaseFlow CI runs...");
  let res = await fetch('https://api.github.com/repos/AMJATH604/Caseflow_Final/actions/workflows/ci.yml/runs?per_page=1', {headers});
  let data = await res.json();
  if (!data.workflow_runs || data.workflow_runs.length === 0) {
    console.log("No runs found for ci.yml");
    return;
  }
  const run = data.workflow_runs[0];
  console.log(`Latest Run ID: ${run.id}, Status: ${run.status}, Conclusion: ${run.conclusion}`);
  
  res = await fetch('https://api.github.com/repos/AMJATH604/Caseflow_Final/actions/runs/' + run.id + '/jobs', {headers});
  data = await res.json();
  
  for (let job of data.jobs) {
    console.log(`Job: ${job.name}, Status: ${job.status}, Conclusion: ${job.conclusion}`);
    if (job.conclusion === 'failure') {
      console.log(`Fetching logs for failed job: ${job.name} (ID: ${job.id})...`);
      res = await fetch('https://api.github.com/repos/AMJATH604/Caseflow_Final/actions/jobs/' + job.id + '/logs', {headers});
      let logText = await res.text();
      let lines = logText.split('\n');
      
      console.log(`\n=== FAILED JOB LOGS FOR ${job.name} (LAST 150 LINES) ===`);
      console.log(lines.slice(-150).join('\n'));
      console.log("=========================================\n");
    }
  }
}
fetchCIErrors();
