#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Settings you might want to set externally ex: VERSION=0.0.1 make create
#

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
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Project naming convention settings. Probably don't want to mess with these

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

#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Various housekeeping settings

#
# Check to ensure users have activated the python virtualenv before running sceptre commands
#
sceptre-exists: ; @which sceptre > /dev/null || echo "Run the following command to switch to deploy mode and then re-run your comand:\nsource packaging/deploy/bin/activate\n"

#
# Construct the S3 keyname based on the version (either detected from Maven or set externally) and dev status
#
KEY_NAME := $(TEMPLATE_NAME)$(DEV_RELEASE)/$(VERSION)

#
# Pass all the common args to every sceptre call to simplify
#
SCEPTRE_ARGS := --var "bucket_name=$(BUCKET_NAME)" --var "key_name=$(KEY_NAME)" --var "version=$(VERSION)" --var "allowed_ip_cidr=$(ALLOWED_IP_CIDR)" --dir "cloudformation"

help:
	@echo ""
	@echo " --- Development Targets ---"
	@echo "init:        Run once after the project is first checked out to intialize the deployment toolchain"
	@echo "clean:       Remove all temporary build files"
	@echo "package:     Clean, build and then package all of the application artifacts"
	@echo "tomcat-run:  Package application artifacts and then run in a local Tomcat server"
	@echo ""
	@echo "--- S3 Operations ---"
	@echo "upload:      Package application artifacts and then upload them to the S3 bucket"
	@echo "upload-only: Skip application rebuild and just upload existing artifacts"
	@echo ""
	@echo "--- Cloudformation orchestration targets ---"
	@echo "create:       Create an application stack"
	@echo "update:       Update an application stack"
	@echo "delete:       Delete an application stack"
	@echo "outputs:      Display the stack outputs like the address to the load balancer"
	@echo ""
	@echo "--- Packaging targets ---"
	@echo "dist:         Create a distribution package containing all app and doc artifacts"
	@echo "docs:         Generate documentation"
	@echo ""
.PHONY: help

#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Project initialization and build targets

#
# This is run once after the project is first checked out to intialize the deployment toolchain
#
init:
	pip install --upgrade virtualenv
	virtualenv packaging/deploy
	packaging/deploy/bin/pip install --upgrade sceptre awscli awsebcli
.PHONY: init

#
# All temporary files are stored within each module's target/ directory. Remove them all
#
clean:
	@mvn clean
.PHONY: clean

#
# The Maven package step will compile, test and then package up code into artifacts
# https://maven.apache.org/guides/introduction/introduction-to-the-lifecycle.html
#
package: clean
	@mvn package
.PHONY: package

#
# During development you can build and deploy to a local Tomcat instance of the same version as used by Beanstalk
#
tomcat-run:
	@mvn install
	@mvn --projects build/tomcat cargo:run
.PHONY: tomcat-run

#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Targets that push files to S3

#
# Upload the local application artifacts and Cloudformation templates into S3 using version prefixes
#
upload-files:
	@aws s3 sync cloudformation/templates/ s3://$(BUCKET_NAME)/$(KEY_NAME)/cloudformation/ --only-show-errors --acl public-read --delete
	@aws s3 cp build/dist/target/*-beanstalk.zip s3://$(BUCKET_NAME)/$(KEY_NAME)/ --only-show-errors --acl public-read
.PHONY: upload-files

#
# Just upload the files, don't rebuild
#
upload-only: upload-files
.PHONY: upload-only

#
# Rebuld the artifacts and then upload
#
upload: package upload-files
.PHONY: upload

#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Cloudformation orchestration targets

#
# Create an application stack
#
create: sceptre-exists
	@sceptre $(SCEPTRE_ARGS) create-stack $(ENV) $(TEMPLATE_NAME)
.PHONY: create

#
# Update a stack. If a version other than the current code is desired set the version ex: VERSION=4.0.0 make update
#
update: sceptre-exists
	@sceptre $(SCEPTRE_ARGS) update-stack $(ENV) $(TEMPLATE_NAME)
.PHONY: update

#
# Delete an application stack
#
delete: sceptre-exists
	@sceptre $(SCEPTRE_ARGS) delete-stack $(ENV) $(TEMPLATE_NAME)
.PHONY: delete

#
# Get the outputs from the stack. The BeanstalkEndpointURL contains the URL to the load balancer
#
outputs: sceptre-exists
	@sceptre $(SCEPTRE_ARGS) describe-stack-outputs $(ENV) $(TEMPLATE_NAME)
.PHONY: outputs

#
# Validate the Cloudformation main template
#
validate: sceptre-exists
	@sceptre $(SCEPTRE_ARGS) validate-template $(ENV) $(TEMPLATE_NAME)
.PHONY: validate

#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Packaging and documentation targets

#
# Run the all of the doc output profiles and dist module
#
dist:
	@mvn -P dist,pdf,html package
.PHONY: dist

#
# Activate all the output format profiles for the docs module
#
docs:
	@mvn -P pdf,html -pl docs
.PHONY: docs

#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Docker container wtih preloaded utilities

#
# If lucee-eb-demo/deploy is not available from a container registry build it locally
#
docker-build:
	@docker build -t lucee-eb-demo/deploy packaging/docker/
.PHONY: docker-build

#
# Run the container with all build and deploy artifacts preloaded
#
docker-deploy:
	@docker run -it --rm -w /src \
		-v ~/.aws:/home/deploy/.aws -v $$(pwd):/src -v ~/.m2:/home/deploy/.m2 \
		lucee-eb-demo/deploy
.PHONY: docker-deploy