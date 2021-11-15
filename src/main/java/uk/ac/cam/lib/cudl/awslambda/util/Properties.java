package uk.ac.cam.lib.cudl.awslambda.util;

import java.io.IOException;

public class Properties {

    private final java.util.Properties properties = new java.util.Properties();

    public Properties () {
        try {
            String version = System.getenv("VERSION");
            if (version != null && version.equals("LIVE")) {
                properties.load(Thread.currentThread().getContextClassLoader().getResourceAsStream("lambda.live.properties"));
            } else {
                properties.load(Thread.currentThread().getContextClassLoader().getResourceAsStream("lambda.dev.properties"));
            }
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    public String getProperty(String key) {
        return properties.getProperty(key);
    }
}
