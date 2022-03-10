### Prereqs

Install maven, Java 11.  
Set JAVA_HOME to java 11 

### Building jar

Make sure you set JAVA_HOME to be your java 11 installation. 
Then run: 

mvn clean compile assembly:single
 
 upload target/AWSLambda_DATA_Transform-<VERSION>-SNAPSHOT-jar-with-dependencies.jar
 to AWS function.  Tests are defined in the aws console.
 
 Handler changes depending on the function e.g. for copying file function it should be set to: 
 
 ``uk.ac.cam.lib.cudl.awslambda.handlers.CopyFileHandler::handleRequest``

### Making a Release

When you're ready to make a release you can run the following

      mvn release:prepare
      mvn release:perform

This will tag a version in git and upload it to s3.

After this is done you should run `git push` and `git push --tags` to mae sure the 
tags are pushed to the remote git repo.

After this version is published to s3 the AWS console can be used to update the lambda functions 
with the new version.  Once tested a new fixed version of the lambda function can be created and the 
LIVE alias updated to use this version.  This will make the live process use this code.

