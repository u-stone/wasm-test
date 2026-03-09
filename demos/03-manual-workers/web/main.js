const workerCount = 4;
const iterationsPerWorker = 300000;
const scheme = 'manual-workers';
const params = new URLSearchParams(window.location.search);
const debugMode = params.get('debug') || localStorage.getItem('wasmDebugMode') || 'release';

const modeBadge = document.createElement('p');
modeBadge.textContent = `Debug mode: ${debugMode}`;
document.body.insertBefore(modeBadge, document.getElementById('run'));

function emit(event, payload) {
  window.parent.postMessage(Object.assign({
    source: 'wasm-demo',
    scheme,
    event,
    ts: performance.now()
  }, payload || {}), '*');
}

function appendLog(text) {
  const list = document.getElementById('log');
  const li = document.createElement('li');
  li.textContent = text;
  list.appendChild(li);
  emit('log', { message: text });
}

function runDemo() {
  document.getElementById('log').innerHTML = '';
  appendLog('[manual-workers] start');
  emit('run-start');

  let finished = 0;
  let combined = 0;
  const begin = performance.now();

  for (let i = 0; i < workerCount; i += 1) {
    const worker = new Worker(`./task-worker.js?debug=${encodeURIComponent(debugMode)}`);
    worker.onmessage = (event) => {
      const data = event.data;
      finished += 1;
      combined += data.result;
      appendLog(`[manual-workers] worker ${data.workerId} done in ${data.elapsedMs.toFixed(1)} ms, result=${data.result.toFixed(3)}`);
      worker.terminate();

      if (finished === workerCount) {
        const totalMs = performance.now() - begin;
        appendLog(`[manual-workers] all done in ${totalMs.toFixed(1)} ms, combined=${combined.toFixed(3)}`);
        emit('run-end', { durationMs: totalMs, combined });
      }
    };

    worker.postMessage({ workerId: i, iterations: iterationsPerWorker });
  }
}

window.addEventListener('message', (event) => {
  if (!event.data || event.data.type !== 'run-demo') {
    return;
  }
  if (event.data.scheme !== scheme && event.data.scheme !== 'all') {
    return;
  }
  runDemo();
});

window.runManualWorkersDemo = runDemo;
emit('ready');

document.getElementById('run').addEventListener('click', runDemo);
