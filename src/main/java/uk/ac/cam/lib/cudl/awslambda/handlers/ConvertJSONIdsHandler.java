package uk.ac.cam.lib.cudl.awslambda.handlers;

import com.amazonaws.services.lambda.runtime.Context;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import uk.ac.cam.lib.cudl.awslambda.input.S3Input;
import uk.ac.cam.lib.cudl.awslambda.output.EFSFileOutput;
import uk.ac.cam.lib.cudl.awslambda.output.S3Output;
import uk.ac.cam.lib.cudl.awslambda.util.JSONConvertIds;

import javax.xml.transform.TransformerConfigurationException;
import java.io.IOException;

public class ConvertJSONIdsHandler extends AbstractRequestHandler {

    private static final Logger logger = LoggerFactory.getLogger(ConvertJSONIdsHandler.class);
    private final S3Input s3Input;
    private final JSONConvertIds converter;
    private final EFSFileOutput fileOutput;
    private final S3Output s3Output;

    public ConvertJSONIdsHandler() throws IOException, TransformerConfigurationException {

        s3Input = new S3Input();
        converter = new JSONConvertIds();
        fileOutput = new EFSFileOutput();
        s3Output = new S3Output();

    }

    @Override
    public String handlePutEvent(String srcBucket, String srcKey, Context context) throws Exception {

        // Get the source file from s3
        logger.info("Put Event");
        String file = getSourceString(srcBucket,srcKey, s3Input);

        // transform item ids
        String output = converter.rewriteIds(file, srcKey);

        // Write to EFS
        String dst = fileOutput.translateSrcKeyToDestPath(srcKey);
        fileOutput.writeFromString(output, dst);

        // Write to S3
        String s3Dest = s3Output.translateSrcKeyToDestPath(srcKey);
        s3Output.writeFromString(output, s3Dest);

        return "Ok";
    }

    @Override
    public String handleDeleteEvent(String srcBucket, String srcKey, Context context) throws IOException {
        logger.info("Delete Event");
        String dst = fileOutput.translateSrcKeyToDestPath(srcKey);
        fileOutput.deleteFromPath(dst);

        String dstKey = s3Output.translateSrcKeyToDestPath(srcKey);
        s3Output.deleteFromPath(dstKey);

        return "Ok";
    }
}
