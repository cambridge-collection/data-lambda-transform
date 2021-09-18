package uk.ac.cam.lib.cudl.awslambda.util;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

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
    private final S3Helper s3Helper;
    private final SAXTransformerFactory stf = (SAXTransformerFactory) TransformerFactory.newInstance();
    private final String tmpDir;

    public XSLTHelper(S3Helper s3Helper) throws TransformerConfigurationException, IOException {

        Properties properties = new Properties();

        // Setup XSLT templates here so that they are only setup once and are available for the
        // request function.
        stf.setAttribute("http://saxon.sf.net/feature/xinclude-aware", Boolean.TRUE);

        String xsltList = properties.getProperty("XSLT");
        String[] xsltPaths = xsltList.split(",");

        Map<String,Templates> XSLTTemplates = new HashMap<>();
        for (String xsltS3Path: xsltPaths) {
            System.out.println("xsltPath: "+xsltS3Path);
            File stylesheet = new File(xsltS3Path);
            XSLTTemplates.put(xsltS3Path, stf.newTemplates(new StreamSource(stylesheet)));
        }
        templates = XSLTTemplates;
        this.s3Helper = s3Helper;
        tmpDir = properties.getProperty("TMP_DIR");
    }

    /**
     * Runs transform on a set of local files and returns file paths for output
     * Can be used where transform oututs one file.
     *
     * @param sourceFile
     * @param xsltPath
     * @param outputFile
     * @throws TransformerException
     */
    public void transformAndWriteToFile(File sourceFile, String xsltPath, File outputFile) throws TransformerException {

        StreamSource filesrc = new StreamSource(sourceFile);
        FileOutputStream os = null;
        try {
            os = new FileOutputStream(outputFile);
        } catch (FileNotFoundException e) {
            e.printStackTrace();
        }

        StreamResult streamResult = new StreamResult(os);
        transform(filesrc, streamResult, templates.get(xsltPath), new HashMap<>());

        logger.info("Successfully transformed " + sourceFile.getAbsolutePath() + " and uploaded to " + s3Helper.dstBucket + "/" + outputFile.getAbsolutePath());

    }

    private void transform(StreamSource src, StreamResult result, Templates template, Map<String,String> params) throws TransformerException {
        logger.info("Transforming: "+src.getSystemId()+" to "+result.getSystemId()+ " with template: "+template+" and params: "+params);
        TransformerHandler th1 = stf.newTransformerHandler(template);
        Transformer transformer = th1.getTransformer();
        for (Map.Entry<String,String> param: params.entrySet()) {
            transformer.setParameter(param.getKey(), param.getValue());
        }

        transformer.transform(src,result);
    }

}
