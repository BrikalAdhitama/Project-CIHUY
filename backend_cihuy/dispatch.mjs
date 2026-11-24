const secret = process.env.SCHEDULER_SECRET;
if (!secret || secret.length < 32) throw new Error('Configure SCHEDULER_SECRET (32+ characters).');
const url = new URL(process.env.DISPATCH_URL || 'http://127.0.0.1:8080/internal/dispatch');
if (url.protocol !== 'https:' && !(url.protocol === 'http:' && ['127.0.0.1', 'localhost', '[::1]'].includes(url.hostname))) throw new Error('Remote scheduler endpoint must use HTTPS.');
const response = await fetch(url, {
  method: 'POST', headers: { Authorization: `Bearer ${secret}` }, signal: AbortSignal.timeout(55000),
});
if (!response.ok) throw new Error(`Scheduler failed: HTTP ${response.status}`);
console.log(await response.text());
