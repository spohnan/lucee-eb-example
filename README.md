## Lucee Elastic Beanstalk Example

### Overview

This project demonstrates the ability to build multiple projects and deploy them to Elastic Beanstalk using Maven.

### Functionality

A Makefile contains all of the one-liner commands and executes them in the right order.

`make tomcat-run` - Package and run the current project code on a local Tomcat instance.
Open `http://localhost:8080` in a browser once started.

`make deploy-version-console` - Deploy an existing version using the console. Set the version as 
an environment variable before calling ex: "VERSION=0.0.3 make deploy-version-console"

`make deploy-console` - Build and push local code to S3 and then deploy using the console.

### Code Structure

```
├── app
│   ├── api
│   └── ui
├── build
│   ├── dist
│   └── tomcat
└── cloudformation
```

* The app module contains the two applications
    * api - A Lucee API project
    * ui - A ReactJS front end
* The build modules orchestrate various build functions
    * dist - Contains finished artifacts in `dist/target`
    * tomcat - Runs both apps in a local Tomcat instance
* The cloudformation directory contains a really simple deployment script but for production we'd use [something more substantial](https://github.com/aws-quickstart/quickstart-enterprise-accelerator-nist)

### S3 Structure

```
s3-bucket/
└── lucee-eb-example
    ├── 0.0.3
    │   ├── cloudformation
    │   └── lucee-eb-example-0.0.3-beanstalk.zip
    └── dev
        └── 0.0.4-SNAPSHOT
            ├── cloudformation
            └── lucee-eb-example-0.0.4-beanstalk.zip
```

During development when `make deploy-console` is called the snapshot version will overwrite the previous copy under the 
dev key prefix. When a maven release is performed a final tagged version of the code is uploaded with a version prefix 
which makes it available ever after for deployment using a command like `VERSION=0.0.3 make deploy-version-console`

### Release Process

The first two commands are the standard Maven release process but as release:prepare tags the non snapshot version and
then also advances to the next snapshot version in a single step we have to go back, check out the tagged release and
push to our S3 repo afterwards.

```
mvn release:prepare
mvn release:perform -Darguments="-Dmaven.deploy.skip=true"
# Maven will have started a new SNAPSHOT version already so check out the release and push to S3
git checkout tags/vTAG_NUMBER
make push
git checkout -
```