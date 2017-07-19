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
# The sceptre deployment environment to use
#
ifeq ($(ENV),)
ENV := dev
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

#
# Used to set security group rules. Defaults to your specific IP and requires that curl is installed locally
#
ifeq ($(ALLOWED_IP_CIDR),)
ALLOWED_IP_CIDR := $(shell curl -s https://api.ipify.org)/32
endif

KEY_NAME := $(TEMPLATE_NAME)$(DEV_RELEASE)/$(VERSION)
BUILD_DIR := build/dist/target/*-deployment-bundle/
CONSOLE_URL := https://console.aws.amazon.com/cloudformation/home?region=$(AWS_DEFAULT_REGION)\#/stacks/new
CONSOLE_ARGS := ?stackName=$(TEMPLATE_NAME)-$$(date +'%H%M%S')&templateURL=https://s3.amazonaws.com/cfn-andyspohn-com/$(KEY_NAME)/cloudformation/$(TEMPLATE_NAME).template
SCEPTRE_ARGS := --var "bucket_name=$(BUCKET_NAME)" --var "key_name=$(KEY_NAME)" --var "version=$(VERSION)" --var "allowed_ip_cidr=$(ALLOWED_IP_CIDR)" --dir "cloudformation"

all: clean package setup push validate deploy-console tomcat-run
.PHONY: all

#
# This is run once after the project is first checked out to intialize the deployment toolchain
#
init:
	# Clients will need Python 2.7.x installed as a deployment prereq
	pip install --upgrade virtualenv
	virtualenv packaging/deploy
	packaging/deploy/bin/pip install --upgrade sceptre awscli awsebcli

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
# During development you can build and deploy to a local Tomcat instance of the same version as used by Beanstalk
#
tomcat-run:
	@mvn install
	@mvn --projects build/tomcat cargo:run

#activate:
#	echo "source packaging/deploy/bin/activate"

#
# Validate the Cloudformation main template
#
validate:
	@sceptre $(SCEPTRE_ARGS) validate-template $(ENV) $(TEMPLATE_NAME)

#
# Upload the local application artifacts and Cloudformation templates into S3 using version prefixes
#
upload-files:
	@aws s3 sync cloudformation/templates/ s3://$(BUCKET_NAME)/$(KEY_NAME)/cloudformation/ --only-show-errors --acl public-read --delete
	@aws s3 cp build/dist/target/*-beanstalk.zip s3://$(BUCKET_NAME)/$(KEY_NAME)/ --only-show-errors --acl public-read

#
# Just upload the files, don't rebuild
#
upload-only: upload-files

#
# Rebuld the artifacts and then upload
#
upload: package upload-files

#
# Deploy an application stack
#
deploy:
	@sceptre $(SCEPTRE_ARGS) create-stack $(ENV) $(TEMPLATE_NAME)

#
# Update a stack. If a version other than the current code is desired set the version ex: VERSION=4.0.0 make update
#
update:
	@sceptre $(SCEPTRE_ARGS) update-stack $(ENV) $(TEMPLATE_NAME)

#
# Terminate an application stack
#
terminate:
	@sceptre $(SCEPTRE_ARGS) delete-stack $(ENV) $(TEMPLATE_NAME)

#
# Get the outputs from the stack. The BeanstalkEndpointURL contains the URL to the load balancer
#
outputs:
	@sceptre $(SCEPTRE_ARGS) describe-stack-outputs  $(ENV) $(TEMPLATE_NAME)

#
# If lucee-eb-demo/deploy is not available from a container registry build it locally
#
docker-build:
	@docker build -t lucee-eb-demo/deploy packaging/docker/

#
# Run the container with all build and deploy artifacts preloaded
#
docker-deploy:
	@docker run -it --rm -w /src \
		-v ~/.aws:/home/deploy/.aws -v $$(pwd):/src -v ~/.m2:/home/deploy/.m2 \
		lucee-eb-demo/deploy