package uk.ac.cam.lib.cudl.awslambda;

import org.apache.commons.io.FileUtils;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.Test;

import javax.xml.transform.*;
import javax.xml.transform.sax.SAXTransformerFactory;
import javax.xml.transform.sax.TransformerHandler;
import javax.xml.transform.stream.StreamResult;
import javax.xml.transform.stream.StreamSource;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

public class TestXSLTTransform {

    final static String XSLT1 = "../../../../../../../../src/test/resources/xslt/msTeiPreFilter.xsl";
    final static String XSLT2 = "../../../../../../../../src/test/resources/xslt/jsonDocFormatter.xsl";
    final static String outputDirParent = "/tmp/dest/testXSLTTransform/";
    final String testDir;
    final SAXTransformerFactory stf = (SAXTransformerFactory) TransformerFactory.newInstance();

    // TODO restructure so it can test the actual function
    public TestXSLTTransform() throws IOException {

        testDir = getClass().getResource(".").getPath();

        // Setup XSLT templates here so that they are only setup once and are available for the
        // request function.
        stf.setAttribute("http://saxon.sf.net/feature/xinclude-aware", Boolean.TRUE);
        stf.setURIResolver((s, s1) -> new StreamSource(testDir+s));

        // copy files to test dir
        FileUtils.copyDirectory(new File("./src/test/resources"), new File(testDir));

    }

    @Test
    public void testTransformsSuccessfulMS_ADD_04000_no_chunking() throws IOException, TransformerException {

        String outputDir =  outputDirParent+Math.random();
        Files.createDirectories(Path.of(outputDir));

        String out = outputDir+"/TEST-MS-ADD-04000";
        Templates template1 = stf.newTemplates(new StreamSource(new FileInputStream(testDir+XSLT1)));
        Templates template2 = stf.newTemplates(new StreamSource(new FileInputStream(testDir+XSLT2)));

        String outputFile = runXSLT("src/test/resources/tei/MS-ADD-04000/MS-ADD-04000.xml", out+"/xml",  template1);
        String files = runXSLT(outputFile, out+"/json", template2);

        System.out.println("files: "+files);
        assert(!files.isEmpty());
        System.out.println("size: "+files);
        assert(files.endsWith("TEST-MS-ADD-04000/json/output"));
        // TODO Check file contents
    }

    private String runXSLT(String inputFile, String out,Templates template) throws IOException, TransformerException {

        StreamSource src = new StreamSource(new FileInputStream(inputFile));

        TransformerHandler th1 = stf.newTransformerHandler(template);
        Transformer transformer = th1.getTransformer();
        transformer.setParameter("dest_dir", out);
        transformer.setParameter("num_chunks", String.valueOf(1));

        String outputPath = out+"/output";
        src.setSystemId(FileUtils.getFile(inputFile).getName());

        transformer.transform(src,new StreamResult(new File(outputPath)));

        return outputPath;
    }

    @AfterAll
    public static void cleanup() throws IOException {

        //clean up
        FileUtils.deleteDirectory(new File(outputDirParent));
    }

}
