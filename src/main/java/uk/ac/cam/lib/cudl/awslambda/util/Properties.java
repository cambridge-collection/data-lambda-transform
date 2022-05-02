package uk.ac.cam.lib.cudl.awslambda.util;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;

public class Properties {

    private final java.util.Properties properties = new java.util.Properties();

    public Properties () {
        try {
            File f = new File("/opt/java/lib/cudl-loader-lambda.properties");
            properties.load(new FileInputStream(f));

        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    public String getProperty(String key) {
        return properties.getProperty(key);
    }
}
