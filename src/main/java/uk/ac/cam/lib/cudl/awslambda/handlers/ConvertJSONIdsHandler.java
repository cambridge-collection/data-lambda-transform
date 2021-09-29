package uk.ac.cam.lib.cudl.awslambda.handlers;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.SQSEvent;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import uk.ac.cam.lib.cudl.awslambda.model.ReceivedSQSMessage;
import uk.ac.cam.lib.cudl.awslambda.util.ConvertIdsToBeRelativeToRoot;
import uk.ac.cam.lib.cudl.awslambda.util.Properties;
import uk.ac.cam.lib.cudl.awslambda.util.S3Helper;
import uk.ac.cam.lib.cudl.awslambda.util.SQSHandler;

import javax.xml.transform.TransformerException;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

public class ConvertJSONIdsHandler implements RequestHandler<SQSEvent, String> {

    private static final Logger logger = LoggerFactory.getLogger(ConvertJSONIdsHandler.class);
    private final SQSHandler handler;
    private final S3Helper s3Helper;
    private final String tmpDir;

    public ConvertJSONIdsHandler() throws IOException {

        handler = new SQSHandler();
        Properties properties = new Properties();
        s3Helper = new S3Helper();
        tmpDir = properties.getProperty("TMP_DIR");
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

    public String handlePutEvent(String srcBucket, String srcKey, Context context) throws IOException {

        // Get the source file from s3
        logger.info("Put Event");

        String dstKey = s3Helper.translateSrcKeyToDestKey(srcKey);
        String tmpFile = tmpDir + context.getAwsRequestId();
        Files.createDirectories(Path.of(tmpFile));

        File sourceFile = s3Helper.getFromS3(srcBucket, srcKey, new File(tmpFile+File.separator+Math.random()+"_source"));

        byte[] encoded = Files.readAllBytes(sourceFile.toPath());
        String file =  new String(encoded, StandardCharsets.UTF_8);
        ObjectMapper mapper = new ObjectMapper();
        JsonNode node = mapper.readTree(file);

        // transform url paths
        ConvertIdsToBeRelativeToRoot converter = new ConvertIdsToBeRelativeToRoot();
        node = converter.rewriteIds(node, srcKey);

        // write to destination
        byte[] bytes = mapper.writerWithDefaultPrettyPrinter().writeValueAsString(node).getBytes();
        ByteArrayOutputStream baos = new ByteArrayOutputStream(bytes.length);
        baos.write(bytes, 0, bytes.length);

        s3Helper.writeToS3(baos, dstKey);

        return "Ok";
    }

    public String handleDeleteEvent(String srcBucket, String srcKey, Context context) throws IOException, TransformerException {
        // TODO
        return null;
    }
}
