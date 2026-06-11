const token = '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';
async function getRunSummary() {
  const headers = { 'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github.v3+json' };
  const runId = '26685417085';
  
  console.log(`Fetching jobs for run ${runId}...`);
  let res = await fetch(`https://api.github.com/repos/AMJATH604/Caseflow_Final/actions/runs/${runId}/jobs`, {headers});
  let data = await res.json();
  
  for (let job of data.jobs) {
    console.log(`Job: ${job.name} -> Conclusion: ${job.conclusion}`);
    for (let step of job.steps) {
      console.log(`  - ${step.name}: ${step.conclusion}`);
    }
  }
}
getRunSummary();
