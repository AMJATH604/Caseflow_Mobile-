const token = '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';
async function deleteFailedRuns() {
  const headers = { 
    'Authorization': 'Bearer ' + token, 
    'Accept': 'application/vnd.github.v3+json',
    'X-GitHub-Api-Version': '2022-11-28'
  };
  
  console.log("Fetching all workflow runs...");
  let res = await fetch('https://api.github.com/repos/AMJATH604/Caseflow_Final/actions/runs?per_page=100', {headers});
  let data = await res.json();
  
  if (!data.workflow_runs) {
      console.log("Could not fetch runs.");
      return;
  }
  
  let failedRuns = data.workflow_runs.filter(run => run.conclusion === 'failure' || run.conclusion === 'cancelled');
  console.log(`Found ${failedRuns.length} failed/cancelled runs. Deleting...`);
  
  for (let run of failedRuns) {
      console.log(`Deleting run ID ${run.id} (${run.name})...`);
      let delRes = await fetch(`https://api.github.com/repos/AMJATH604/Caseflow_Final/actions/runs/${run.id}`, {
          method: 'DELETE',
          headers: headers
      });
      if (delRes.ok) {
          console.log(`Successfully deleted run ${run.id}`);
      } else {
          console.log(`Failed to delete run ${run.id}: ${delRes.status} ${delRes.statusText}`);
      }
  }
  console.log("Cleanup complete!");
}
deleteFailedRuns();
