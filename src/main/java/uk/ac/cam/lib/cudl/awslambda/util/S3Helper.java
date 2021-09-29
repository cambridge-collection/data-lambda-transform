package uk.ac.cam.lib.cudl.awslambda.util;

import com.amazonaws.AmazonServiceException;
import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.AmazonS3ClientBuilder;
import com.amazonaws.services.s3.model.GetObjectRequest;
import com.amazonaws.services.s3.model.ObjectMetadata;
import com.amazonaws.services.s3.model.S3ObjectSummary;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.apache.commons.io.FilenameUtils;

import java.io.*;


/**
 * This class is used for help with processing using pagify.xsl (used for chunking and pagifying) and
 * msTEITrans.xsl (used to convert pagified xml into html
 */
public class S3Helper {

    private static final Logger logger = LoggerFactory.getLogger(S3Helper.class);

    public static final AmazonS3 s3Client = AmazonS3ClientBuilder.defaultClient();
    public final String dstBucket;
    public final String dstPrefix;
    public final String dstSuffix;

    public S3Helper() throws IOException {

        Properties properties = new Properties();
        dstBucket = properties.getProperty("DST_BUCKET");
        dstPrefix = properties.getProperty("DST_PREFIX");
        dstSuffix = properties.getProperty("DST_SUFFIX");
    }

    // takes the srcKey from the request (complete path) and preserves the dir
    // structure but replaces the bucket to the dst bucket (under dstPrefix path)
    public String translateSrcKeyToDestKey(String srcKey) {

        String baseName = FilenameUtils.getBaseName(srcKey);
        return dstPrefix+baseName+dstSuffix;

    }

    public void writeToS3(ByteArrayOutputStream os, String dstKey) {

        // Check for empty result (no transcription/transformation)
        if (os.size()<=412) {
            logger.info("File is too small for writing to s3");
            return;
        }

        // Write out to s3
        InputStream is = new ByteArrayInputStream(os.toByteArray());
        ObjectMetadata meta = new ObjectMetadata();
        meta.setContentLength(os.size());
        meta.setContentType("text/html");

        // Uploading to S3 destination bucket
        logger.info("Writing to: " + dstBucket + "/" + dstKey);
        try {
            s3Client.putObject(dstBucket, dstKey, is, meta);
        } catch (AmazonServiceException e) {
            logger.error(e.getErrorMessage());
            System.exit(1);
        }

    }

    public void deleteFromS3AllObjectsUnderPath(String dstKey) {

        // Delete from S3 destination bucket
        logger.info("Deleting all items from: " + dstBucket + "/" + dstKey);
        try {
            for (S3ObjectSummary file : s3Client.listObjects(dstBucket, dstKey).getObjectSummaries()){
                s3Client.deleteObject(dstBucket, file.getKey());
            }
            s3Client.deleteObject(dstBucket, dstKey);
        } catch (AmazonServiceException e) {
            logger.error(e.getErrorMessage());
            System.exit(1);
        }

    }

    public File getFromS3(String srcBucket, String key, File file) {
        s3Client.getObject(new GetObjectRequest(srcBucket, key), file);
        return file;
    }
}
