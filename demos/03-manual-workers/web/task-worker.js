const pendingJobs = [];
let ready = false;
const params = new URLSearchParams(self.location.search);
const debugMode = params.get('debug') || 'release';

function runJob(job) {
  const result = Module.ccall(
    'run_heavy_task',
    'number',
    ['number', 'number'],
    [job.workerId, job.iterations]
  );

  postMessage({
    workerId: job.workerId,
    iterations: job.iterations,
    result: result,
    elapsedMs: performance.now() - job.startedAt
  });
}

self.Module = {
  onRuntimeInitialized: function() {
    ready = true;
    while (pendingJobs.length > 0) {
      runJob(pendingJobs.shift());
    }
  }
};

importScripts(`../output/${debugMode}/task.js`);

onmessage = function(event) {
  const job = {
    workerId: event.data.workerId,
    iterations: event.data.iterations,
    startedAt: performance.now()
  };

  if (!ready) {
    pendingJobs.push(job);
    return;
  }

  runJob(job);
};
