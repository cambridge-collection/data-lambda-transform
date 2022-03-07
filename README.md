## Building locally using ant:

### Prereqs

Install Ant

### Building page extracts in dist

```ant -noclasspath -buildfile ./bin/build.xml```

## Building for upload to AWS Lambda

This will delete all existing transcription (WARNING!)

`aws s3 rm --dryrun --recursive s3://cudl-transcriptions-staging/html/data/tei/`

Copy over the generated files into s3 staging

`aws s3 sync --dryrun --size-only --delete dist/cudl-data/data/tei/ s3://cudl-transcriptions-staging/html/data/tei/` 

*Note: REMOVE --dryrun when you are happy with the result of the command to run it for real.*

### Prereqs

Install maven, Java 11.  
Set JAVA_HOME to java 11 

### Building jar

Make sure you set JAVA_HOME to be your java 11 installation. 
Then run: 

mvn clean compile assembly:single
 
 upload target/AWSLambda_CUDLPackageDataJSON-1.0-SNAPSHOT-jar-with-dependencies.jar
 to AWS function.  Tests are defined in the aws console.
 
 Handler should be set to: 
 
 ``uk.ac.cam.lib.cudl.awslambda.handlers.XSLTTransformRequestHandler::handleRequest``

## Notes

The creation of the TEI page excerpts and the html page renderings are created by two XSLT stylesheets. 

1) pagify.xsl

Feed this stylesheet a master TEI transcription (ie. full volume) and it will iterate over each of the surface elements (which map image files) and extract the corresponding page transcription, if any. There is no reason to specify an output document when performing a transformation. The stylesheet creates page extracts using xs:result-document. It dumps the files, with their full nested path, into ./dist. The ant build pipes stdout into ./tmp but I suppose that /dev/null would work just as well.

pagify.xsl includes a stylesheet called prune.xsl. This file is intended to perform any post extraction fixes that are specific to your data set. The current file, for example, removes all the metadata for casebook cases or darwin letters from other pages in the document. As these are entirely bespoke changes, it didn't feel appropriate to put them into the main page extractor. The generic version of this file would simply include a straightforward identity transform copy of all data. Those who implement the framework would be responsible for providing their own unique templates.

Future plans are to include a schema-aware format and indent whitespace cleaner.

NOTE: The pagify script also handles chunking data if the num_chunks > 1

In this case the pagify script generates chunked tei xml instead of pagified xml. These chunks then need to be
input into the pagify script again with num_chunks set to 1 to pagify.

2) msTeiTrans.xsl

This is a straightforward transformation. Feed it all the page xml transcriptions in ./dist and it will create corresponding html renderings. You will have to specify the output document path and filename. I suggest replicating the entire path and name of the file and just replacing the extension with html.

