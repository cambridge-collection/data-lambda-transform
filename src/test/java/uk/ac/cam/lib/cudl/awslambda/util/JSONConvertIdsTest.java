package uk.ac.cam.lib.cudl.awslambda.util;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.commons.io.FileUtils;
import org.junit.jupiter.api.Test;

import java.io.File;

import static org.junit.jupiter.api.Assertions.assertEquals;

class JSONConvertIdsTest {

    private final String srcKey = "collections/test.collection.json";

    @Test
    void rewriteIds() throws Exception {

        String json_in = FileUtils.readFileToString(new File("src/test/resources/json/source.test.collection.json"), "UTF-8");
        String json_out = FileUtils.readFileToString(new File("src/test/resources/json/release.test.collection.json"), "UTF-8");

        JSONConvertIds jsonConvertIds = new JSONConvertIds();
        String out = jsonConvertIds.rewriteIds(json_in, srcKey);

        ObjectMapper mapper = new ObjectMapper();
        JsonNode jsonNodeIn = mapper.readTree(out);
        JsonNode jsonNodeOut = mapper.readTree(json_out);

        assertEquals(jsonNodeIn, jsonNodeOut);

    }
}