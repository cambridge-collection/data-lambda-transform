package uk.ac.cam.lib.cudl.awslambda.util;

import com.fasterxml.jackson.databind.ObjectMapper;
import uk.ac.cam.lib.cudl.awslambda.model.CollectionJSON;

import java.io.IOException;

public class JSONHelper {

    public CollectionJSON getCollection(String collectionJSON) throws IOException {
        ObjectMapper mapper = new ObjectMapper();
        return mapper.readValue(collectionJSON, CollectionJSON.class);
    }

}
