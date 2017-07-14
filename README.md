## Lucee Elastic Beanstalk Example

### Overview

1. Builds a Lucee app with Maven producing the following artifacts (Run the `mvn` command to build):
    * A war file for use with local testing
    * A zip file containing the exploded war file that can be uploaded to beanstalk as a source bundle
    * A zip file containing the source bundle and CloudFormation scripts
1. Use CloudFormation to run in the supported Elastic Beanstalk [Java with Tomcat platform](http://docs.aws.amazon.com/elasticbeanstalk/latest/dg/concepts.platforms.html#concepts.platforms.java)
