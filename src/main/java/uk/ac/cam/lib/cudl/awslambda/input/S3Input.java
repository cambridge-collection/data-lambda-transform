package uk.ac.cam.lib.cudl.awslambda.input;

import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.AmazonS3ClientBuilder;
import com.amazonaws.services.s3.model.GetObjectRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.File;
import java.io.InputStream;


/**
 * This class is used for help with processing using pagify.xsl (used for chunking and pagifying) and
 * msTEITrans.xsl (used to convert pagified xml into html
 */
public class S3Input {

    private static final Logger logger = LoggerFactory.getLogger(S3Input.class);
    public static final AmazonS3 s3Client = AmazonS3ClientBuilder.defaultClient();

    public File getFile(String srcBucket, String key, File file) {
        s3Client.getObject(new GetObjectRequest(srcBucket, key), file);
        return file;
    }

    public InputStream getInputStream(String srcBucket, String key) {
        return s3Client.getObject(srcBucket, key).getObjectContent();
    }

    public String getString(String srcBucket, String key) {
        return s3Client.getObjectAsString(srcBucket, key);
    }
}
