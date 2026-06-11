const token = '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';
async function getRunDetails() {
  const headers = { 'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github.v3+json' };
  const runId = '26878098153';
  
  console.log(`Fetching jobs for run ${runId}...`);
  let res = await fetch(`https://api.github.com/repos/AMJATH604/Caseflow_Final/actions/runs/${runId}/jobs`, {headers});
  let data = await res.json();
  
  for (let job of data.jobs) {
    console.log(`Job: ${job.name}`);
    console.log(`  Conclusion: ${job.conclusion}`);
    console.log(`  Steps:`);
    for (let step of job.steps) {
      console.log(`    - ${step.name}: ${step.conclusion} (Status: ${step.status})`);
    }
    
    if (job.conclusion === 'failure') {
      console.log(`\nFetching logs for failed job ${job.name}...`);
      res = await fetch(`https://api.github.com/repos/AMJATH604/Caseflow_Final/actions/jobs/${job.id}/logs`, {headers});
      let logText = await res.text();
      let lines = logText.split('\n');
      
      // Let's find failed steps and print logs around them
      for (let step of job.steps) {
        if (step.conclusion === 'failure') {
          console.log(`\n=== FAILED STEP LOGS: ${step.name} ===`);
          // Find lines starting with timestamp and belonging to the step
          // Since GitHub logs usually have timestamps, let's find the lines for this step.
          // Or we can just find lines that look like errors.
          let stepLines = lines.filter(line => line.includes(step.name) || line.toLowerCase().includes('error') || line.toLowerCase().includes('failed'));
          console.log(stepLines.slice(-30).join('\n'));
          
          console.log(`\n=== END OF LOGS FOR STEP ${step.name} (LAST 60 LINES) ===`);
          // Let's print the last 60 lines of the job's log to catch everything
          console.log(lines.slice(-60).join('\n'));
        }
      }
    }
  }
}
getRunDetails();
