package uk.ac.cam.lib.cudl.awslambda.handlers;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.SQSEvent;
import uk.ac.cam.lib.cudl.awslambda.util.SQSHandler;
import uk.ac.cam.lib.cudl.awslambda.model.ReceivedSQSMessage;

import javax.xml.transform.TransformerException;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

public class ConvertJSONRelativePaths implements RequestHandler<SQSEvent, String> {

    private final SQSHandler handler;

    public ConvertJSONRelativePaths() {
        handler = new SQSHandler();
    }

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
        // TODO
        return null;
    }


    public String handleDeleteEvent(String srcBucket, String srcKey, Context context) throws IOException, TransformerException {
        // TODO
        return null;
    }
}
