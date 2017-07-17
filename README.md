## Lucee Elastic Beanstalk Example

### Overview

This project demonstrates the ability to build multiple projects and deploy them to Elastic Beanstalk using Maven.

### Functionality

A Makefile contains all of the one-liner commands and executes them in the right order.

`make tomcat-run` - Package and run the current project code on a local Tomcat instance.
Open `http://localhost:8080` in a browser once started.

`make deploy-version-console` - Deploy an existing version using the console. Set the version as 
an environment variable before calling ex: "VERSION 0.0.1 make deploy-version-console"

`make deploy-console` - Build and push local code to S3 and then deploy using the console.

### Structure

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
