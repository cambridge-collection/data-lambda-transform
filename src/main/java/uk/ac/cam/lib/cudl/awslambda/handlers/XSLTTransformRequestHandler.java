package uk.ac.cam.lib.cudl.awslambda.handlers;

import com.amazonaws.services.lambda.runtime.Context;
import org.apache.commons.io.FileUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import uk.ac.cam.lib.cudl.awslambda.input.S3Input;
import uk.ac.cam.lib.cudl.awslambda.output.S3Output;
import uk.ac.cam.lib.cudl.awslambda.util.Properties;
import uk.ac.cam.lib.cudl.awslambda.util.RefreshHelper;
import uk.ac.cam.lib.cudl.awslambda.util.XSLTHelper;

import javax.xml.transform.TransformerConfigurationException;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
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
public class XSLTTransformRequestHandler extends AbstractRequestHandler {

    private static final Logger logger = LoggerFactory.getLogger(XSLTTransformRequestHandler.class);

    public final String functionName;
    private final List<String> xsltLocations;
    private final XSLTHelper xsltHelper;
    private final S3Input s3Input;
    private final String tmpDir;
    public final String dstPrefix;
    public final String dstS3Prefix;
    public final S3Output s3Output;
    public final RefreshHelper refreshHelper;

    public XSLTTransformRequestHandler() throws TransformerConfigurationException, IOException {

        Properties properties = new Properties();
        s3Input = new S3Input();
        xsltHelper = new XSLTHelper(properties.getProperty("XSLT"));
        tmpDir = properties.getProperty("TMP_DIR");

        functionName = properties.getProperty("FUNCTION_NAME");
        xsltLocations = Arrays.asList(properties.getProperty("XSLT").split(","));

        dstPrefix = properties.getProperty("DST_EFS_PREFIX");
        dstS3Prefix = properties.getProperty("DST_S3_PREFIX");
        s3Output = new S3Output();
        refreshHelper = new RefreshHelper();

    }

    @Override
    public String handlePutEvent(String srcBucket, String srcKey, Context context) throws Exception {

        logger.info("Put Event");

        File sourceFile = getSourceFile(srcBucket, srcKey, context, s3Input, tmpDir);

        String tmpFile = tmpDir + context.getAwsRequestId();

        // Chain together XSLT calls (from properties)
        for (String xslt: xsltLocations) {
            File outputFile = new File(tmpFile+File.separator+Math.random()+"_output");
            xsltHelper.transformAndWriteToFile(sourceFile, xslt, outputFile);
            sourceFile = outputFile;
        }

        byte[] bytes = Files.readAllBytes(sourceFile.toPath());
        ByteArrayOutputStream baos = new ByteArrayOutputStream(bytes.length);
        baos.write(bytes, 0, bytes.length);

        String dstKey = dstPrefix+xsltHelper.translateSrcKeyToItemPath(srcKey);

        // write to efs storage (shared with ec2)
        FileUtils.copyFile(sourceFile, new File(dstKey));

        // write to s3
        String dstS3Key = dstS3Prefix+xsltHelper.translateSrcKeyToItemPath(srcKey);
        s3Output.writeFromStream(baos, dstS3Key);

        refreshHelper.refreshCache();
        return "Ok";

    }

    @Override
    public String handleDeleteEvent(String srcBucket, String srcKey, Context context) throws Exception {

/*        logger.info("Delete Event");
        // should be at same path as src but have dstPrefix and end in .html
        String dstKey = s3Helper.translateSrcKeyToDestKey(srcKey);
        s3Helper.deleteFromS3AllObjectsUnderPath(dstKey);*/
        return "OK";
    }
}