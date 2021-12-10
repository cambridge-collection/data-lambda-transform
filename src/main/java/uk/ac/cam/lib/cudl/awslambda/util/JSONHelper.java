package uk.ac.cam.lib.cudl.awslambda.util;

import com.fasterxml.jackson.databind.ObjectMapper;
import uk.ac.cam.lib.cudl.awslambda.model.CollectionJSON;
import uk.ac.cam.lib.cudl.awslambda.model.Dataset;
import uk.ac.cam.lib.cudl.awslambda.model.UI;

import java.io.IOException;

public class JSONHelper {

    private ObjectMapper mapper;

    public JSONHelper () {
       mapper = new ObjectMapper();
    }

    public CollectionJSON getCollection(String collectionJSON) throws IOException {
        return mapper.readValue(collectionJSON, CollectionJSON.class);
    }

    public Dataset getDataset(String datasetJSON) throws IOException {
        return mapper.readValue(datasetJSON, Dataset.class);
    }

    public UI getUI(String uiJSON) throws IOException {
        return mapper.readValue(uiJSON, UI.class);
    }
}
