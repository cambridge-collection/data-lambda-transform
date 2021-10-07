package uk.ac.cam.lib.cudl.awslambda.util;

import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;
import org.jsoup.parser.Parser;
import org.jsoup.select.Elements;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.File;
import java.io.IOException;
import java.nio.file.Path;

public class HTMLConvertImgs {

    private static final Logger logger = LoggerFactory.getLogger(HTMLConvertImgs.class);
    private final String dstPrefix;

    public HTMLConvertImgs( ) throws IOException {
        Properties properties = new Properties();
        dstPrefix = properties.getProperty("DST_EFS_PREFIX");
    }

    /**
     * This process converts the @id elements to be relative to the root rather than
     * relative to HTML file.
     * @param html
     * @throws IOException
     */
    public String rewriteIds(String html, String srcKey) throws IOException {

        Document doc = Jsoup.parse(html, "", Parser.xmlParser());
        doc =  rewriteHTMLIdsFromDocument(doc, srcKey);
        doc.outputSettings().prettyPrint(true);
        return doc.html();
    }

    public String translateSrcKeyToEFSPath(String srcKey) {

        return dstPrefix+srcKey;

    }

    private Document rewriteHTMLIdsFromDocument(Document document, String srcKey) throws IOException {

        // Document
        Elements images = document.select("img");

        for (Element img: images) {
            String imgSrc = img.attr("src");

            // Modify img src
            imgSrc = convertSrcToBeRelativeToRoot(imgSrc, srcKey);

            img.attr("src", imgSrc);
        }
        return document;
    }

    /**
     * This process converts the src attributes to be relative to the root rather than
     * relative to HTML file. (/images/collectionsView/maps.jpg)
     * @param src e.g. ../../../images/collectionsView/maps.jpg
     * @param parentFile e.g. pages/html/collections/maps/summary.html
     * */
    private String convertSrcToBeRelativeToRoot(String src, String parentFile) {

        File collectionFile = new File(parentFile);
        Path linkPath= new File(collectionFile.getParent()+File.separator+src).toPath();

        String normalised = linkPath.normalize().toString();
        // pages/images is mapped to /images in urls
        return normalised.replaceFirst("pages/images", "/images");

    }
}
