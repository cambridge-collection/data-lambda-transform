package uk.ac.cam.lib.cudl.awslambda.output;

import org.apache.commons.io.FileUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;

public class LambdaLocalFileOutput {

    private static final Logger logger = LoggerFactory.getLogger(LambdaLocalFileOutput.class);

    public LambdaLocalFileOutput() {
    }

    public void writeFromFile(File file, String dst) throws IOException {

        File fileDst = new File(dst);
        Files.createDirectories(Paths.get(fileDst.getParent()));
        FileUtils.copyFile(file, fileDst);

    }
}
