import os
from flask import Flask, render_template_string
from google.cloud import storage

app = Flask(__name__)

BUCKET = os.environ.get("GCS_BUCKET", "")
OUTPUT_PREFIX = "mayavi_output/"
SRC_PREFIX = f"gs://{BUCKET}/mayavi_src/"

TEMPLATE = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Hadoop MapReduce Results</title>
<style>
  *{margin:0;padding:0;box-sizing:border-box}
  body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;background:#f0f2f5;color:#1a1a2e}
  .container{max-width:1100px;margin:0 auto;padding:24px 16px}
  header{background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);color:#fff;padding:32px 0;margin-bottom:24px;border-radius:12px;text-align:center}
  header h1{font-size:28px;font-weight:700}
  header p{opacity:.85;margin-top:8px;font-size:15px}
  .stats{display:grid;grid-template-columns:repeat(3,1fr);gap:16px;margin-bottom:24px}
  .stat-card{background:#fff;border-radius:10px;padding:20px;text-align:center;box-shadow:0 1px 3px rgba(0,0,0,.08)}
  .stat-card .value{font-size:32px;font-weight:700;color:#667eea}
  .stat-card .label{font-size:13px;color:#666;margin-top:4px;text-transform:uppercase;letter-spacing:.5px}
  .controls{background:#fff;border-radius:10px;padding:16px;margin-bottom:16px;box-shadow:0 1px 3px rgba(0,0,0,.08);display:flex;gap:12px;align-items:center}
  .controls input{flex:1;padding:10px 14px;border:1px solid #ddd;border-radius:8px;font-size:14px;outline:none}
  .controls input:focus{border-color:#667eea;box-shadow:0 0 0 3px rgba(102,126,234,.15)}
  .controls select{padding:10px 14px;border:1px solid #ddd;border-radius:8px;font-size:14px;outline:none;background:#fff}
  table{width:100%;border-collapse:collapse;background:#fff;border-radius:10px;overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,.08)}
  th{background:#f8f9fa;padding:12px 16px;text-align:left;font-size:12px;text-transform:uppercase;letter-spacing:.5px;color:#666;cursor:pointer;user-select:none;border-bottom:2px solid #e9ecef}
  th:hover{background:#e9ecef}
  th.asc::after{content:" \25B2"}
  th.desc::after{content:" \25BC"}
  td{padding:10px 16px;border-bottom:1px solid #f0f0f0;font-size:14px}
  tr:hover td{background:#f8f9ff}
  .lc{font-weight:600;color:#667eea;text-align:right;white-space:nowrap}
  .bar{display:inline-block;height:8px;background:linear-gradient(90deg,#667eea,#764ba2);border-radius:4px;margin-left:8px;vertical-align:middle}
  .fp{color:#333;word-break:break-all}
  .ext{display:inline-block;padding:2px 8px;border-radius:4px;font-size:11px;font-weight:600;margin-left:6px}
  .ext-py{background:#e3f2fd;color:#1565c0}
  .ext-js{background:#fff8e1;color:#f57f17}
  .ext-rst{background:#f3e5f5;color:#7b1fa2}
  .ext-txt{background:#e8f5e9;color:#2e7d32}
  .ext-csv{background:#fce4ec;color:#c62828}
  .ext-yaml,.ext-yml{background:#fff3e0;color:#e65100}
  .ext-other{background:#f5f5f5;color:#616161}
  .footer{text-align:center;padding:24px;color:#999;font-size:13px}
  .visible-count{font-size:13px;color:#888;margin-left:auto}
  .error-box{background:#fff;border-radius:10px;padding:40px;text-align:center;box-shadow:0 1px 3px rgba(0,0,0,.08)}
  .error-box h2{color:#e53935;margin-bottom:12px}
  @media(max-width:600px){.stats{grid-template-columns:1fr}.controls{flex-direction:column}}
</style>
</head>
<body>
<div class="container">
  <header>
    <h1>Hadoop MapReduce Line Count Results</h1>
    <p>Mayavi Repository &mdash; Processed by Dataproc Hadoop Streaming on GKE</p>
  </header>
  {% if error %}
  <div class="error-box">
    <h2>Could not load results</h2>
    <p>{{ error }}</p>
  </div>
  {% else %}
  <div class="stats">
    <div class="stat-card"><div class="value">{{ total_files }}</div><div class="label">Files Processed</div></div>
    <div class="stat-card"><div class="value">{{ "{:,}".format(total_lines) }}</div><div class="label">Total Lines</div></div>
    <div class="stat-card"><div class="value">{{ avg_lines }}</div><div class="label">Avg Lines / File</div></div>
  </div>
  <div class="controls">
    <input type="text" id="search" placeholder="Search files... (e.g. mapper.py, tests/, .rst)" oninput="filterTable()">
    <select id="extFilter" onchange="filterTable()">
      <option value="">All extensions</option>
      {% for e in extensions %}<option value=".{{ e }}">{{ e }}</option>{% endfor %}
    </select>
    <span class="visible-count" id="visCount">{{ total_files }} files</span>
  </div>
  <table id="results">
    <thead><tr>
      <th onclick="sortTable(0)" style="width:60px">#</th>
      <th onclick="sortTable(1)">File Path</th>
      <th onclick="sortTable(2)" style="width:200px;text-align:right">Lines</th>
    </tr></thead>
    <tbody>
    {% for file, count in results %}
      <tr>
        <td>{{ loop.index }}</td>
        <td class="fp">{{ file }}{% set ext = file.rsplit('.', 1)[-1] if '.' in file else '' %}<span class="ext ext-{{ ext if ext in ('py','js','rst','txt','csv','yaml','yml') else 'other' }}">{{ ext }}</span></td>
        <td class="lc" data-val="{{ count }}">{{ "{:,}".format(count) }}<span class="bar" style="width:{{ (count / max_lines * 120)|int }}px"></span></td>
      </tr>
    {% endfor %}
    </tbody>
  </table>
  {% endif %}
  <div class="footer">
    GCS bucket: <strong>{{ bucket }}</strong> &nbsp;|&nbsp; Powered by Jenkins + Dataproc + GKE
  </div>
</div>
<script>
let sortCol=-1,sortAsc=true;
function sortTable(c){
  const tb=document.querySelector('#results tbody'),rows=Array.from(tb.rows),
        ths=document.querySelectorAll('#results thead th');
  if(sortCol===c)sortAsc=!sortAsc;else{sortCol=c;sortAsc=true}
  ths.forEach(t=>t.className='');
  ths[c].className=sortAsc?'asc':'desc';
  rows.sort((a,b)=>{
    let va=c===2?+a.cells[2].dataset.val:a.cells[c].textContent.trim(),
        vb=c===2?+b.cells[2].dataset.val:b.cells[c].textContent.trim();
    if(typeof va==='number')return sortAsc?va-vb:vb-va;
    if(!isNaN(va)&&!isNaN(vb))return sortAsc?va-vb:vb-va;
    return sortAsc?va.localeCompare(vb):vb.localeCompare(va);
  });
  rows.forEach(r=>tb.appendChild(r));
}
function filterTable(){
  const q=document.getElementById('search').value.toLowerCase(),
        ext=document.getElementById('extFilter').value.toLowerCase();
  let vis=0;
  document.querySelectorAll('#results tbody tr').forEach(r=>{
    const t=r.cells[1].textContent.toLowerCase(),
          show=t.includes(q)&&(!ext||t.endsWith(ext));
    r.style.display=show?'':'none';
    if(show)vis++;
  });
  document.getElementById('visCount').textContent=vis+' files';
}
</script>
</body>
</html>"""


@app.route("/")
def index():
    try:
        client = storage.Client()
        bucket = client.bucket(BUCKET)
        results = []
        for blob in bucket.list_blobs(prefix=OUTPUT_PREFIX):
            if "/part-" in blob.name:
                for line in blob.download_as_text().strip().split("\n"):
                    if "\t" in line:
                        path, count = line.rsplit("\t", 1)
                        path = path.replace(SRC_PREFIX, "")
                        try:
                            results.append((path, int(count)))
                        except ValueError:
                            pass
        results.sort(key=lambda x: x[1], reverse=True)
        total_lines = sum(c for _, c in results)
        max_lines = results[0][1] if results else 1
        avg = total_lines // len(results) if results else 0
        exts = sorted(
            {f.rsplit(".", 1)[-1] for f, _ in results if "." in f}
        )
        return render_template_string(
            TEMPLATE,
            results=results,
            total_files=len(results),
            total_lines=total_lines,
            max_lines=max_lines,
            avg_lines=avg,
            bucket=BUCKET,
            extensions=exts,
            error=None,
        )
    except Exception as e:
        return render_template_string(
            TEMPLATE,
            results=[],
            total_files=0,
            total_lines=0,
            max_lines=1,
            avg_lines=0,
            bucket=BUCKET,
            extensions=[],
            error=str(e),
        )


@app.route("/health")
def health():
    return "ok"


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
