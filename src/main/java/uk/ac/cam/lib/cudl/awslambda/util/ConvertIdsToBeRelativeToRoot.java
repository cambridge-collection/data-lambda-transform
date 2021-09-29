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

public class ConvertIdsToBeRelativeToRoot {

    private static final Logger logger = LoggerFactory.getLogger(ConvertIdsToBeRelativeToRoot.class);

    /**
     * This process converts the @id elements to be relative to the root rather than
     * relative to JSON file.
     * @param node
     * @throws IOException
     */
    public JsonNode rewriteIds(final JsonNode node, String srcKey) throws IOException {

        ObjectMapper mapper = new ObjectMapper();

        logger.info("NodeType: " + node.getNodeType().toString());

        // Node is Array
        if (node.isArray()) {
            logger.info("Node IS ARRAY");
            ArrayNode arrayNode = (ArrayNode) node;
            ArrayNode newArrayNode = mapper.createArrayNode();

            for (int i = 0; i < arrayNode.size(); i++) {
                JsonNode updatedNode = rewriteIds(arrayNode.get(i),srcKey);
                newArrayNode.add(updatedNode);
            }
            return newArrayNode;


        } else

        // Node is Object
        if (node.isObject()) {
            logger.info("Node IS Object");
            ObjectNode objectNode = (ObjectNode) node;
            Iterator<Map.Entry<String, JsonNode>> iter = objectNode.fields();

            while (iter.hasNext()) {

                Map.Entry<String, JsonNode> entry = iter.next();
                if ("@id".equals(entry.getKey()) && entry.getValue().getNodeType()== JsonNodeType.STRING) {
                    logger.info("replacing id: "+entry.toString()+" srcKey: "+srcKey);
                    String newId = convertIdToBeRelativeToRoot(entry.getValue().asText(), srcKey);
                    logger.info("out: "+newId);
                    objectNode.put("@id", newId);
                } else {
                    logger.info("here");
                    objectNode.set(entry.getKey(), rewriteIds(entry.getValue(), srcKey));
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
