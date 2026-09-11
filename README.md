# r2sdk

A Cloudflare R2 client built on the Ortus [S3 SDK](https://forgebox.io/view/s3sdk).
It reuses the SDK's HTTP transport and Signature V4 implementation while adapting
R2 account endpoints, path-style signed URLs, signing dates, and ACL behavior.

Apache 2.0 · ColdBox module · BoxLang CFML / Lucee / Adobe ColdFusion

Releases: [GitHub](https://github.com/coldbox-modules/r2sdk/releases) · [ForgeBox](https://forgebox.io/view/r2sdk).
See [development](docs/development.md) for local installation and verification.

## Quick start

Install with `box install r2sdk`. Configure ColdBox:

```cfml
moduleSettings.r2sdk = {
    accessKey : getSystemSetting( "R2_ACCESS_KEY_ID" ),
    secretKey : getSystemSetting( "R2_SECRET_ACCESS_KEY" ),
    awsDomain : getSystemSetting( "R2_ENDPOINT_HOST" ),
    defaultBucketName : "documents"
};
```

Inject a configured client with `property name="r2" inject="Client@r2sdk";`.
Every resolution creates an independent client. For multiple accounts or buckets,
construct `new r2sdk.models.Client(...)` with the same named options.

```cfml
r2.putObject(
    bucketName = "documents",
    uri = "receipts/123.pdf",
    data = pdfBytes,
    contentType = "application/pdf"
);
var metadata = r2.getObjectInfo( "documents", "receipts/123.pdf" );
var download = r2.getAuthenticatedURL(
    bucketName = "documents",
    uri = "receipts/123.pdf",
    minutesValid = 2
);
r2.copyObject( "documents", "receipts/123.pdf", "documents", "archive/123.pdf" );
r2.deleteObject( "documents", "receipts/123.pdf" );
```

Existing S3 operation signatures retain their positional arguments. Prefer named
arguments when supplying optional settings. `getObject()` returns the upstream
SDK response struct; the `response` field contains the body. Set
`getAsBinary=true` for arbitrary bytes (images, PDFs, or archives) so Adobe
ColdFusion cannot decode them as text. For application
filesystem operations, use the separate cbfs-r2 provider instead.

## Configuration

| Setting | Default | Meaning |
| --- | --- | --- |
| `accessKey`, `secretKey` | required | R2 S3 credentials, not Cloudflare API tokens |
| `awsDomain` | required | Bare account hostname |
| `defaultBucketName` | empty | Default for inherited S3 methods |
| `defaultTimeOut` | `30` | HTTP timeout in seconds |
| `retriesOnError` | `3` | Upstream request retry count |
| `defaultCacheControl` | `no-store, no-cache, must-revalidate` | Upload cache control |
| `autoContentType` | `true` | Upstream content-type detection |
| `autoMD5` | `false` | Upstream payload MD5 option |
| `debug` | `false` | Request debugging; may expose signed data |
| `allowInsecureLocalhost` | `false` | Test-only HTTP to `127.0.0.1:port` |

Use `<32-character-account-id>.r2.cloudflarestorage.com` as the endpoint.
Jurisdiction endpoints containing `.eu` or `.fedramp` are accepted. Omit the
scheme, bucket, path, and query string. The client enforces HTTPS, Signature V4,
path-style addressing, and an empty signing region (R2's alias for `auto`).
Conflicting S3 settings cannot change those transport requirements.

## Signed downloads

`getAuthenticatedURL()` accepts the bucket, object key, expiry in minutes, HTTP
method, optional metadata/content-type headers, and response-header overrides.
Expiry is one second through seven days. The caller must send the signed method
and any signed headers unchanged. Generate short-lived URLs when needed and keep
object keys—not signed URLs—in persistent records.

```cfml
var download = r2.getAuthenticatedURL(
    bucketName = "documents",
    uri = "receipts/123.pdf",
    minutesValid = 2,
    responseHeaders = {
        "content-disposition" : 'attachment; filename="receipt.pdf"'
    }
);
```

Supported response overrides are content-type, content-language, expires,
cache-control, content-disposition, and content-encoding. URI encoding preserves
spaces, Unicode, literal plus signs, and percent signs. Do not re-encode the
returned URL.

## R2 compatibility

R2 does not support object ACLs. ACL arguments and ACL APIs raise
`r2sdk.UnsupportedACL`; configure bucket public access in Cloudflare. The SDK
neither provisions public domains nor turns private files public.

The local HTTP contract covers object PUT/GET/HEAD/DELETE, copies, binary data,
configuration, and signed downloads. Inherited APIs such as bucket management,
multipart uploads, and directory listings are not automatically R2-certified.
Consult [Cloudflare's supported S3 operations](https://developers.cloudflare.com/r2/api/s3/api/)
before using additional inherited methods. Keep unsupported AWS-specific options
out of requests. Transport errors propagate rather than being reported as success.

## Documentation and contribution

- [Development, formatting, and tests](docs/development.md)
- [Troubleshooting and live smoke test](docs/troubleshooting.md)
- [Release automation and recovery](docs/releasing.md)
- [Contribution guidelines](CONTRIBUTING.md) · [Security](SECURITY.md)
- Generate API HTML with `box run-script build:docs`.

The modules are independent community integrations, not official Cloudflare
products. Local fixture tests require no credentials; real R2 permissions and TLS
must also be checked before deployment.
