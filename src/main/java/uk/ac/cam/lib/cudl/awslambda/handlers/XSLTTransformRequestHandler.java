package uk.ac.cam.lib.cudl.awslambda.handlers;

import com.amazonaws.services.lambda.runtime.Context;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import uk.ac.cam.lib.cudl.awslambda.input.S3Input;
import uk.ac.cam.lib.cudl.awslambda.output.EFSFileOutput;
import uk.ac.cam.lib.cudl.awslambda.output.S3Output;
import uk.ac.cam.lib.cudl.awslambda.util.Properties;
import uk.ac.cam.lib.cudl.awslambda.util.XSLTHelper;

import javax.xml.transform.TransformerConfigurationException;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.nio.file.Files;
import java.util.*;

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

    private final List<String> xsltLocations;
    private final List<Map<String,String>> xsltParams = new ArrayList<>();
    private final XSLTHelper xsltHelper;
    private final S3Input s3Input;
    private final String tmpDir;
    public final String dstPrefix;
    public final String dstS3Prefix;
    public final S3Output s3Output;
    public final EFSFileOutput fileOutput;

    public XSLTTransformRequestHandler() throws TransformerConfigurationException {

        Properties properties = new Properties();
        s3Input = new S3Input();
        xsltHelper = new XSLTHelper(properties.getProperty("XSLT"));
        tmpDir = properties.getProperty("TMP_DIR");

        xsltLocations = Arrays.asList(properties.getProperty("XSLT").split(","));

        // Get xslt parameters if set
        for (int i=0; i<xsltLocations.size(); i++) {
            String paramEnv="XSLT_"+(i+1)+"_PARAMS";
            if (properties.exists(paramEnv)) {
                String params = properties.getProperty(paramEnv);
                Map<String,String> map = new Hashtable<>();
                for (String param :params.split(",")) {
                    String[] paramArray = param.split(":");
                    map.put(paramArray[0],paramArray[1]);
                }
                xsltParams.add(i, map);
            }
        }

        dstPrefix = properties.getProperty("DST_EFS_PREFIX");
        dstS3Prefix = properties.getProperty("DST_S3_PREFIX");
        s3Output = new S3Output();
        fileOutput = new EFSFileOutput();
    }

    @Override
    public String handlePutEvent(String srcBucket, String srcKey, Context context) throws Exception {

        logger.info("Put Event");

        File sourceFile = getSourceFile(srcBucket, srcKey, context, s3Input, tmpDir);
        String tmpFile = tmpDir + context.getAwsRequestId();

        // Chain together XSLT calls (from properties)
        for (int i=0; i<xsltLocations.size(); i++) {
            String xslt = xsltLocations.get(i);
            File outputFile = new File(tmpFile+File.separator+Math.random()+"_output");

            //  Get parameters if they exist for this xslt in properties
            Map<String, String> params = new Hashtable<>();
            if (xsltParams.size()>i) {
                 params = xsltParams.get(i);
            }

            // source file needs to be in <ITEM_ID>/<ITEM_ID>.xml format as this is used in XSLT
            // for the tei->json transform
            xsltHelper.transformAndWriteToFile(sourceFile, xslt, outputFile, params);
            sourceFile = outputFile;
        }

        byte[] bytes = Files.readAllBytes(sourceFile.toPath());
        ByteArrayOutputStream baos = new ByteArrayOutputStream(bytes.length);
        baos.write(bytes, 0, bytes.length);

        // write to efs storage (shared with ec2)
        String dstKey = dstPrefix+"/"+xsltHelper.translateSrcKeyToItemPath(srcKey);
        fileOutput.writeFromFile(sourceFile, dstKey);

        // write to s3
        String dstS3Key = dstS3Prefix+xsltHelper.translateSrcKeyToItemPath(srcKey);
        s3Output.writeFromStream(baos, dstS3Key);

        return "Ok";

    }

    @Override
    public String handleDeleteEvent(String srcBucket, String srcKey, Context context) throws Exception {

        logger.info("Delete Event");
        String jsonItemPath = xsltHelper.translateSrcKeyToItemPath(srcKey);
        String dst = dstPrefix+"/"+jsonItemPath;
        logger.info("Deleting from EFS: "+dst);
        fileOutput.deleteFromPath(dst);

        String dstKey = s3Output.translateSrcKeyToDestPath(jsonItemPath);
        logger.info("Deleting from S3: "+dstKey);
        s3Output.deleteFromPath(dstKey);

        return "Ok";
    }

}
