package uk.ac.cam.lib.cudl.awslambda.output;

import org.apache.commons.io.FileUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import uk.ac.cam.lib.cudl.awslambda.util.Properties;

import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;

public class EFSFileOutput {

    private final String dstPrefix;
    private final String tmpDir;
    private static final Logger logger = LoggerFactory.getLogger(EFSFileOutput.class);

    public EFSFileOutput() throws IOException {
        Properties properties = new Properties();
        dstPrefix = properties.getProperty("DST_EFS_PREFIX");
        tmpDir = properties.getProperty("TMP_DIR");
    }

    public String translateSrcKeyToDestPath(String srcKey) {
        return dstPrefix+srcKey;
    }

    public void writeFromString(String output, String dst) throws IOException {

        logger.info("writing to: "+dst);

        byte[] bytes = output.getBytes();
        FileUtils.copyInputStreamToFile(new ByteArrayInputStream(bytes), new File (dst));

        File tempFile = File.createTempFile(tmpDir, ".tmp");
        tempFile.deleteOnExit();

        FileOutputStream out = new FileOutputStream(tempFile);
        out.write(bytes);

        writeFromFile(tempFile, dst);

    }

    public void writeFromFile(File file, String dst) throws IOException {

        logger.info("writing to: "+dst);

        // write to efs storage (shared with ec2)
        FileUtils.copyFile(file, new File(dst));

    }


    public void deleteFromPath(String dstKey) {
    // TODO
    }

}
