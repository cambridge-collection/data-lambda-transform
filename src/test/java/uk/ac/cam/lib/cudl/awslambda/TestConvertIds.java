package uk.ac.cam.lib.cudl.awslambda;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.commons.io.FileUtils;
import org.junit.jupiter.api.Test;
import uk.ac.cam.lib.cudl.awslambda.util.ConvertIdsToBeRelativeToRoot;

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
    public void testConvertIds() throws IOException {

        // TODO Finish off
        ConvertIdsToBeRelativeToRoot converter = new ConvertIdsToBeRelativeToRoot();

        String outputDir =  outputDirParent+Math.random();
        Files.createDirectories(Path.of(outputDir));

        File sourceFile = new File("src/test/resources/json/source.test.collection.json");
        byte[] encoded = Files.readAllBytes(sourceFile.toPath());
        String file =  new String(encoded, StandardCharsets.UTF_8);

        ObjectMapper mapper = new ObjectMapper();
        final JsonNode rootNode = mapper.readTree(file);

        String srcKey="collections/hebrew.collections.json";
        converter.rewriteIds(rootNode, srcKey);

        System.out.println(rootNode.toString());


    }

}
