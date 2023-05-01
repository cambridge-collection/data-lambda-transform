package uk.ac.cam.lib.cudl.awslambda.util;

import org.apache.commons.io.FilenameUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.activation.FileDataSource;
import javax.xml.transform.*;
import javax.xml.transform.sax.SAXTransformerFactory;
import javax.xml.transform.sax.TransformerHandler;
import javax.xml.transform.stream.StreamResult;
import javax.xml.transform.stream.StreamSource;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;


/**
 * This class is used for help with processing using xslt transformations
 */
public class XSLTHelper {

    private static final Logger logger = LoggerFactory.getLogger(XSLTHelper.class);

    private final Map<String,Templates> templates;
    private final SAXTransformerFactory stf = (SAXTransformerFactory) TransformerFactory.newInstance();
    public final String dstSuffix;
    public final String itemsFolder;

    public XSLTHelper(String xsltList) throws TransformerConfigurationException {

        Properties properties = new Properties();

        // Setup XSLT templates here so that they are only setup once and are available for the
        // request function.
        stf.setAttribute("http://saxon.sf.net/feature/xinclude-aware", Boolean.TRUE);

        String[] xsltPaths = xsltList.split(",");

        Map<String,Templates> XSLTTemplates = new HashMap<>();
        for (String xsltPath: xsltPaths) {
            File stylesheet = new File(xsltPath);
            if (stylesheet.exists()) {
                XSLTTemplates.put(xsltPath, stf.newTemplates(new StreamSource(stylesheet)));
            } else {
                logger.info("Initiatised XSLTHelper without stylesheet: "+stylesheet);
            }
        }
        templates = XSLTTemplates;

        dstSuffix = properties.getProperty("DST_XSLT_OUTPUT_SUFFIX");
        itemsFolder = properties.getProperty("DST_XSLT_OUTPUT_FOLDER");
    }

    /**
     * Runs transform on a local file and returns the file output
     * Can be used where transform oututs one file.
     * NOTE: For JSON transformation the path of the file should be /<ITEM_ID>/<ITEM_ID>.xml
     *
     * @param sourceFile
     * @param xsltPath
     * @param outputFile
     * @throws TransformerException
     */
    public void transformAndWriteToFile(File sourceFile, String xsltPath, File outputFile, Map<String,String> params) throws TransformerException, IOException {

        StreamSource filesrc = new StreamSource(sourceFile);
        FileOutputStream os = null;
        try {
            os = new FileOutputStream(outputFile);
        } catch (FileNotFoundException e) {
            e.printStackTrace();
        }

        StreamResult streamResult = new StreamResult(os);
        transform(filesrc, streamResult, templates.get(xsltPath), params);

        logger.info("Successfully transformed " + sourceFile.getAbsolutePath() + " and uploaded to " + outputFile.getAbsolutePath());

    }

    public Templates getTemplate(String name) {
        return templates.get(name);
    }

    public void transform(StreamSource src, StreamResult result, Templates template, Map<String,String> params) throws TransformerException {
        logger.info("Transforming: "+src.getSystemId()+" to "+result.getSystemId()+ " with template: "+template+" and params: "+params);
        TransformerHandler th1 = stf.newTransformerHandler(template);
        Transformer transformer = th1.getTransformer();
        for (Map.Entry<String,String> param: params.entrySet()) {
            transformer.setParameter(param.getKey(), param.getValue());
        }

        transformer.transform(src,result);
    }

    /**
     * NOTE: If <ITEM_ID> appears in the DST_XSLT_OUTPUT_FOLDER parameter this is
     * replaced with the basename from the key.
     *
     * @param srcKey
     * @return
     */
    public String translateSrcKeyToItemPath(String srcKey) {

        logger.info("Item srcKey: "+srcKey);
        String baseName = FilenameUtils.getBaseName(srcKey);

        return itemsFolder.replaceAll("<ITEM_ID>", baseName)+baseName+dstSuffix;

    }
}
