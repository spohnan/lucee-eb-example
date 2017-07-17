#
# S3 bucket to which deployment bundle will be uploaded when publishing
# or downloaded when deploying
#
ifeq ($(BUCKET_NAME),)
BUCKET_NAME?=cfn-andyspohn-com
endif

#
# Beanstalk will only download artifacts from S3 in the same region
#
ifeq ($(AWS_DEFAULT_REGION),)
AWS_DEFAULT_REGION?=us-east-1
endif

#
# By default the most recent Maven project version is used but for the deployment scenario
# you could set a prior version to deploy ex: "VERSION=1.0.1 make deploy-console"
#
ifeq ($(VERSION),)
VERSION := $(shell mvn -q -Dexec.executable="echo" -Dexec.args='$${project.version}' --non-recursive org.codehaus.mojo:exec-maven-plugin:1.3.1:exec)
endif

#
# Assume we're storing many projects in the same S3 bucket, start key prefix with project name
#
ifeq ($(TEMPLATE_NAME),)
TEMPLATE_NAME?=lucee-eb-example
endif

#
# If this version a snapshot add a dev prefix
#
ifeq ($(findstring -SNAPSHOT, $(VERSION)),-SNAPSHOT)
DEV_RELEASE?=/dev
endif

KEY_NAME := $(TEMPLATE_NAME)$(DEV_RELEASE)/$(VERSION)
BUILD_DIR := build/dist/target/*-deployment-bundle/

all: clean package setup push validate deploy-console tomcat-run
.PHONY: all

#
# All temporary files are stored within each module's target/ directory. Remove them all
#
clean:
	@mvn clean

#
# The Maven package step will compile, test and then package up code into artifacts
# https://maven.apache.org/guides/introduction/introduction-to-the-lifecycle.html
#
package: clean
	@mvn package

#
# The CloudFormation template(s) checked into source control have tokens that get replaced
# with the actual version and location strings before we push them up into S3
#
template: package
	@find $(BUILD_DIR) -type f -name "*.template" | xargs sed -i 's/VERSION_STRING_TOKEN/$(VERSION)/g'
	@find $(BUILD_DIR) -type f -name "*.template" | xargs sed -i 's/KEY_PREFIX_TOKEN/$(subst /,\/,$(KEY_NAME))/g'

#
# Take the finished artifacts and push them up into the S3 bucket
#
push: template
	@echo "Copying deployment bundle to S3 ..."
	@aws s3 sync build/dist/target/*-deployment-bundle/ s3://$(BUCKET_NAME)/$(KEY_NAME)/ \
		--delete \
		--only-show-errors \
		--acl public-read

#
# Run the CloudFormation validation check against our template we just uploaded to ensure there are no errors
#
validate: push
	@echo "Validating CloudFormation template"
	@aws cloudformation \
		validate-template \
		--template-url https://s3.amazonaws.com/$(BUCKET_NAME)/$(KEY_NAME)/cloudformation/$(TEMPLATE_NAME).template

#
# The open command is only available on a Mac but you could also just echo out the quicklink to the console
#
deploy-console: validate
	@open "https://console.aws.amazon.com/cloudformation/home?region=$(AWS_DEFAULT_REGION)#/stacks/new?stackName=$(TEMPLATE_NAME)-$$(date +'%H%M%S')&templateURL=https://s3.amazonaws.com/cfn-andyspohn-com/$(KEY_NAME)/cloudformation/$(TEMPLATE_NAME).template"

#
# During development you can build and deploy to a local Tomcat instance of the same version as used by Beanstalk
#
tomcat-run:
	@mvn install
	@mvn --projects build/tomcat cargo:run