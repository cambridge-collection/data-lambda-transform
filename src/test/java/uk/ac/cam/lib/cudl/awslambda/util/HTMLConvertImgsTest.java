package uk.ac.cam.lib.cudl.awslambda.util;

import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.jsoup.select.Elements;
import org.junit.jupiter.api.Test;

import java.io.IOException;

class HTMLConvertImgsTest {

    private final String srcKey = "collections/test.collection.json";

    @Test
    void rewriteIds() throws IOException {
        HTMLConvertImgs htmlConvertImgs = new HTMLConvertImgs();

        String file = "<img src='../pages/images/testfile.jpg'>\n";
        String out = htmlConvertImgs.rewriteIds(file, srcKey);
        Document document = Jsoup.parse(out);
        Elements img = document.select("img");
        assert (img.get(0).attr("src").equals("/images/testfile.jpg"));
    }

    @Test
    void translateSrcKeyToEFSPath() throws IOException {

        HTMLConvertImgs htmlConvertImgs = new HTMLConvertImgs();
        String out = htmlConvertImgs.translateSrcKeyToEFSPath(srcKey);
        Properties properties = new Properties();
        assert (out.equals(properties.getProperty("DST_EFS_PREFIX")+srcKey));
    }

}