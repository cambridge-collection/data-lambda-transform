package uk.ac.cam.lib.cudl.awslambda.handlers;

import com.amazonaws.services.lambda.runtime.Context;
import org.apache.commons.io.FilenameUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import uk.ac.cam.lib.cudl.awslambda.input.S3Input;
import uk.ac.cam.lib.cudl.awslambda.model.CollectionJSON;
import uk.ac.cam.lib.cudl.awslambda.util.DBHelper;
import uk.ac.cam.lib.cudl.awslambda.util.JSONHelper;

import java.io.IOException;

public class UpdateDBHandler extends AbstractRequestHandler {

    private static final Logger logger = LoggerFactory.getLogger(UpdateDBHandler.class);
    private final S3Input s3Input;
    private final DBHelper dbHelper;
    private final JSONHelper JSONHelper;

    public UpdateDBHandler() throws IOException {
        s3Input = new S3Input();
        dbHelper = new DBHelper();
        JSONHelper = new JSONHelper();
    }

    @Override
    public String handlePutEvent(String srcBucket, String srcKey, Context context) throws Exception {

        // Read in the collections file
        logger.info("Put Event");
        String file = getSourceString(srcBucket,srcKey, s3Input);
        CollectionJSON collectionJSON = JSONHelper.getCollection(file);

        // Update the DB with collection data
        dbHelper.updateCollection(collectionJSON);

        // update items in collection
        dbHelper.updateItemsInCollection(collectionJSON);

        return "Ok";
    }


    @Override

    public String handleDeleteEvent(String srcBucket, String srcKey, Context context) throws Exception {

        logger.info("Delete Event");
        // Transform to srcKey e.g. 'collections/example.collection.json' to urlSLug 'example'
        String urlSlug = FilenameUtils.getBaseName(srcKey);

        if (urlSlug.endsWith(".collection")) {
            urlSlug = urlSlug.replace(".collection", "");
        }

        dbHelper.deleteCollection(urlSlug);

        return "Ok";
    }
}
