package uk.ac.cam.lib.cudl.awslambda.util;

import com.amazonaws.services.lambda.AWSLambda;
import com.amazonaws.services.lambda.AWSLambdaClientBuilder;
import com.amazonaws.services.lambda.model.InvokeRequest;
import com.amazonaws.services.lambda.model.InvokeResult;
import com.amazonaws.services.lambda.runtime.events.SQSEvent;
import org.apache.commons.text.StringEscapeUtils;
import org.json.JSONObject;

import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.List;

public class LambdaInvoker {

    final AWSLambda client = AWSLambdaClientBuilder.standard().build();

    // async
    public void runWithPayload(String functionName, String body) {
        String escaped = StringEscapeUtils.escapeJson(body);
        SQSEvent.SQSMessage message = new SQSEvent.SQSMessage();
        message.setBody("\""+escaped+"\"");

        List<SQSEvent.SQSMessage> messages = new ArrayList<>();
        messages.add(message);
        SQSEvent event = new SQSEvent();
        event.setRecords(messages);
        JSONObject payloadJSON = new JSONObject(event.toString());

        InvokeRequest request = new InvokeRequest().withFunctionName(functionName).withInvocationType("Event").withLogType("Tail")
                .withPayload(ByteBuffer.wrap(payloadJSON.toString().getBytes()));

        InvokeResult invoke = client.invoke(request);
        System.out.println("Result invoking " + functionName + ": " + invoke);
    }

}