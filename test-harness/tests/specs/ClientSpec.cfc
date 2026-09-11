component
	extends      ="coldbox.system.testing.BaseTestCase"
	appMapping   ="/harness"
	configMapping="harness.config.Coldbox"
{

	function run(){
		describe( "R2 client module", function(){
			beforeEach( function(){
				setup();
				variables.r2Client = getInstance( "Client@r2sdk" );
				variables.key      = "sdk/" & createUUID() & ".bin";
				variables.bytes    = binaryDecode( "00010203fffe80abcd2500", "hex" );
			} );
			it( "resolves configured independent WireBox clients", function(){
				var other = getInstance( "Client@r2sdk" );
				variables.r2Client.setDefaultBucketName( "different" );
				expect( other.getDefaultBucketName() ).toBe( "private-contract" );
				expect( other.getDefaultTimeOut() ).toBe( 5 );
				expect( other.getRetriesOnError() ).toBe( 0 );
			} );
			it( "preserves positional S3 writes and binary reads over signed HTTP", function(){
				expect( variables.r2Client.objectExists( "private-contract", key ) ).toBeFalse();
				expect( variables.r2Client.putObject( "private-contract", key, bytes ) ).notToBeEmpty();
				var response = variables.r2Client.getObject(
					bucketName  = "private-contract",
					uri         = key,
					getAsBinary = true
				).response;
				if ( !isBinary( response ) ) {
					response = response.toByteArray();
				}
				expect( hash( response, "SHA-256" ) ).toBe( hash( bytes, "SHA-256" ) );
				var objectInfo = variables.r2Client.getObjectInfo( "private-contract", key );
				expect( objectInfo[ "Content-Length" ] ).toBe( 11 );
				variables.r2Client.deleteObject( "private-contract", key );
				expect( variables.r2Client.objectExists( "private-contract", key ) ).toBeFalse();
			} );
			it( "preserves positional copies", function(){
				variables.r2Client.putObject( "private-contract", key, bytes );
				expect(
					variables.r2Client.copyObject(
						"private-contract",
						key,
						"private-contract",
						key & ".copy"
					)
				).toBeTrue();
				expect( variables.r2Client.objectExists( "private-contract", key & ".copy" ) ).toBeTrue();
			} );
			it( "creates usable signed URLs for encoded object names", function(){
				var name = "sdk/été + 25%.bin";
				variables.r2Client.putObject(
					bucketName = "private-contract",
					uri        = name,
					data       = bytes
				);
				var address = variables.r2Client.getAuthenticatedURL(
					bucketName   = "private-contract",
					uri          = name,
					minutesValid = 2
				);
				cfhttp(
					url         = address,
					method      = "GET",
					result      = "local.response",
					getAsBinary = "yes",
					timeout     = 5
				);
				expect( response.statusCode ).toStartWith( "200" );
				expect( hash( response.fileContent, "SHA-256" ) ).toBe( hash( bytes, "SHA-256" ) );
			} );
			it( "rejects expired and excessive signed URL lifetimes", function(){
				expect( function(){
					variables.r2Client.getAuthenticatedURL( "private-contract", key, 0 );
				} ).toThrow( "r2sdk.InvalidSignedURL" );
				expect( function(){
					variables.r2Client.getAuthenticatedURL( "private-contract", key, 10081 );
				} ).toThrow( "r2sdk.InvalidSignedURL" );
			} );
			it( "rejects object ACLs before making an HTTP request", function(){
				expect( function(){
					variables.r2Client.putObject(
						bucketName = "private-contract",
						uri        = key,
						data       = bytes,
						acl        = "public-read"
					);
				} ).toThrow( "r2sdk.UnsupportedACL" );
				expect( function(){
					variables.r2Client.getObjectACL( bucketName = "private-contract", uri = key );
				} ).toThrow( "r2sdk.UnsupportedACL" );
			} );
			it( "enforces the account endpoint, TLS, region and addressing style", function(){
				var remote = new r2sdk.models.Client(
					accessKey = "synthetic",
					secretKey = "synthetic",
					awsDomain = "0123456789abcdef0123456789abcdef.eu.r2.cloudflarestorage.com",
					awsRegion = "us-west-2",
					urlStyle  = "virtual",
					ssl       = false
				);
				expect( remote.getSSL() ).toBeTrue();
				expect( remote.getUrlStyle() ).toBe( "path" );
				expect( remote.getAwsRegion() ).toBe( "" );
				expect( function(){
					remote.getAuthenticatedURL( "private-contract", key, 2, false );
				} ).toThrow( "r2sdk.InvalidSignedURL" );
			} );
			it( "rejects absent credentials and unapproved hosts", function(){
				expect( function(){
					new r2sdk.models.Client( "", "", "example.test" );
				} ).toThrow( "r2sdk.InvalidCredentials" );
				expect( function(){
					new r2sdk.models.Client( "key", "secret", "127.0.0.1:8080" );
				} ).toThrow( "r2sdk.InvalidEndpoint" );
				expect( function(){
					new r2sdk.models.Client( "key", "secret", "example.test", true );
				} ).toThrow( "r2sdk.InvalidEndpoint" );
			} );
		} );
	}

}
