package uk.ac.cam.lib.cudl.awslambda.output;

import com.amazonaws.AmazonServiceException;
import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.AmazonS3ClientBuilder;
import com.amazonaws.services.s3.model.ObjectMetadata;
import com.amazonaws.services.s3.model.PutObjectRequest;
import com.amazonaws.services.s3.model.S3ObjectSummary;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import uk.ac.cam.lib.cudl.awslambda.model.MimeTypes;
import uk.ac.cam.lib.cudl.awslambda.util.Properties;

import java.io.*;
import java.net.URLConnection;
import java.nio.file.Files;
import java.nio.file.Path;


/**
 * This class is used for help with processing using pagify.xsl (used for chunking and pagifying) and
 * msTEITrans.xsl (used to convert pagified xml into html
 */
public class S3Output {

    private static final Logger logger = LoggerFactory.getLogger(S3Output.class);

    public static final AmazonS3 s3Client = AmazonS3ClientBuilder.defaultClient();
    public final String dstBucket;
    public final String dstPrefix;
    public final String dstSuffix;

    public S3Output() {
        Properties properties = new Properties();

        dstBucket = properties.getProperty("DST_BUCKET");
        dstPrefix = properties.getProperty("DST_S3_PREFIX");
        dstSuffix = properties.getProperty("DST_XSLT_OUTPUT_SUFFIX");
    }

    public S3Output(String dstBucket, String dstPrefix, String dstSuffix) {

        this.dstBucket = dstBucket;
        this.dstPrefix = dstPrefix;
        this.dstSuffix = dstSuffix;
    }

    // Takes the srcKey from the request (complete path) and preserves the dir
    // structure but replaces the bucket to the dst bucket (under dstPrefix path)
    public String translateSrcKeyToDestPath(String srcKey) {

        return dstPrefix+srcKey;

    }

    public void writeFromString(String output, String dst) {

        // write to destination
        byte[] bytes = output.getBytes();
        ByteArrayOutputStream baos = new ByteArrayOutputStream(bytes.length);
        baos.write(bytes, 0, bytes.length);

        writeFromStream(baos, dst);

    }

    public boolean exists(String dstBucket, String dstKey) {
        return s3Client.doesObjectExist(dstBucket,dstKey);
    }

    public void writeFromStream(ByteArrayOutputStream os,  String dstKey) {
        writeFromStream(os, dstBucket, dstKey);
    }

    public void writeFromStream(ByteArrayOutputStream os, String dstBucket, String dstKey) {

        // Check for empty result (no transcription/transformation)
        if (os.size()<=412) {
            logger.info("File is too small for writing to s3");
            return;
        }

        // Write out to s3
        InputStream is = new ByteArrayInputStream(os.toByteArray());
        ObjectMetadata meta = new ObjectMetadata();
        meta.setContentLength(os.size());
        // String mimeType = URLConnection.guessContentTypeFromName(dstKey);
        meta.setContentType(MimeTypes.getMimeType(dstKey));

        // Uploading to S3 destination bucket
        logger.info("Writing to: " + dstBucket + "/" + dstKey);
        try {
            s3Client.putObject(dstBucket, dstKey, is, meta);
        } catch (AmazonServiceException e) {
            logger.error(e.getErrorMessage());
            System.exit(1);
        }

    }

    public void deleteFromPath(String dstKey) {
        deleteFromPath(dstBucket, dstKey);
    }

    public void deleteFromPath(String dstBucket, String dstKey) {

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

}
