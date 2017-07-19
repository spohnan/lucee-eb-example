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
#template: package
#	@find $(BUILD_DIR) -type f -name "*.template" | xargs sed -i 's/VERSION_STRING_TOKEN/$(VERSION)/g'
#	@find $(BUILD_DIR) -type f -name "*.template" | xargs sed -i 's/KEY_PREFIX_TOKEN/$(subst /,\/,$(KEY_NAME))/g'

#
# Take the finished artifacts and push them up into the S3 bucket
#
push:
	@echo "Copying deployment bundle to s3://$(BUCKET_NAME)/$(KEY_NAME) ..."
	@aws s3 sync build/dist/target/*-deployment-bundle/ s3://$(BUCKET_NAME)/$(KEY_NAME)/ \
		--delete \
		--only-show-errors \
		--acl public-read

#
# Run the CloudFormation validation check against our template we just uploaded to ensure there are no errors
#
#validate: push
#	@echo "Validating CloudFormation template"
#	@aws cloudformation \
#		validate-template \
#		--template-url https://s3.amazonaws.com/$(BUCKET_NAME)/$(KEY_NAME)/cloudformation/$(TEMPLATE_NAME).template

#
# The open command is only available on a Mac but you could also just echo out the quicklink to the console
#
#deploy-console: validate
#	@open "$(CONSOLE_URL)$(CONSOLE_ARGS)"

#
# Same as above but with no deployment prerequisite.
# Meant to deploy existing versions ex: "VERSION=1.2.3 make deploy-version-console"
#
#deploy-version-console:
#	@open "$(CONSOLE_URL)$(CONSOLE_ARGS)"

#
# During development you can build and deploy to a local Tomcat instance of the same version as used by Beanstalk
#
tomcat-run:
	@mvn install
	@mvn --projects build/tomcat cargo:run

#
# This is run once after the project is first checked out to intialize the deployment toolchain
#
init:
	# Clients will need Python 2.7.x installed as a deployment prereq
	pip install --upgrade virtualenv
	virtualenv deploy
	. deploy/bin/activate
	pip install --upgrade sceptre awscli awsebcli

validate:
	@sceptre $(SCEPTRE_ARGS) validate-template $(ENV) $(TEMPLATE_NAME)

upload:
	@aws s3 sync cloudformation/templates/ s3://$(BUCKET_NAME)/$(KEY_NAME)/cloudformation/ --delete --only-show-error

deploy: upload validate
	@sceptre $(SCEPTRE_ARGS) create-stack $(ENV) $(TEMPLATE_NAME)

terminate:
	@sceptre $(SCEPTRE_ARGS) delete-stack $(ENV) $(TEMPLATE_NAME)

outputs:
	@sceptre $(SCEPTRE_ARGS) describe-stack-outputs  $(ENV) $(TEMPLATE_NAME)