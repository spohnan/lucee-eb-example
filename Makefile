#
# Push templates to S3, validate and a preloaded shortcut to the console (on Mac)
#

ifeq ($(BUCKET_NAME),)
BUCKET_NAME?=cfn-andyspohn-com
endif

ifeq ($(TEMPLATE_NAME),)
TEMPLATE_NAME?=lucee-eb-example
endif

ifeq ($(AWS_DEFAULT_REGION),)
AWS_DEFAULT_REGION?=us-east-1
endif

ifeq ($(VERSION),)
VERSION := $(shell mvn -q -Dexec.executable="echo" -Dexec.args='$${project.version}' --non-recursive org.codehaus.mojo:exec-maven-plugin:1.3.1:exec)
endif

# If this version a snapshot add a dev prefix
ifeq ($(findstring -SNAPSHOT, $(VERSION)),-SNAPSHOT)
DEV_RELEASE?=/dev
endif

BUILD_DIR := build/dist/target/*-deployment-bundle/
KEY_NAME := $(TEMPLATE_NAME)$(DEV_RELEASE)/$(VERSION)

all: clean package push test tomcat-run validate
.PHONY: all

clean:
	@mvn clean

package: clean
	@mvn package

setup: package
	@find $(BUILD_DIR) -type f -name "*.template" | xargs sed -i 's/VERSION_STRING_TOKEN/$(VERSION)/g'
	@find $(BUILD_DIR) -type f -name "*.template" | xargs sed -i 's/KEY_PREFIX_TOKEN/$(subst /,\/,$(KEY_NAME))/g'

push: setup
	@echo "Copying deployment bundle to S3 ..."
	@aws s3 sync build/dist/target/*-deployment-bundle/ s3://$(BUCKET_NAME)/$(KEY_NAME)/ \
		--delete \
		--only-show-errors \
		--acl public-read

validate: push
	@echo "Validating CloudFormation template"
	@aws cloudformation \
		validate-template \
		--template-url https://s3.amazonaws.com/$(BUCKET_NAME)/$(KEY_NAME)/cloudformation/$(TEMPLATE_NAME).template

deploy-console: validate
	@open "https://console.aws.amazon.com/cloudformation/home?region=$(AWS_DEFAULT_REGION)#/stacks/new?stackName=$(TEMPLATE_NAME)-$$(date +'%H%M%S')&templateURL=https://s3.amazonaws.com/cfn-andyspohn-com/$(KEY_NAME)/cloudformation/$(TEMPLATE_NAME).template"

tomcat-run:
	@mvn install
	@mvn --projects build/tomcat cargo:run