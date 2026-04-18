# Security Policy

## Supported Versions

Currently supported versions for security updates:

| Version | Support Status | EOL Date |
|---------|---------------|----------|
| 1.0.x (Phase 1 PoC) | Active Development | TBD (Month 6) |
| 0.1.x | Superseded by 1.0.0 | 2026-02-21 |

## Security Model

### Threat Model

**In Scope:**
- GraphQL API injection attacks
- ArangoDB query injection (AQL)
- Authentication/authorization bypasses (Phase 2+)
- XSS in web interface
- CSRF in state-changing operations
- Sensitive data exposure (interview subjects, confidential evidence)
- Dependency vulnerabilities

**Out of Scope (Current Phase):**
- DDoS attacks (no production deployment yet)
- Physical security of infrastructure
- Social engineering of users
- Client-side attacks on user browsers (beyond standard web security)

### Security Architecture

**10+ Dimensions of Security (RSR Framework):**

1. **Type Safety**: Elixir compile-time checks, Ecto schemas, GraphQL type system
2. **Memory Safety**: BEAM VM memory isolation, no manual memory management
3. **Input Validation**: Ecto changesets, GraphQL schema validation, AQL parameterization
4. **Authentication**: phx.gen.auth with BCrypt password hashing, magic link login
5. **Authorization**: Session-based auth with CSRF protection (RBAC planned Phase 2)
6. **Data Protection**: EU GDPR compliance, anonymized interview subjects
7. **Transport Security**: HTTPS/TLS in production (Phase 2)
8. **Audit Logging**: All mutations logged with user attribution
9. **Dependency Scanning**: Automated via CI/CD (see Justfile `security-scan`)
10. **IPFS Provenance**: (Phase 2) Tamper-evident evidence storage with hash verification

### EU GDPR Compliance

This project handles sensitive investigative journalism data:

- **Anonymization**: Interview subjects can be anonymized in database
- **Right to Erasure**: Evidence marked as `deleted` (soft delete) with audit trail
- **Data Minimization**: Only essential metadata collected
- **Encryption**: Database-level encryption in production (ArangoDB Enterprise)
- **Data Sovereignty**: EU hosting (Hetzner Cloud)

## Reporting a Vulnerability

### Where to Report

**DO NOT** open public GitHub issues for security vulnerabilities.

**Preferred Methods (in order):**

1. **Email**: security@evidencegraph.org (PGP key below)
2. **GitHub Security Advisory**: https://github.com/Hyperpolymath/bofig/security/advisories/new
3. **GitLab Confidential Issue**: (if hosted on GitLab)

### What to Include

Please provide:

1. **Description**: Detailed explanation of the vulnerability
2. **Impact**: What an attacker could do (CVSS score if calculated)
3. **Reproduction**: Step-by-step instructions to reproduce
4. **Environment**: Version, OS, configuration
5. **Proposed Fix**: If you have suggestions (optional)
6. **Disclosure Timeline**: When you plan to publish (if at all)

### Response Timeline

We commit to:

- **24 hours**: Initial acknowledgment of report
- **7 days**: Preliminary assessment (severity, affected versions)
- **30 days**: Fix deployed or detailed remediation plan
- **90 days**: Public disclosure (coordinated with reporter)

### Severity Levels

| Severity | Response Time | Example |
|----------|--------------|---------|
| **Critical** | 24 hours | Remote code execution, authentication bypass |
| **High** | 7 days | SQL/AQL injection, XSS, privilege escalation |
| **Medium** | 30 days | CSRF, information disclosure |
| **Low** | 90 days | Minor information leaks, rate limiting issues |

### Bounty Program

**Current Status**: No formal bug bounty (Phase 1 PoC)

**Phase 2+**: Considering partnership with:
- HackerOne / Bugcrowd
- EU-specific platforms (YesWeHack)

**Acknowledgments**: Security researchers will be credited in:
- CHANGELOG.md
- .well-known/humans.txt
- Security Hall of Fame (if program established)

## Known Security Limitations (v1.0.0)

### Current Gaps

1. **No Rate Limiting**: API can be abused
   - **Mitigation**: Reverse proxy with rate limits (Nginx config provided)
   - **Fix**: Phase 2 (Phoenix rate limiting plug)

2. **No RBAC**: All authenticated users have equal access
   - **Mitigation**: Authentication required for all routes
   - **Fix**: Phase 2 (role-based access control)

3. **Security Headers**: Basic headers via Phoenix, full CSP pending
   - **Mitigation**: Nginx adds HSTS, X-Frame-Options in production
   - **Fix**: Phase 2 (comprehensive CSP policy)

### Resolved Since v0.1.0

1. **Authentication**: Implemented via phx.gen.auth (bcrypt, sessions, CSRF)
2. **Dependency Scanning**: Automated via `mix deps.audit` in CI and Justfile
3. **Input Validation**: Ecto changesets on all user input, parameterized AQL queries

### Secure Coding Practices

**We follow:**
- OWASP Top 10 prevention guidelines
- Elixir Security Working Group recommendations
- Phoenix Security Guide
- ArangoDB Security Best Practices

**We avoid:**
- `String.to_existing_atom/1` on user input (atom exhaustion)
- `Code.eval_string/1` on untrusted input
- Storing plaintext secrets (use environment variables)
- SQL injection (we use ArangoDB with parameterized queries)

## Security Testing

### Automated Scanning

```bash
# Dependency vulnerability scan
mix deps.audit

# Static analysis
mix credo --strict

# Code quality
mix dialyzer

# Security-focused linting
just security-scan  # (see Justfile)
```

### Manual Testing

**GraphQL API Fuzzing:**
```bash
# Test injection attacks
echo '{ claims(investigationId: "inv\"; DROP TABLE claims;--") { id } }' | \
  http POST :4000/api/graphql query=@-
```

**AQL Injection Testing:**
```elixir
# Should be safe due to parameterized queries
EvidenceGraph.Claims.search_claims("'; DROP COLLECTION claims;--")
```

### Penetration Testing

**Phase 2+ Plan:**
- External penetration test before public launch
- Red team exercise on production infrastructure
- OWASP ZAP automated scanning in CI/CD

## Security Updates

### Notification Channels

Subscribe to security announcements:

1. **GitHub Watch**: Enable "Custom" notifications → "Security alerts"
2. **RSS Feed**: https://github.com/Hyperpolymath/bofig/security/advisories.atom
3. **Mailing List**: security-announce@evidencegraph.org (low-traffic)

### Changelog

All security fixes documented in CHANGELOG.md with:
- CVE ID (if assigned)
- Severity level
- Affected versions
- Credit to reporter

## Dependency Security

### Current Dependencies (Phase 1)

**Critical Dependencies:**
- Phoenix 1.7.x (web framework)
- Absinthe 1.7.x (GraphQL)
- Arangox 0.5.x (database driver)
- Ecto 3.11.x (schemas/validation)

**Audit Process:**
1. Weekly `mix deps.audit` check
2. Automated GitHub Dependabot alerts
3. Manual review of security advisories
4. Test suite run before all updates

### Update Policy

- **Critical vulnerabilities**: Patch within 24 hours
- **High severity**: Update within 7 days
- **Medium/Low**: Include in next minor release

## Infrastructure Security (Phase 2)

### Production Deployment

**Hetzner Cloud (EU):**
- Firewall: Ports 80/443 only, no SSH from public internet
- SSH: Key-based auth only, fail2ban active
- Nginx: Reverse proxy with rate limiting, ModSecurity WAF
- SSL: Let's Encrypt with HSTS, TLS 1.3 only

**ArangoDB Oasis:**
- Managed service, automatic security patches
- Network isolation (VPC peering)
- Encryption at rest + in transit
- Daily backups with 30-day retention

### Secrets Management

**Never commit:**
- `SECRET_KEY_BASE`
- `ARANGO_PASSWORD`
- API keys, tokens, credentials

**Use:**
- Environment variables (`.env` ignored by Git)
- Phoenix releases config (`config/runtime.exs`)
- Hetzner Cloud metadata service (production)
- 1Password/Vault for team secrets (Phase 2)

## Incident Response

### Process

1. **Detection**: Automated alerts, user reports, security scans
2. **Containment**: Isolate affected systems, revoke credentials
3. **Eradication**: Apply patches, remove malicious code
4. **Recovery**: Restore from backups, verify integrity
5. **Lessons Learned**: Post-mortem, update security measures

### Communication

- **Internal**: Maintainers via encrypted channel (Signal/Matrix)
- **Users**: Security advisory published within 24 hours of fix
- **Public**: CVE assignment for critical issues, blog post with details

### Data Breach Protocol

If sensitive investigative data is compromised:

1. Notify affected journalists within 24 hours
2. Report to data protection authority (GDPR Article 33)
3. Publish incident report with timeline
4. Offer mitigation (password reset, evidence re-upload)
5. Forensic analysis to prevent recurrence

## Compliance & Audits

### Standards

- **EU GDPR**: Article 25 (Privacy by Design), Article 32 (Security)
- **ISO 27001**: Information security management (future certification)
- **OWASP ASVS**: Application Security Verification Standard Level 2
- **CWE Top 25**: Common Weakness Enumeration prevention

### Audit Trail

All security-relevant events logged:
- Authentication attempts
- Authorization failures
- Data access (GDPR Article 30)
- Configuration changes
- Security updates applied

Logs retained for 90 days (GDPR minimum), 1 year for security incidents.

## Contact Information

### Security Team

- **Lead**: @Hyperpolymath (GitHub)
- **Email**: security@evidencegraph.org
- **PGP Key**: [To be published]
- **Response Hours**: Mon-Fri 9am-5pm UTC (best-effort, volunteer project)

### Escalation

For urgent issues (active exploitation):
- **Phone**: [To be published for Phase 2]
- **Matrix**: [To be set up]

## Acknowledgments

We thank the following security researchers:

*(None yet - Hall of Fame will be added as reports are received)*

## Resources

- **OWASP Top 10**: https://owasp.org/www-project-top-ten/
- **Elixir Security**: https://elixir-lang.org/blog/2021/10/13/security-working-group/
- **Phoenix Security Guide**: https://hexdocs.pm/phoenix/security.html
- **ArangoDB Security**: https://www.arangodb.com/docs/stable/security.html

---

**Last Updated**: 2026-02-21
**Policy Version**: 1.1 (v1.0.0 Release)
**Next Review**: 2026-03-21 (monthly during Phase 1)

*This security policy is maintained in accordance with RSR (Rhodium Standard Repository) framework requirements and RFC 9116 (security.txt).*
