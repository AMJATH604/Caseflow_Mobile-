const token = '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';
const headers = { 'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github.v3+json' };

async function cleanUpWorkflows() {
  let res = await fetch('https://api.github.com/repos/AMJATH604/Caseflow_Final/actions/runs?per_page=100', {headers});
  let data = await res.json();
  
  if (!data.workflow_runs || data.workflow_runs.length === 0) {
      console.log("No runs found.");
      return;
  }
  
  // Find the latest successful run to KEEP
  const latestSuccess = data.workflow_runs.find(r => r.conclusion === 'success');
  const keepId = latestSuccess ? latestSuccess.id : data.workflow_runs[0].id; // Fallback to keeping the latest if no success found
  
  console.log(`Keeping run ID: ${keepId} (${latestSuccess ? 'Success' : 'Latest'})`);
  
  let deletedCount = 0;
  for (let run of data.workflow_runs) {
      if (run.id !== keepId) {
          let delRes = await fetch(`https://api.github.com/repos/AMJATH604/Caseflow_Final/actions/runs/${run.id}`, {
              method: 'DELETE',
              headers: headers
          });
          if (delRes.status === 204) {
              console.log(`Deleted run ${run.id} (${run.conclusion})`);
              deletedCount++;
          } else {
              console.log(`Failed to delete ${run.id}: ${delRes.status}`);
          }
      }
  }
  console.log(`Cleanup complete! Deleted ${deletedCount} old runs.`);
}

cleanUpWorkflows();
