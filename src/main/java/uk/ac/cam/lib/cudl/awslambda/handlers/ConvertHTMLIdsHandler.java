package uk.ac.cam.lib.cudl.awslambda.handlers;

import com.amazonaws.services.lambda.runtime.Context;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import uk.ac.cam.lib.cudl.awslambda.input.S3Input;
import uk.ac.cam.lib.cudl.awslambda.output.S3Output;
import uk.ac.cam.lib.cudl.awslambda.util.HTMLConvertImgs;

import java.io.IOException;

public class ConvertHTMLIdsHandler extends AbstractRequestHandler {

    private static final Logger logger = LoggerFactory.getLogger(ConvertHTMLIdsHandler.class);
    private final S3Input s3Input;
    private final HTMLConvertImgs converter;
    private final S3Output s3Output;

    public ConvertHTMLIdsHandler() throws IOException {

        s3Input = new S3Input();
        converter = new HTMLConvertImgs();
        s3Output = new S3Output();

    }

    @Override
    public String handlePutEvent(String srcBucket, String srcKey, Context context) throws Exception {

        // Get the source file from s3
        logger.info("Put Event");
        String file = getSourceString(srcBucket,srcKey, s3Input);

        // transform url paths
        String output = converter.rewriteIds(file, srcKey);

        // Write to S3
        String s3Dest = s3Output.translateSrcKeyToDestPath(srcKey);
        s3Output.writeFromString(output, s3Dest);

        return "Ok";
    }

    @Override
    public String handleDeleteEvent(String srcBucket, String srcKey, Context context) throws IOException {
        logger.info("Delete Event");

        String dstKey = s3Output.translateSrcKeyToDestPath(srcKey);
        s3Output.deleteFromPath(dstKey);

        return "Ok";
    }
}
