# ADR-005: Markdown and Sanitized HTML

Status: Accepted

Store Markdown source and permit broad sanitized teacher HTML, including approved video iframes. Block executable/active content and dangerous URLs. Use plain textarea with rendered preview below.

Rationale: Teacher needs flexible existing content and embeds; unrestricted HTML creates stored-XSS risk.

