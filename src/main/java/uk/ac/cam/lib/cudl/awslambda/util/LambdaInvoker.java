package uk.ac.cam.lib.cudl.awslambda.util;

import com.amazonaws.regions.Regions;
import com.amazonaws.services.lambda.AWSLambda;
import com.amazonaws.services.lambda.AWSLambdaAsyncClient;
import com.amazonaws.services.lambda.model.InvocationType;
import com.amazonaws.services.lambda.model.InvokeRequest;
import com.amazonaws.services.lambda.model.InvokeResult;
import com.amazonaws.services.lambda.runtime.events.SQSEvent;
import org.apache.commons.text.StringEscapeUtils;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

public class LambdaInvoker {

    final AWSLambda client = AWSLambdaAsyncClient.builder().withRegion(Regions.EU_WEST_1).build();

    // async
    public void runWithPayload(String functionName, String body) {

        InvokeRequest request = new InvokeRequest();

        String escaped = StringEscapeUtils.escapeJson(body);
        SQSEvent.SQSMessage message = new SQSEvent.SQSMessage();
        message.setBody("\""+escaped+"\"");

        List<SQSEvent.SQSMessage> messages = new ArrayList<>();
        messages.add(message);
        SQSEvent event = new SQSEvent();
        event.setRecords(messages);
        JSONObject payloadJSON = new JSONObject(event.toString());

        request.withFunctionName(functionName).withPayload(payloadJSON.toString()).setInvocationType(InvocationType.Event);

        InvokeResult invoke = client.invoke(request);
        System.out.println("Result invoking " + functionName + ": " + invoke);
    }

}