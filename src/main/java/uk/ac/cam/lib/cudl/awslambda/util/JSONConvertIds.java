package uk.ac.cam.lib.cudl.awslambda.util;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.JsonNodeType;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.File;
import java.io.IOException;
import java.nio.file.Path;
import java.util.Iterator;
import java.util.Map;

public class JSONConvertIds {

    private static final Logger logger = LoggerFactory.getLogger(JSONConvertIds.class);

    /**
     * This process converts the @id elements to be relative to the root rather than
     * relative to JSON file.
     * @param file
     * @throws IOException
     */
    public String rewriteIds(String file, String srcKey) throws IOException {

        ObjectMapper mapper = new ObjectMapper();
        JsonNode node = mapper.readTree(file);
        node =  rewriteJSONIdsFromNode(node, srcKey);
        return mapper.writerWithDefaultPrettyPrinter().writeValueAsString(node);

    }

    private JsonNode rewriteJSONIdsFromNode(JsonNode node, String srcKey) {

        ObjectMapper mapper = new ObjectMapper();

        // Node is Array
        if (node.isArray()) {
            ArrayNode arrayNode = (ArrayNode) node;
            ArrayNode newArrayNode = mapper.createArrayNode();

            for (int i = 0; i < arrayNode.size(); i++) {
                JsonNode updatedNode = rewriteJSONIdsFromNode(arrayNode.get(i),srcKey);
                newArrayNode.add(updatedNode);
            }
            return newArrayNode;


        } else

        // Node is Object
        if (node.isObject()) {
            ObjectNode objectNode = (ObjectNode) node;
            Iterator<Map.Entry<String, JsonNode>> iter = objectNode.fields();

            while (iter.hasNext()) {

                Map.Entry<String, JsonNode> entry = iter.next();
                if ("@id".equals(entry.getKey()) && entry.getValue().getNodeType()== JsonNodeType.STRING) {
                    logger.info("replacing id: "+entry.toString()+" srcKey: "+srcKey);
                    String newId = convertIdToBeRelativeToRoot(entry.getValue().asText(), srcKey);
                    objectNode.put("@id", newId);
                } else {
                    objectNode.set(entry.getKey(), rewriteJSONIdsFromNode(entry.getValue(), srcKey));
                }
            }

        }

        return node;
    }

    /**
     * This process converts the @id elements to be relative to the root rather than
     * relative to JSON file.
     * @param id e.g. ../pages/html/collections/hebrew/summary.html
     * @param parentFile e.g. collections/hebrew.collections.json
     * */
    private String convertIdToBeRelativeToRoot(String id, String parentFile) {

        File collectionFile = new File(parentFile);
        Path linkPath= new File(collectionFile.getParent()+File.separator+id).toPath();

        return linkPath.normalize().toString();

    }
}
