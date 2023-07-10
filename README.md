# Mediaconnect Stream Switcher
## Purpose
This is a work-in-progress proof of concept for an AWS [MediaConnect](https://aws.amazon.com/mediaconnect/) based solution to integrate live streams from any MediaConnect supported AWS region over the AWS global network and into a single live and preview stream. The benefit of this over using a single ingest is that regional ingests can be created to match physical location of content, and modern protocols for ingest can be used, such as [SRT](https://www.haivision.com/blog/all/rtmp-vs-srt/). This reduces the chance for data loss or additional latency traveling the public internet.
While [MediaLive](https://aws.amazon.com/medialive/) is an obvious choice for selecting between MediaConnect streams due to built-in functionality for this, it has limited support for multiple inputs (2 push inputs), and it adds a transcoding step. Any transcoding done to a stream will diminish the quality slightly, and two inputs is limiting (though more inputs are supported as pull). 
One solution to this problem is to directly switch between MediaConnect streams using a single output stream. Without reencoding, this results in a brief distortion to the stream between keyframes:

The envisioned use for this system is to switch between long-running streams i.e. for a change of artist in a festival, where a change would be less noticeable than in the middle of a livestream. In this usecase, the delay and distortion of switching streams is acceptable in exchange for no quality loss. Input streams are controlled to identical encoding parameters. 

##  Architecture

As this is a proof of concept and not designed for enterprise production use, some tradeoffs are made in the architecture for simplicity and to control costs:
- Load balancers, which have a constant running cost, are not used in favour of public IPs. This would normally raise security and avilaibility concerns.
- VPC peering connections are used rather than a Transit Gateway, which would simplify networking, to avoid the constant running cost of the latter.
- Security is not a focus at this stage, though IAM permissions, security groups, etc are still in place. 

The architecture is shown below:

- MediaConnect streams are accessed by their assigned public IP. Their outbound endpoint is assigned to a (VPC interface)[https://docs.aws.amazon.com/mediaconnect/latest/ug/vpc-interfaces.html], isolated from the public internet and the output MediaConnect stream may access ingest endpoints through a VPC peering connection. 
- SRT is chosen as the streaming protocol. Password encryption is supported through (AWS Secrets Manager)[https://docs.aws.amazon.com/mediaconnect/latest/ug/data-protection.html].
- A web application hosted on ECS may access the Lambda-based API through API Gateway. The API makes a call through Boto3 to the Live and Preview MediaConnect streams to switch between different ingests. 
- IPs may be matched to subdomains through Route53. 
- Configuration details of the streaming architecture are stored in a JSON file on S3. This is accessed by Terraform and CloudFormation to deploy infrastructure to whatever regions are required (CloudFormation is required as Terraform MediaConnect support is (unavailable)[https://github.com/hashicorp/terraform-provider-aws/issues/26494] ). The file may also be accessed by the control interface to populate fields.

## Progress

- The base Terraform and CloudFormation is complete
- Boto3 scripts need to be created to automate the creation of the private VPC network due to (limitations)[https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-mediaconnect-flowvpcinterface.html] in CloudFormation.
- The API backend needs to be created
- The web control panel is hosted in another repo, but will need to be updated to utilize the API.
- Testing of the system needs to be done