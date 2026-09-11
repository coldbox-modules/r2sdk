/** R2 endpoint and ACL compatibility over the existing S3 SDK. */
component extends="s3sdk.models.AmazonS3" {

	/**
	 * Construct an isolated R2 client. Credentials are S3 access keys, not API bearer tokens.
	 *
	 * @accessKey              R2 access key ID.
	 * @secretKey              R2 secret access key.
	 * @awsDomain              Bare account hostname, including an optional jurisdiction label.
	 * @allowInsecureLocalhost Permit HTTP only for an explicit 127.0.0.1:port fixture.
	 * @defaultBucketName      Default bucket for inherited S3 operations.
	 * @defaultTimeOut         HTTP timeout in seconds.
	 * @retriesOnError         Retry count used by the upstream S3 transport.
	 *
	 * @throws r2sdk.InvalidCredentials ,r2sdk.InvalidEndpoint
	 */
	function init(
		required string accessKey,
		required string secretKey,
		required string awsDomain,
		boolean allowInsecureLocalhost = false,
		string defaultBucketName       = "",
		numeric defaultTimeOut         = 30,
		numeric retriesOnError         = 3
	){
		if ( !len( arguments.accessKey ) || !len( arguments.secretKey ) ) {
			throw(
				type    = "r2sdk.InvalidCredentials",
				message = "R2 requires an access key ID and secret access key."
			);
		}
		var localEndpoint = reFind( "^127\.0\.0\.1:[0-9]+$", arguments.awsDomain ) > 0;
		if (
			!( arguments.allowInsecureLocalhost && localEndpoint ) &&
			!reFindNoCase( "^[a-f0-9]{32}(\.(eu|fedramp))?\.r2\.cloudflarestorage\.com$", arguments.awsDomain )
		) {
			throw( type = "r2sdk.InvalidEndpoint", message = "Use the account R2 S3 endpoint hostname." );
		}
		arguments.ssl                 = !( arguments.allowInsecureLocalhost && localEndpoint );
		arguments.signatureType       = "V4";
		// Empty region is an R2-supported alias for auto. It also prevents the
		// upstream SDK from prefixing a region onto a custom path-style host.
		arguments.awsRegion           = "";
		arguments.urlStyle            = "path";
		arguments.defaultACL          = "";
		arguments.throwOnRequestError = true;
		arguments.serviceName         = "s3";
		super.init( argumentCollection = arguments );
		return this;
	}

	/**
	 * Retrieve an object, optionally preserving binary bytes across CFML engines.
	 *
	 * @bucketName    Existing R2 bucket or configured default.
	 * @uri           Raw object key relative to the bucket.
	 * @encryptionKey Optional customer encryption key.
	 * @getAsBinary   Force binary transport for images, PDFs and other arbitrary bytes.
	 *
	 * @return S3 response struct with body in response and headers in responseHeader.
	 */
	struct function getObject(
		required string bucketName = variables.defaultBucketName,
		required string uri,
		string encryptionKey = variables.defaultEncryptionKey,
		boolean getAsBinary  = false
	){
		buildUrlEndpoint( arguments.bucketName );
		requireBucketName( arguments.bucketName );
		return s3Request(
			method        = "GET",
			headers       = applyEncryptionHeaders( {}, arguments ),
			resource      = buildKeyName( arguments.uri, arguments.bucketName ),
			getAsBinary   = arguments.getAsBinary,
			parseResponse = !arguments.getAsBinary
		);
	}

	/**
	 * Return the R2-compatible SigV4 signer; the configured protocol is always V4.
	 *
	 * @type Upstream factory argument, retained for API compatibility.
	 *
	 * @return r2sdk.models.SignatureV4
	 */
	function createSignatureUtil( required string type ){
		return new r2sdk.models.SignatureV4();
	}

	/**
	 * Write an object using the S3 SDK transport with R2-compatible headers.
	 *
	 * @bucketName          Existing R2 bucket, or the configured default.
	 * @uri                 Object key relative to the bucket; do not URL-encode it first.
	 * @data                Text or binary object contents.
	 * @contentDisposition  HTTP Content-Disposition header.
	 * @contentType         MIME type, or auto for upstream detection.
	 * @contentEncoding     Content encoding of the supplied payload.
	 * @HTTPTimeout         Request timeout in seconds.
	 * @cacheControl        HTTP Cache-Control header.
	 * @expires             HTTP Expires header.
	 * @acl                 Must be empty because R2 does not support ACLs.
	 * @metaHeaders         User metadata without the x-amz-meta- prefix.
	 * @md5                 Upstream Content-MD5 option.
	 * @storageClass        R2-supported storage class.
	 * @encryptionAlgorithm Optional supported S3 customer encryption algorithm.
	 * @encryptionKey       Optional customer encryption key; keep secret.
	 *
	 * @return ETag confirmed by the object store.
	 *
	 * @throws r2sdk.UnsupportedACL ,S3SDKError
	 */
	string function putObject(
		required string bucketName = variables.defaultBucketName,
		required string uri,
		any data                   = "",
		string contentDisposition  = "",
		string contentType         = ( variables.autoContentType ? "auto" : "text/plain" ),
		string contentEncoding     = "",
		numeric HTTPTimeout        = variables.defaultTimeOut,
		string cacheControl        = variables.defaultCacheControl,
		string expires             = "",
		any acl                    = variables.defaultACL,
		struct metaHeaders         = {},
		string md5                 = variables.autoMD5,
		string storageClass        = variables.defaultStorageClass,
		string encryptionAlgorithm = variables.defaultEncryptionAlgorithm,
		string encryptionKey       = variables.defaultEncryptionKey
	){
		rejectACL( arguments );
		arguments.acl = "";
		return super.putObject( argumentCollection = arguments );
	}

	/**
	 * Copy an object server-side; the source is never deleted by this method.
	 *
	 * @fromBucket                Source bucket.
	 * @fromURI                   Source object key.
	 * @toBucket                  Destination bucket.
	 * @toURI                     Destination key.
	 * @acl                       Must be empty; public access is a bucket setting.
	 * @metaHeaders               Metadata supplied to the S3 copy operation.
	 * @storageClass              R2-supported destination storage class.
	 * @contentType               Optional replacement MIME type.
	 * @throwOnError              Raise transport errors instead of returning false.
	 * @encryptionAlgorithm       Destination customer encryption algorithm.
	 * @encryptionKey             Destination customer encryption key.
	 * @encryptionAlgorithmSource Source customer encryption algorithm.
	 * @encryptionKeySource       Source customer encryption key.
	 *
	 * @return True when the object store confirms the copy.
	 *
	 * @throws r2sdk.UnsupportedACL ,S3SDKError
	 */
	boolean function copyObject(
		required string fromBucket = variables.defaultBucketName,
		required string fromURI,
		required string toBucket = variables.defaultBucketName,
		required string toURI,
		any acl             = variables.defaultACL,
		struct metaHeaders  = {},
		string storageClass = variables.defaultStorageClass,
		string contentType,
		boolean throwOnError             = variables.throwOnRequestError,
		string encryptionAlgorithm       = variables.defaultEncryptionAlgorithm,
		string encryptionKey             = variables.defaultEncryptionKey,
		string encryptionAlgorithmSource = variables.defaultEncryptionAlgorithm,
		string encryptionKeySource       = variables.defaultEncryptionKey
	){
		rejectACL( arguments );
		arguments.acl = "";
		return super.copyObject( argumentCollection = arguments );
	}

	/**
	 * Generate a path-style R2 presigned request URL without contacting R2.
	 *
	 * @bucketName      Existing bucket, or the configured default.
	 * @uri             Raw object key; the signer performs canonical encoding.
	 * @minutesValid    Lifetime in minutes; fractional minutes are accepted, from one second to seven days.
	 * @useSSL          Must match the configured endpoint scheme.
	 * @method          HTTP method the client must use.
	 * @acl             Must be empty.
	 * @metaHeaders     Headers the caller must send unchanged with the signed request.
	 * @contentType     Optional content type that must accompany the signed request.
	 * @responseHeaders Supported S3 response header overrides, without the response- prefix.
	 *
	 * @return Bearer URL; treat it as a temporary credential.
	 *
	 * @throws r2sdk.InvalidSignedURL ,r2sdk.UnsupportedACL
	 */
	string function getAuthenticatedURL(
		required string bucketName = variables.defaultBucketName,
		required string uri,
		numeric minutesValid = 60,
		boolean useSSL       = variables.ssl,
		string method        = "GET",
		any acl              = "",
		struct metaHeaders   = {},
		string contentType,
		struct responseHeaders = {}
	){
		rejectACL( arguments );
		var secondsValid = round( arguments.minutesValid * 60 );
		if ( !len( arguments.bucketName ) || secondsValid < 1 || secondsValid > 604800 ) {
			throw(
				type    = "r2sdk.InvalidSignedURL",
				message = "Supply a bucket and an expiry between one second and seven days."
			);
		}
		if ( arguments.useSSL != variables.ssl ) {
			throw(
				type    = "r2sdk.InvalidSignedURL",
				message = "The signed URL scheme must match the configured R2 endpoint."
			);
		}
		var headers = createMetaHeaders( arguments.metaHeaders );
		if ( !isNull( arguments.contentType ) ) {
			headers[ "content-type" ] = arguments.contentType;
		}
		var query = { "X-Amz-Expires" : secondsValid };
		for ( var header in arguments.responseHeaders ) {
			if (
				!listFindNoCase(
					"content-type,content-language,expires,cache-control,content-disposition,content-encoding",
					header
				)
			) {
				throw( type = "r2sdk.InvalidSignedURL", message = "Unsupported response header override." );
			}
			query[ "response-" & lCase( header ) ] = arguments.responseHeaders[ header ];
		}
		var key       = "/" & arguments.bucketName & "/" & reReplace( arguments.uri, "^/+", "" );
		var signature = variables.signatureUtil.generateSignatureData(
			requestMethod      = uCase( arguments.method ),
			hostName           = variables.URLEndpointHostname,
			requestURI         = key,
			requestBody        = "",
			requestHeaders     = headers,
			requestParams      = query,
			accessKey          = variables.accessKey,
			secretKey          = variables.secretKey,
			regionName         = variables.awsRegion,
			serviceName        = "s3",
			presignDownloadURL = true
		);
		return variables.URLEndpoint & signature.canonicalURI & "?" & signature.canonicalQueryString & "&X-Amz-Signature=" & signature.signature;
	}

	/**
	 * Reject the unsupported S3 ACL read API.
	 *
	 * @throws r2sdk.UnsupportedACL
	 */
	array function getAccessControlPolicy(){
		unsupportedACL();
	}

	/** R2 has no per-object ACL API. */
	struct function getObjectACL(){
		unsupportedACL();
	}

	/** R2 public access is configured on the bucket through Cloudflare. */
	function putBucketACL(){
		unsupportedACL();
	}

	/**
	 * Reject the unsupported S3 ACL write API.
	 *
	 * @throws r2sdk.UnsupportedACL
	 */
	void function setAccessControlPolicy(){
		unsupportedACL();
	}

	private void function rejectACL( required struct values ){
		if (
			!isNull( arguments.values.acl ) &&
			( !isSimpleValue( arguments.values.acl ) || len( arguments.values.acl ) )
		) {
			unsupportedACL();
		}
	}

	private void function unsupportedACL(){
		throw(
			type    = "r2sdk.UnsupportedACL",
			message = "R2 does not support object ACLs. Configure public access on the bucket in Cloudflare."
		);
	}

}
