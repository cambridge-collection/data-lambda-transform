package uk.ac.cam.lib.cudl.awslambda.handlers;

import com.amazonaws.services.lambda.runtime.Context;
import org.apache.commons.io.FilenameUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import uk.ac.cam.lib.cudl.awslambda.dao.CollectionDB;
import uk.ac.cam.lib.cudl.awslambda.input.S3Input;
import uk.ac.cam.lib.cudl.awslambda.model.*;
import uk.ac.cam.lib.cudl.awslambda.util.DBHelper;
import uk.ac.cam.lib.cudl.awslambda.util.JSONHelper;

import java.util.ArrayList;

public class UIFileDBHandler extends AbstractRequestHandler {

    private static final Logger logger = LoggerFactory.getLogger(UIFileDBHandler.class);
    private final S3Input s3Input;
    private final DBHelper dbHelper;
    private final JSONHelper JSONHelper;

    public UIFileDBHandler() {
        s3Input = new S3Input();
        dbHelper = new DBHelper();
        JSONHelper = new JSONHelper();
    }

    @Override
    public String handlePutEvent(String srcBucket, String srcKey, Context context) throws Exception {

        // Read in the collections file
        logger.info("Put Event");
        String file = getSourceString(srcBucket,srcKey, s3Input);
        UI uiJSON = JSONHelper.getUI(file);

        // Update the DB collection type
        for (UICollection uiCollection: uiJSON.getThemeData().getCollections()) {

            // Transform Id e.g. 'collections/example.collection.json' to urlSLug 'example'
            String urlSlug = FilenameUtils.getBaseName(uiCollection.getCollection().getId());
            if (urlSlug.endsWith(".collection")) {
                urlSlug = urlSlug.replace(".collection", "");
            }

            // This updates existing collections, adding them if they don't exist
            dbHelper.updateCollectionType(urlSlug, uiCollection.getLayout());

        }
        return "Ok";
    }


    @Override
    public String handleDeleteEvent(String srcBucket, String srcKey, Context context) throws Exception {

        // TODO Not sure we want to do anything in this case.
        throw new Exception("NOT SUPPORTED DELETE ON UI FILE");

    }
}
