package uk.ac.cam.lib.cudl.awslambda.handlers;

import com.amazonaws.services.lambda.runtime.Context;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import uk.ac.cam.lib.cudl.awslambda.input.S3Input;
import uk.ac.cam.lib.cudl.awslambda.output.EFSFileOutput;
import uk.ac.cam.lib.cudl.awslambda.output.S3Output;
import uk.ac.cam.lib.cudl.awslambda.util.Properties;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;

public class CopyFileHandler extends AbstractRequestHandler {

    private static final Logger logger = LoggerFactory.getLogger(CopyFileHandler.class);
    private final S3Input s3Input;
    private final String tmpDir;
    private final EFSFileOutput fileOutput;
    private final S3Output s3Output;

    public CopyFileHandler() throws IOException {

        Properties properties = new Properties();
        s3Input = new S3Input();
        tmpDir = properties.getProperty("TMP_DIR");
        fileOutput = new EFSFileOutput();
        s3Output = new S3Output();
    }

    @Override
    public String handlePutEvent(String srcBucket, String srcKey, Context context) throws Exception {

        // Get the source file from s3
        File sourceFile = getSourceFile(srcBucket,srcKey, context, s3Input, tmpDir);

        // Write to EFS
        String dst = fileOutput.translateSrcKeyToDestPath(srcKey);
        fileOutput.writeFromFile(sourceFile, dst);

        // Write to S3
        String s3Dest = s3Output.translateSrcKeyToDestPath(srcKey);
        byte[] bytes = Files.readAllBytes(sourceFile.toPath());
        ByteArrayOutputStream os = new ByteArrayOutputStream();
        os.write(bytes);
        s3Output.writeFromStream(os, s3Dest);

        return "Ok";
    }

    @Override
    public String handleDeleteEvent(String srcBucket, String srcKey, Context context) {
        // TODO
        return null;
    }
}
