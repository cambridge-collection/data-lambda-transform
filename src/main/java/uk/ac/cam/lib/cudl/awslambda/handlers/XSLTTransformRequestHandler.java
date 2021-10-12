package uk.ac.cam.lib.cudl.awslambda.handlers;

import com.amazonaws.services.lambda.runtime.Context;
import org.apache.commons.codec.binary.Base64;
import org.apache.commons.io.FileUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import uk.ac.cam.lib.cudl.awslambda.output.S3Output;
import uk.ac.cam.lib.cudl.awslambda.util.Properties;
import uk.ac.cam.lib.cudl.awslambda.input.S3Input;
import uk.ac.cam.lib.cudl.awslambda.util.XSLTHelper;

import javax.xml.transform.TransformerConfigurationException;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
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
    private final boolean refreshEnabled;
    private final boolean refreshAuthEnabled;
    private final String refreshURL;
    private final String refreshUsername;
    private final String refreshPassword;
    public final String dstPrefix;
    public final String dstS3Prefix;
    public final S3Output s3Output;

    public XSLTTransformRequestHandler() throws TransformerConfigurationException, IOException {

        Properties properties = new Properties();
        s3Input = new S3Input();
        xsltHelper = new XSLTHelper(properties.getProperty("XSLT"));
        tmpDir = properties.getProperty("TMP_DIR");
        refreshURL = properties.getProperty("REFRESH_URL");


        functionName = properties.getProperty("FUNCTION_NAME");
        xsltLocations = Arrays.asList(properties.getProperty("XSLT").split(","));
        refreshEnabled = "true".equals(properties.getProperty("REFRESH_URL_ENABLE").toLowerCase());
        refreshAuthEnabled = "true".equals(properties.getProperty("REFRESH_URL_ENABLE_AUTH").toLowerCase());
        refreshUsername = properties.getProperty("REFRESH_URL_USERNAME");
        refreshPassword = properties.getProperty("REFRESH_URL_PASSWORD");
        dstPrefix = properties.getProperty("DST_EFS_PREFIX");
        dstS3Prefix = properties.getProperty("DST_S3_PREFIX");
        s3Output = new S3Output();

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
        System.out.println("dstKey: "+dstKey);

        // write to efs storage (shared with ec2)
        FileUtils.copyFile(sourceFile, new File(dstKey));

        // write to s3
        String dstS3Key = dstS3Prefix+xsltHelper.translateSrcKeyToItemPath(srcKey);
        s3Output.writeFromStream(baos, dstS3Key);

        refreshCache();
        return "Ok";

    }

    private void refreshCache() {
        try {
            if (!refreshEnabled) { return; }

            URL url = new URL(refreshURL);
            HttpURLConnection connection = (HttpURLConnection) url.openConnection();
            if (refreshAuthEnabled) {
                String auth = refreshUsername + ":" + refreshPassword;
                byte[] encodedAuth = Base64.encodeBase64(auth.getBytes(StandardCharsets.UTF_8));
                String authHeaderValue = "Basic " + new String(encodedAuth);
                connection.setRequestProperty("Authorization", authHeaderValue);
            }
            System.out.println(connection.getResponseCode() + " " + connection.getResponseMessage());
            connection.disconnect();
        } catch (Exception e){
            e.printStackTrace();
        }
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
