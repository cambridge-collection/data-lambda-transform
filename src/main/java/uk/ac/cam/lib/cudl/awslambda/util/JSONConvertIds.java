package uk.ac.cam.lib.cudl.awslambda.util;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.JsonNodeType;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.apache.commons.io.FilenameUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.xml.transform.TransformerConfigurationException;
import java.io.File;
import java.io.IOException;
import java.nio.file.Path;
import java.util.Iterator;
import java.util.Map;

public class JSONConvertIds {

    public final String itemsFolder;
    public final String dstSuffix;

    private static final Logger logger = LoggerFactory.getLogger(JSONConvertIds.class);

    public JSONConvertIds() throws IOException, TransformerConfigurationException {
        Properties properties = new Properties();
        dstSuffix = properties.getProperty("DST_XSLT_OUTPUT_SUFFIX");
        itemsFolder = properties.getProperty("DST_XSLT_OUTPUT_FOLDER");
    }
    /**
     * This process converts the @id elements to be relative to the root rather than
     * relative to JSON file.
     * @param json
     * @throws IOException
     */
    public String rewriteIds(String json, String srcKey) throws Exception {

        ObjectMapper mapper = new ObjectMapper();
        JsonNode node = mapper.readTree(json);
        node =  rewriteJSONIdsFromNode(node, srcKey, false);
        return mapper.writerWithDefaultPrettyPrinter().writeValueAsString(node);

    }

    private JsonNode rewriteJSONIdsFromNode(JsonNode node, String srcKey, boolean isItemNode) {

        ObjectMapper mapper = new ObjectMapper();

        // Node is Array
        if (node.isArray()) {
            ArrayNode arrayNode = (ArrayNode) node;
            ArrayNode newArrayNode = mapper.createArrayNode();

            for (int i = 0; i < arrayNode.size(); i++) {
                JsonNode jsonNode = arrayNode.get(i);
                JsonNode updatedNode = rewriteJSONIdsFromNode(jsonNode, srcKey, isItemNode);
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

                    // Item ids are replaced at a different path
                    String newId;
                    if (isItemNode) {
                        newId = translateSrcKeyToItemPath(entry.getValue().asText());
                    } else {
                        newId = convertIdToBeRelativeToRoot(entry.getValue().asText(), srcKey);
                    }

                    // If id is html (starts with pages html) remove this as html is relative to the
                    // html directory in the cudl-viewer.
                    if (newId.startsWith("pages/html/")) {
                        newId = newId.replaceFirst("pages/html/", "");
                    }

                    logger.info("replacing id: "+entry.toString()+" output:"+newId+" isItems: "+isItemNode);
                    objectNode.put("@id", newId);
                } else {
                    boolean isItems = "items".equalsIgnoreCase(entry.getKey());
                    objectNode.set(entry.getKey(), rewriteJSONIdsFromNode(entry.getValue(), srcKey, isItems));
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


    /**
     * NOTE: If <ITEM_ID> appears in the DST_XSLT_OUTPUT_FOLDER parameter this is
     * replaced with the basename from the key.
     *
     * @param srcKey
     * @return
     */
    private String translateSrcKeyToItemPath(String srcKey) {

        logger.info("Item srcKey: "+srcKey);
        String baseName = FilenameUtils.getBaseName(srcKey);

        return replacePlaceholders(itemsFolder, baseName)+baseName+dstSuffix;

    }

    /**
     * Only <ITEM_ID> is currently supported and repl
     */
    private String replacePlaceholders(String input, String itemId) {
        return input.replaceAll("<ITEM_ID>", itemId);
    }
}
