package uk.ac.cam.lib.cudl.awslambda.util;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.events.SQSEvent;
import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import uk.ac.cam.lib.cudl.awslambda.model.ReceivedSQSMessage;

public class SQSHelper {

    private static final Logger logger = LoggerFactory.getLogger(SQSHelper.class);

    public ReceivedSQSMessage getTypeOfEvent(SQSEvent.SQSMessage message, Context context) {

        logger.info("Event Received: "+message.getBody());

        JSONObject json = new JSONObject(message.getBody());
        JSONObject record = json.getJSONArray("Records").getJSONObject(0);
        String srcBucket = record.getJSONObject("s3").getJSONObject("bucket").getString("name");
        String srcKey = record.getJSONObject("s3").getJSONObject("object").getString("key");
        String eventName = record.getString("eventName");

        if (eventName != null && eventName.startsWith("ObjectCreated:")) {
            // put event
            return new ReceivedSQSMessage(ReceivedSQSMessage.eventTypes.ObjectCreated, srcBucket, srcKey);
        } else if (eventName != null && eventName.startsWith("ObjectRemoved:")) {
            // delete event
            return new ReceivedSQSMessage(ReceivedSQSMessage.eventTypes.ObjectRemoved, srcBucket, srcKey);
        }

        return null;
    }

}
