# Changelog

## 1.0.0 - 2026-09-15

- Initial R2 compatibility layer over s3sdk 5.8.1+119.
- Enforce account endpoints, TLS, path addressing, and ACL rejection.
- Generate path-style presigned URLs with bounded expiry and UTC signing dates.
- Preserve positional S3 operation arguments and offer explicit binary GETs.
- Configure independent WireBox clients without inherited singleton state.
- Add standalone HTTP contracts, CFFormat, DocBox API documentation, and release packaging.
- Add gated GitHub/ForgeBox publishing workflows for standalone repositories.
- Replace Python test orchestration with a CommandBox task and a Java 21 loopback fixture.
