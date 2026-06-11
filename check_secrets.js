const token = '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';
async function checkSecrets() {
  const headers = { 'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github.v3+json' };
  let res = await fetch('https://api.github.com/repos/AMJATH604/Caseflow_Final/actions/secrets', {headers});
  let data = await res.json();
  console.log("Secrets found:", data.total_count);
  if (data.secrets) {
     data.secrets.forEach(s => console.log(s.name));
  }
}
checkSecrets();
