package uk.ac.cam.lib.cudl.awslambda.util;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.commons.io.FileUtils;
import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.jsoup.parser.Parser;
import org.jsoup.select.Elements;
import org.junit.jupiter.api.Test;

import javax.xml.transform.TransformerConfigurationException;
import javax.xml.transform.TransformerException;
import java.io.File;
import java.io.IOException;

import static org.junit.jupiter.api.Assertions.assertEquals;

class XSLTHelperTest {

    @Test
    void transformAndWriteToFile() throws IOException, TransformerException {

        File sourceFile = new File("src/test/resources/tei/MS-ADD-03958/MS-ADD-03958.xml");
        String xsltPaths = "src/test/resources/xslt/msTeiPreFilter.xsl,src/test/resources/xslt/jsonDocFormatter.xsl";
        String[] xsltPathArray = xsltPaths.split(",");
        File outputFile1 =  File.createTempFile("output", ".xml");
        File outputFile2 =  File.createTempFile("output", ".json");
        outputFile1.deleteOnExit();
        outputFile2.deleteOnExit();
        XSLTHelper xsltHelper = new XSLTHelper(xsltPaths);
        xsltHelper.transformAndWriteToFile(sourceFile, xsltPathArray[0], outputFile1);
        String s1 = FileUtils.readFileToString(outputFile1, "UTF-8");
        xsltHelper.transformAndWriteToFile(outputFile1, xsltPathArray[1], outputFile2);
        String s2 = FileUtils.readFileToString(outputFile2, "UTF-8");

        Document documentGenerated = Jsoup.parse(s1.trim(), "", Parser.xmlParser());
        Document documentCorrect = Jsoup.parse(FileUtils.readFileToString(new File("src/test/resources/xml/MS-ADD-03958.partprocessed.xml"), "UTF-8").trim(), "", Parser.xmlParser());
        assertEquals(documentCorrect.toString(), documentGenerated.toString());

        ObjectMapper mapper = new ObjectMapper();
        JsonNode jsonNodeGenerated = mapper.readTree(s2);
        JsonNode jsonNodeCorrect = mapper.readTree(new File("src/test/resources/json/MS-ADD-03958.json"));

        assertEquals(jsonNodeCorrect, jsonNodeGenerated);

    }

    @Test
    void translateSrcKeyToItemPath() throws IOException, TransformerConfigurationException {
        String xsltPaths = "src/test/resources/xslt/msTeiPreFilter.xsl,src/test/resources/xslt/jsonDocFormatter.xsl";
        XSLTHelper xsltHelper = new XSLTHelper(xsltPaths);
        String itemPath = xsltHelper.translateSrcKeyToItemPath("this/is/a/path/itemid.xml");
        assertEquals("json/itemid.json", itemPath);
    }
}