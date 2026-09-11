/** Cloudflare R2 registration. Module loading does not contact the provider. */
component {

	this.title          = "Cloudflare R2 SDK";
	this.author         = "Eric Peterson";
	this.description    = "Cloudflare R2 object storage over the S3-compatible API.";
	this.version        = "0.1.0";
	this.cfmapping      = "r2sdk";
	this.modelNamespace = "r2sdk";
	this.autoMapModels  = false;
	this.dependencies   = [ "s3sdk" ];

	/** Override these through moduleSettings.r2sdk in the consuming application. */
	function configure(){
		settings = {
			"accessKey"              : "",
			"secretKey"              : "",
			"awsDomain"              : "",
			"defaultBucketName"      : "",
			"defaultTimeOut"         : 30,
			"retriesOnError"         : 3,
			"defaultCacheControl"    : "no-store, no-cache, must-revalidate",
			"autoContentType"        : true,
			"autoMD5"                : false,
			"debug"                  : false,
			"allowInsecureLocalhost" : false
		};
	}

	/** Register an independent configured client for each WireBox resolution. */
	function onLoad(){
		var mapping = binder
			.map( "Client@r2sdk" )
			.to( "#moduleMapping#.models.Client" )
			.into( "noscope" );
		for ( var key in settings ) {
			mapping.initArg( name = key, value = settings[ key ] );
		}
		binder.map( "SignatureV4@r2sdk" ).to( "#moduleMapping#.models.SignatureV4" );
	}

}
