// vim: set ts=2 sw=2 et :
package platforms

// #PlatformAWS defines concrete Amazon Web Services infrastructure parameters.
#PlatformAWS: {
	// AWS deployment region (e.g. "eu-central-1", "us-east-1")
	region?: string

	// Target AWS Account ID (12-digit string)
	accountId?: =~"^[0-9]{12}$" | string

	// Target VPC ID
	vpcId?: string

	// IAM Execution / Instance Role ARN
	iamRoleArn?: string

	// Target Subnet IDs
	subnetIds?: [...string]

	// S3 Object Storage bucket configuration
	s3?: {
		bucketName?: string
		prefix?:     string
		sse?:        "AES256" | "aws:kms" | string | *"AES256"
		...
	}

	// Scoped Terraform module configuration for AWS resources
	terraform?: {
		source?:  string
		version?: string
		inputs?: [string]: _
		...
	}

	// Driver engine for provisioning (defaults to terraform)
	driver?: *"terraform" | "opentofu" | "cdk" | string

	...
}
