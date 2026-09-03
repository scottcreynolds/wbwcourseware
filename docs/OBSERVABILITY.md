# Observability and Data Handling

Capture request ID, function name, status code, duration, actor ID, and coarse resource ID. Do not log access tokens, invitation tokens, bootstrap secret, email bodies, Markdown bodies, recipient lists, original filenames, signed URLs, or provider response bodies.

Use structured error codes in client-visible responses. Keep provider details in restricted server logs. Alert on repeated authorization failures, spikes in invitation creation, submission-finalize failures, and announcement delivery failure rate.

Retention must match operational need. Restrict production logs to the teacher/operator account and infrastructure administrators.
