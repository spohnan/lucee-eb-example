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

all: clean package push test tomcat-run validate
.PHONY: all

clean:
	@mvn clean

package:
	@mvn package

push:
	@aws s3 sync . s3://$(BUCKET_NAME)/$(TEMPLATE_NAME) \
		--delete \
		--only-show-errors \
		--exclude "*" --include "*.template" \
		--acl public-read

test: validate
	@open "https://console.aws.amazon.com/cloudformation/home?region=$(AWS_DEFAULT_REGION)#/stacks/new?stackName=$(TEMPLATE_NAME)-$$(date +'%H%M%S')&templateURL=https://s3.amazonaws.com/cfn-andyspohn-com/$(TEMPLATE_NAME)/cloudformation/$(TEMPLATE_NAME).template"

tomcat-run:
	@mvn --activate-profiles war-only-packaging install
	@mvn --activate-profiles war-only-packaging --projects build/tomcat cargo:run

validate: push
	@aws cloudformation \
		validate-template \
		--template-url https://s3.amazonaws.com/$(BUCKET_NAME)/$(TEMPLATE_NAME)/cloudformation/$(TEMPLATE_NAME).template