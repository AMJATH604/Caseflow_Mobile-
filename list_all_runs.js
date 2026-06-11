const token = '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';
async function listAllRuns() {
  const headers = { 'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github.v3+json' };
  
  console.log("Fetching CaseFlow CI runs...");
  let res = await fetch('https://api.github.com/repos/AMJATH604/Caseflow_Final/actions/runs?per_page=10', {headers});
  let data = await res.json();
  
  for (let run of data.workflow_runs) {
    console.log(`Run ID: ${run.id}`);
    console.log(`  Name: ${run.name} (${run.path})`);
    console.log(`  Commit: ${run.head_commit.message.split('\n')[0]}`);
    console.log(`  Status: ${run.status}, Conclusion: ${run.conclusion}`);
    console.log(`  Created: ${run.created_at}, Updated: ${run.updated_at}`);
  }
}
listAllRuns();
