## Lucee Elastic Beanstalk Example

### Overview

This project demonstrates the ability to build multiple projects and deploy them to Elastic Beanstalk using Maven.

### Functionality

A Makefile contains all of the one-liner commands and executes them in the right order.

`make tomcat-run` - Package and run the current project code on a local Tomcat instance.
Open `http://localhost:8080` in a browser once started.

### Code Structure

```
├── app
│   ├── api
│   └── ui
├── build
│   ├── dist
│   └── tomcat
├── cloudformation
│   ├── config
│   └── templates
└── packaging
    ├── deploy
    └── docker
```

* The app module contains the two applications
    * api - A Lucee API project
    * ui - A ReactJS front end
* The build modules orchestrate various build functions
    * dist - Contains finished artifacts in `dist/target`
    * tomcat - Runs both apps in a local Tomcat instance
* The cloudformation directory contains CF templates and config files by [Sceptre](https://sceptre.cloudreach.com/latest/)
    * The VPC deployment script is really basic in this example, for production we'd use [something more substantial](https://github.com/aws-quickstart/quickstart-enterprise-accelerator-nist)
* The packaging directory contains a Python virtual environment with all the needed modules installed to deploy the solution

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

CloudFormation and ElasticBeanstalk both pull artifacts from S3 so the development workflow involves developing and testing
locally using the `tomcat-run` target and when ready to deploy to AWS using the upload target prior to issuing a `create` or 
`update` of a stack. The Makefile will either detect the version of the code from the local Maven project or you can set a
specific version prior to calling a target to say update to a new version or create a stack of a specific version 
ex: `VERSION-0.0.3 make update`