:root {
  --ink: #1f241e;
  --ink-soft: #4e564c;
  --paper: #eff1ea;
  --paper-raised: #f8f9f5;
  --line: #d7dbcf;
  --sage-deep: #5e6e52;
  --forest: #4f7a5a;
  --rust: #b4573d;
  --amber: #cb9a3a;
}

* { box-sizing: border-box; }

body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  background: var(--paper);
  color: var(--ink);
}

.wrap {
  max-width: 560px;
  margin: 0 auto;
  padding: 32px 20px 80px;
}

.state {
  text-align: center;
  padding: 60px 20px;
  color: var(--ink-soft);
}

.hidden { display: none !important; }

.header {
  display: flex;
  align-items: center;
  gap: 14px;
  margin-bottom: 24px;
}

.logo {
  width: 48px;
  height: 48px;
  border-radius: 8px;
  object-fit: cover;
}

.header h1 { margin: 0; font-size: 22px; }
.intro { margin: 2px 0 0; color: var(--ink-soft); font-size: 14px; }

.progress { margin-bottom: 24px; }
.progress-bar {
  height: 8px;
  border-radius: 4px;
  background: var(--line);
  overflow: hidden;
}
.progress-fill {
  height: 100%;
  background: var(--sage-deep);
  width: 0%;
  transition: width 0.3s ease;
}
.progress-label {
  margin: 8px 0 0;
  font-size: 13px;
  color: var(--ink-soft);
}

.items { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 12px; }

.item {
  background: var(--paper-raised);
  border: 1px solid var(--line);
  border-radius: 8px;
  padding: 16px;
}

.item-head { display: flex; justify-content: space-between; align-items: flex-start; gap: 12px; }
.item-name { font-weight: 600; margin: 0; }
.item-instructions { color: var(--ink-soft); font-size: 13px; margin: 4px 0 0; }

.badge {
  font-size: 12px;
  font-weight: 600;
  padding: 3px 10px;
  border-radius: 999px;
  white-space: nowrap;
}
.badge-missing { background: rgba(203,154,58,0.15); color: var(--amber); }
.badge-received { background: rgba(79,122,90,0.15); color: var(--forest); }

.item-input { margin-top: 12px; }

input[type="text"], textarea {
  width: 100%;
  padding: 10px 12px;
  border: 1px solid var(--line);
  border-radius: 6px;
  font-size: 14px;
  font-family: inherit;
  resize: vertical;
}

input[type="file"] { font-size: 13px; }

button {
  margin-top: 10px;
  padding: 10px 16px;
  background: var(--sage-deep);
  color: var(--paper-raised);
  border: none;
  border-radius: 6px;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
}
button:disabled { opacity: 0.5; cursor: not-allowed; }

.item-error { color: var(--rust); font-size: 13px; margin-top: 8px; }

.complete-banner {
  margin-top: 28px;
  text-align: center;
  padding: 28px 16px;
  background: var(--paper-raised);
  border: 1px solid var(--line);
  border-radius: 8px;
}
.complete-banner h2 { margin: 0 0 6px; font-size: 18px; }
.complete-banner p { margin: 0; color: var(--ink-soft); font-size: 14px; }