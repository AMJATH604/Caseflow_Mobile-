const token = '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';
async function fetchStatus() {
  const headers = { 'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github.v3+json' };
  
  let res = await fetch('https://api.github.com/repos/AMJATH604/Caseflow_Final/actions/workflows/build-apk.yml/runs?per_page=1', {headers});
  let data = await res.json();
  let run = data.workflow_runs[0];
  console.log(`APK Run Status: ${run.status}, Conclusion: ${run.conclusion}`);
  if (run.conclusion === 'success') {
     console.log(`Artifacts URL: ${run.artifacts_url}`);
  }
}
fetchStatus();
