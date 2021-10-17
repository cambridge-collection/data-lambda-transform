package uk.ac.cam.lib.cudl.awslambda.handlers;

import com.amazonaws.services.lambda.runtime.Context;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import uk.ac.cam.lib.cudl.awslambda.input.S3Input;
import uk.ac.cam.lib.cudl.awslambda.model.CollectionJSON;
import uk.ac.cam.lib.cudl.awslambda.util.DBHelper;
import uk.ac.cam.lib.cudl.awslambda.util.JSONHelper;
import uk.ac.cam.lib.cudl.awslambda.util.RefreshHelper;

import java.io.IOException;

public class UpdateDBHandler extends AbstractRequestHandler {

    private static final Logger logger = LoggerFactory.getLogger(UpdateDBHandler.class);
    private final S3Input s3Input;
    private final DBHelper dbHelper;
    private final JSONHelper JSONHelper;
    private final RefreshHelper refreshHelper;

    public UpdateDBHandler() throws IOException {
        s3Input = new S3Input();
        dbHelper = new DBHelper();
        JSONHelper = new JSONHelper();
        refreshHelper = new RefreshHelper();
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

        // refresh cache
        refreshHelper.refreshCache();

        return "Ok";
    }


    @Override
    public String handleDeleteEvent(String srcBucket, String srcKey, Context context) throws Exception {

        // TODO
        // Connect to DB

        // Update the DB to remove collection
        return null;
    }
}
