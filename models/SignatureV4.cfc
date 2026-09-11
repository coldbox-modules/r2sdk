/** Supply explicit UTC timestamps across engines; retain the SDK's SigV4 implementation. */
component extends="s3sdk.models.Sv4Util" {

	/**
	 * Sign an S3 request using the upstream SigV4 algorithm and an explicit UTC clock.
	 *
	 * @requestMethod      HTTP method to sign.
	 * @hostName           Account endpoint hostname, including port for loopback fixtures.
	 * @requestURI         Raw bucket and object path.
	 * @requestBody        Payload bytes or text.
	 * @requestHeaders     Headers included in signing.
	 * @requestParams      Query parameters before signing.
	 * @accessKey          S3 access key ID.
	 * @secretKey          S3 secret key.
	 * @regionName         R2 region alias; normally empty.
	 * @serviceName        Normally s3.
	 * @excludeHeaders     Headers omitted from the canonical request.
	 * @amzDate            Optional yyyyMMdd'T'HHmmss'Z' timestamp; must accompany dateStamp.
	 * @dateStamp          Optional yyyyMMdd date; must accompany amzDate.
	 * @presignDownloadURL Sign query parameters instead of an Authorization header.
	 *
	 * @return Upstream canonical request, signature, headers, and query data.
	 *
	 * @throws r2sdk.InvalidSigningDate
	 */
	struct function generateSignatureData(
		required string requestMethod,
		required string hostName,
		required string requestURI,
		required any requestBody,
		required struct requestHeaders,
		required struct requestParams,
		required string accessKey,
		required string secretKey,
		required string regionName,
		required string serviceName,
		array excludeHeaders = [],
		string amzDate,
		string dateStamp,
		boolean presignDownloadURL = false
	){
		// On BoxLang an omitted optional argument can still exist with a null
		// value. The upstream keyExists check otherwise replaces both dates
		// with null. Explicit values also make this independent of local TZ.
		if ( isNull( arguments.amzDate ) && isNull( arguments.dateStamp ) ) {
			var formatter = createObject( "java", "java.time.format.DateTimeFormatter" )
				.ofPattern( "yyyyMMdd'T'HHmmss'Z'" )
				.withZone( createObject( "java", "java.time.ZoneOffset" ).UTC );
			arguments.amzDate   = formatter.format( createObject( "java", "java.time.Instant" ).now() );
			arguments.dateStamp = left( arguments.amzDate, 8 );
		} else if ( isNull( arguments.amzDate ) || isNull( arguments.dateStamp ) ) {
			throw(
				type    = "r2sdk.InvalidSigningDate",
				message = "Supply both amzDate and dateStamp when overriding the signing clock."
			);
		}
		return super.generateSignatureData( argumentCollection = arguments );
	}

}
