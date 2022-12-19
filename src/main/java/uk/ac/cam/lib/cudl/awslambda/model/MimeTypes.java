package uk.ac.cam.lib.cudl.awslambda.model;

import org.apache.commons.io.FilenameUtils;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.util.HashMap;
import java.util.Map;

public class MimeTypes {

    private static final Map<String, String> mimeTypes = new HashMap<>();

    // TODO put this in a nice config file?
    static {

        mimeTypes.put("eot", "application/vnd.ms-fontobject");
        mimeTypes.put("otf", "font/otf");
        mimeTypes.put("ttf", "font/ttf");
        mimeTypes.put("woff", "font/woff");
        mimeTypes.put("woff2", "font/woff2");
        mimeTypes.put("jpg", "image/jpeg");
        mimeTypes.put("jpeg", "image/jpeg");
        mimeTypes.put("png", "image/png");
        mimeTypes.put("gif", "image/gif");
        mimeTypes.put("svg", "image/svg+xml");
        mimeTypes.put("webp", "image/webp");
        mimeTypes.put("ico", "image/vnd.microsoft.icon");
        mimeTypes.put("js", "text/javascript");
        mimeTypes.put("min.js", "text/javascript");
        mimeTypes.put("css", "text/css");
        mimeTypes.put("json", "application/json");
        mimeTypes.put("jsonld", "application/ld+json");
        mimeTypes.put("html", "text/html");
        mimeTypes.put("htm", "text/html");
    }

    /** Use the mime type mapping above and if that does not have a match, take a guess **/
    public static String getMimeType(String path) {

        String ext = FilenameUtils.getExtension(path);
        if (mimeTypes.containsKey(ext)) {
            return mimeTypes.get(ext);
        }

        String type = null;
        try {
            type = Files.probeContentType(new File(path).toPath());
        } catch (IOException e) {
            e.printStackTrace();
        }

        return type;
    }
}
