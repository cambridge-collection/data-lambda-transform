package uk.ac.cam.lib.cudl.awslambda;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.commons.io.FileUtils;
import org.junit.jupiter.api.Test;
import uk.ac.cam.lib.cudl.awslambda.util.HTMLConvertImgs;
import uk.ac.cam.lib.cudl.awslambda.util.JSONConvertIds;

import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

public class TestConvertIds {

    final static String outputDirParent = "/tmp/dest/testConvertIds/";
    final String testDir;

    public TestConvertIds() throws IOException {

        testDir = getClass().getResource(".").getPath();

        // copy files to test dir
        FileUtils.copyDirectory(new File("./src/test/resources"), new File(testDir));


    }

    @Test
    public void testConvertIdsCollection() throws IOException {

        // TODO Finish off
        JSONConvertIds converter = new JSONConvertIds();

        String outputDir =  outputDirParent+Math.random();
        Files.createDirectories(Path.of(outputDir));

        File sourceFile = new File("src/test/resources/json/source.test.collection.json");
        byte[] encoded = Files.readAllBytes(sourceFile.toPath());
        String file =  new String(encoded, StandardCharsets.UTF_8);

        String srcKey="collections/hebrew.collections.json";
        String output = converter.rewriteIds(file, srcKey);

        System.out.println(output);


    }

    @Test
    public void testConvertIdsPages() throws IOException {

        // TODO Finish off
        HTMLConvertImgs converter = new HTMLConvertImgs();

        String outputDir =  outputDirParent+Math.random();
        Files.createDirectories(Path.of(outputDir));

        File sourceFile = new File("src/test/resources/pages/html/collections/maps-source/summary.html");
        byte[] encoded = Files.readAllBytes(sourceFile.toPath());
        String file =  new String(encoded, StandardCharsets.UTF_8);

        String srcKey="pages/html/collections/maps/summary.html";
        String output = converter.rewriteIds(file,srcKey);

        System.out.println(output);


    }
}
