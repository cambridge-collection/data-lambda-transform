package uk.ac.cam.lib.cudl.awslambda.handlers;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.SQSEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import uk.ac.cam.lib.cudl.awslambda.util.Properties;
import uk.ac.cam.lib.cudl.awslambda.util.S3Helper;
import uk.ac.cam.lib.cudl.awslambda.util.SQSHandler;
import uk.ac.cam.lib.cudl.awslambda.util.XSLTHelper;
import uk.ac.cam.lib.cudl.awslambda.model.ReceivedSQSMessage;

import javax.xml.transform.TransformerConfigurationException;
import javax.xml.transform.TransformerException;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * Triggered by a edit from cudl data in s3.  One event s3 is sent per file edited.  These are put into
 * a queue in SQS which can batch events in groups of up to 10.
 * NOTE DO NOT WRITE TO SAME S3 WHICH CONTAINS THE TRIGGER as this could cause an expensive loop.
 * so do not write to the data directory.
 * NOTE: THIS IS FOR SIMPLE one .xml file -> one file result transformations.
 * You can pass a list of transformations in the properties files (from s3).
 */
public class XSLTTransformRequestHandler implements RequestHandler<SQSEvent, String> {

    private static final Logger logger = LoggerFactory.getLogger(XSLTTransformRequestHandler.class);

    public final String functionName;
    private final List<String> xsltLocations;
    private final XSLTHelper xsltHelper;
    private final S3Helper s3Helper;
    private final String tmpDir;
    private final SQSHandler handler;

    public XSLTTransformRequestHandler() throws TransformerConfigurationException, IOException {

        Properties properties = new Properties();
        s3Helper = new S3Helper();
        xsltHelper = new XSLTHelper(s3Helper);
        tmpDir = properties.getProperty("TMP_DIR");

        functionName = properties.getProperty("FUNCTION_NAME");
        xsltLocations = Arrays.asList(properties.getProperty("XSLT").split(","));
        handler = new SQSHandler();

    }

    /**
     * For efficiency as much as possible should be done outside this function.
     * It also assumes that this is used for a lambda function which is configured to
     * only pass *.xml files suitable for transformation (via a SQS Queue).
     *
     * List of transformations to apply in properties. Should be s3 locations.
     *
     * @param context
     * @return
     */
    @Override
    public String handleRequest(SQSEvent sqsEvent, Context context) {

        ArrayList<Exception> errors = new ArrayList<>();
        List<SQSEvent.SQSMessage> events = sqsEvent.getRecords();
        for (SQSEvent.SQSMessage message : events) {
            try {
                ReceivedSQSMessage receivedSQSMessage = handler.getTypeOfEvent(message, context);
                switch (receivedSQSMessage.getEventType()){
                    case ObjectCreated:
                        handlePutEvent(receivedSQSMessage.getS3Bucket(), receivedSQSMessage.getS3Key(), context);
                        break;
                    case ObjectRemoved:
                        handleDeleteEvent(receivedSQSMessage.getS3Bucket(), receivedSQSMessage.getS3Key(), context);
                        break;
                }
            } catch (TransformerException | IOException e) {
                errors.add(e);
            }
        }

        if (errors.size()==0) {
            return "Ok";
        } else {

            for (Exception error : errors) {
                error.printStackTrace();
            }
            throw new RuntimeException("Found errors when processing this batch request: "+errors.size()+" " +
                    "errors found. Showing first error:", errors.get(0).getCause());

        }

    }

    public String handlePutEvent(String srcBucket, String srcKey, Context context) throws IOException, TransformerException {

        logger.info("Put Event");

        String dstKey = s3Helper.translateSrcKeyToDestKey(srcKey);

        String tmpFile = tmpDir + context.getAwsRequestId();
        Files.createDirectories(Path.of(tmpFile));

        // Chain together XSLT calls (from properties)
        File sourceFile = s3Helper.getFromS3(srcBucket, srcKey, new File(tmpFile+File.separator+Math.random()+"_source"));
        for (String xslt: xsltLocations) {
            File outputFile = new File(tmpFile+File.separator+Math.random()+"_output");
            xsltHelper.transformAndWriteToFile(sourceFile, xslt, outputFile);
            sourceFile = outputFile;
        }

        byte[] bytes = Files.readAllBytes(sourceFile.toPath());
        ByteArrayOutputStream baos = new ByteArrayOutputStream(bytes.length);
        baos.write(bytes, 0, bytes.length);

        s3Helper.writeToS3(baos, dstKey);

        return "Ok";

    }

    public String handleDeleteEvent(String srcBucket, String srcKey, Context context) {

/*        logger.info("Delete Event");
        // should be at same path as src but have dstPrefix and end in .html
        String dstKey = s3Helper.translateSrcKeyToDestKey(srcKey);
        s3Helper.deleteFromS3AllObjectsUnderPath(dstKey);*/
        return "OK";
    }
}
