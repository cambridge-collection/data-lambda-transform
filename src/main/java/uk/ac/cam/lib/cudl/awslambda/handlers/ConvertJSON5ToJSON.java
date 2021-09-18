package uk.ac.cam.lib.cudl.awslambda.handlers;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.SQSEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import uk.ac.cam.lib.cudl.awslambda.util.SQSHandler;
import uk.ac.cam.lib.cudl.awslambda.model.ReceivedSQSMessage;

import javax.xml.transform.TransformerException;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

public class ConvertJSON5ToJSON implements RequestHandler<SQSEvent, String> {

    private static final Logger logger = LoggerFactory.getLogger(ConvertJSON5ToJSON.class);
    private final SQSHandler handler;

    public ConvertJSON5ToJSON() {
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

    /**
     *
     * @param srcBucket
     * @param srcKey
     * @param context
     * @return
     * @throws IOException
     * @throws TransformerException
     */
    public String handlePutEvent(String srcBucket, String srcKey, Context context) throws IOException, TransformerException {
        // TODO



    return null;
    }


    public String handleDeleteEvent(String srcBucket, String srcKey, Context context) throws IOException, TransformerException {
        // TODO
    return null;
    }
}
