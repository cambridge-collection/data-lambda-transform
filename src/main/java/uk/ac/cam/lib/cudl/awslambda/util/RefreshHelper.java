package uk.ac.cam.lib.cudl.awslambda.util;

import org.apache.commons.codec.binary.Base64;

import java.io.IOException;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;

public class RefreshHelper {

    private final boolean refreshEnabled;
    private final boolean refreshAuthEnabled;
    private final String refreshURL;
    private final String refreshUsername;
    private final String refreshPassword;

    public RefreshHelper() throws IOException {
        Properties properties = new Properties();
        refreshURL = properties.getProperty("REFRESH_URL");
        refreshEnabled = "true".equals(properties.getProperty("REFRESH_URL_ENABLE").toLowerCase());
        refreshAuthEnabled = "true".equals(properties.getProperty("REFRESH_URL_ENABLE_AUTH").toLowerCase());
        refreshUsername = properties.getProperty("REFRESH_URL_USERNAME");
        refreshPassword = properties.getProperty("REFRESH_URL_PASSWORD");
    }

    public void refreshCache() {
        try {
            if (!refreshEnabled) { return; }

            URL url = new URL(refreshURL);
            HttpURLConnection connection = (HttpURLConnection) url.openConnection();
            if (refreshAuthEnabled) {
                String auth = refreshUsername + ":" + refreshPassword;
                byte[] encodedAuth = Base64.encodeBase64(auth.getBytes(StandardCharsets.UTF_8));
                String authHeaderValue = "Basic " + new String(encodedAuth);
                connection.setRequestProperty("Authorization", authHeaderValue);
            }
            connection.disconnect();
        } catch (Exception e){
            e.printStackTrace();
        }
    }
}
