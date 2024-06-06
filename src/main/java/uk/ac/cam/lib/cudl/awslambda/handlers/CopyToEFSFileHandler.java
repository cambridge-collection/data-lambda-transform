package uk.ac.cam.lib.cudl.awslambda.handlers;

import com.amazonaws.services.lambda.runtime.Context;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import uk.ac.cam.lib.cudl.awslambda.input.S3Input;
import uk.ac.cam.lib.cudl.awslambda.output.EFSFileOutput;
import uk.ac.cam.lib.cudl.awslambda.util.Properties;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;

public class CopyToEFSFileHandler extends AbstractRequestHandler {

    private static final Logger logger = LoggerFactory.getLogger(CopyToEFSFileHandler.class);
    private final S3Input s3Input;
    private final String tmpDir;
    private final EFSFileOutput fileOutput;

    public CopyToEFSFileHandler() throws IOException {

        Properties properties = new Properties();
        s3Input = new S3Input();
        tmpDir = properties.getProperty("TMP_DIR");
        fileOutput = new EFSFileOutput();
    }

    @Override
    public String handlePutEvent(String srcBucket, String srcKey, Context context) throws Exception {

        // Get the source file from s3
        File sourceFile = getSourceFile(srcBucket,srcKey, context, s3Input, tmpDir);

        if (sourceFile==null || !sourceFile.exists() || sourceFile.isDirectory() || Files.size(sourceFile.toPath())==0) {
            logger.info("sourceFile :"+sourceFile+ " was not a file or empty.  From srcKey: "+srcKey);
            return "Ok";
        }

        // Write to EFS
        String dst = fileOutput.translateSrcKeyToDestPath(srcKey);
        fileOutput.writeFromFile(sourceFile, dst);

        return "Ok";
    }

    @Override
    public String handleDeleteEvent(String srcBucket, String srcKey, Context context) throws IOException {
        logger.info("Delete Event");

        String dst = fileOutput.translateSrcKeyToDestPath(srcKey);
        fileOutput.deleteFromPath(dst);

        return "Ok";
    }
}
