package uk.ac.cam.lib.cudl.awslambda.handlers;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.SQSEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import uk.ac.cam.lib.cudl.awslambda.input.S3Input;
import uk.ac.cam.lib.cudl.awslambda.model.ReceivedSQSMessage;
import uk.ac.cam.lib.cudl.awslambda.util.RefreshHelper;
import uk.ac.cam.lib.cudl.awslambda.util.SQSHelper;

import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

public abstract class AbstractRequestHandler implements RequestHandler<SQSEvent, String> {

    private static final Logger logger = LoggerFactory.getLogger(AbstractRequestHandler.class);

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

        SQSHelper handler = new SQSHelper();
        ArrayList<Exception> errors = new ArrayList<>();
        RefreshHelper refreshHelper = new RefreshHelper();

        List<SQSEvent.SQSMessage> events = sqsEvent.getRecords();
        for (SQSEvent.SQSMessage message : events) {
            try {
                ReceivedSQSMessage receivedSQSMessage = handler.getTypeOfEvent(message, context);
                switch (receivedSQSMessage.getEventType()){
                    case TestEvent:
                        // do nothing
                        break;
                    case ObjectCreated:
                        handlePutEvent(receivedSQSMessage.getS3Bucket(), receivedSQSMessage.getS3Key(), context);
                        refreshHelper.refreshCache();
                        break;
                    case ObjectRemoved:
                        handleDeleteEvent(receivedSQSMessage.getS3Bucket(), receivedSQSMessage.getS3Key(), context);
                        refreshHelper.refreshCache();
                        break;
                }
            } catch (Exception e) {
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

    protected File getSourceFile(String srcBucket, String srcKey, Context context, S3Input s3Input, String tmpDir) throws Exception {
        // Get the source file from s3
        logger.info("get Source File");

        String tmpFile = tmpDir + context.getAwsRequestId();
        Files.createDirectories(Path.of(tmpFile));

        return s3Input.getFile(srcBucket, srcKey, new File(tmpFile+File.separator+Math.random()+"_source"));

    }

    protected String getSourceString(String srcBucket, String srcKey, S3Input s3Input)  {
        // Get the source file from s3
        logger.info("get Source String");

        return s3Input.getString(srcBucket, srcKey);

    }

    public abstract String handlePutEvent (String srcBucket, String srcKey, Context context) throws Exception;
    public abstract String handleDeleteEvent (String srcBucket, String srcKey, Context context) throws Exception;
}
