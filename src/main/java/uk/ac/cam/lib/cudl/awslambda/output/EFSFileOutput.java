package uk.ac.cam.lib.cudl.awslambda.output;

import org.apache.commons.io.FileUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import uk.ac.cam.lib.cudl.awslambda.util.Properties;

import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;

public class EFSFileOutput {

    private final String dstPrefix;
    private static final Logger logger = LoggerFactory.getLogger(EFSFileOutput.class);

    public EFSFileOutput() {
        Properties properties = new Properties();
        dstPrefix = properties.getProperty("DST_EFS_PREFIX");
    }

    public String translateSrcKeyToDestPath(String srcKey) {
        return dstPrefix+srcKey;
    }

    public void writeFromString(String output, String dst) throws IOException {

        logger.info("writing to: "+dst);

        File fileDst = new File(dst);
        Files.createDirectories(Paths.get(fileDst.getParent()));

        // write to efs storage (shared with ec2)
        byte[] bytes = output.getBytes();
        FileUtils.copyInputStreamToFile(new ByteArrayInputStream(bytes), fileDst);

    }

    public void writeFromFile(File file, String dst) throws IOException {

        logger.info("writing to: "+dst);

        File fileDst = new File(dst);
        Files.createDirectories(Paths.get(fileDst.getParent()));

        // write to efs storage (shared with ec2)
        FileUtils.copyFile(file, fileDst);

    }


    public void deleteFromPath(String dst) throws IOException {
        // delete from EFS
        File f = new File (dst);
        boolean successful = f.delete();

        if (!successful) {
            throw new IOException("ERROR: could not delete file "+dst);
        }

    }

}
