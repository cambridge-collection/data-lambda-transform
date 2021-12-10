package uk.ac.cam.lib.cudl.awslambda.handlers;

import com.amazonaws.services.lambda.runtime.Context;
import org.apache.commons.io.FilenameUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import uk.ac.cam.lib.cudl.awslambda.dao.CollectionDB;
import uk.ac.cam.lib.cudl.awslambda.input.S3Input;
import uk.ac.cam.lib.cudl.awslambda.model.CollectionJSON;
import uk.ac.cam.lib.cudl.awslambda.model.Dataset;
import uk.ac.cam.lib.cudl.awslambda.model.Id;
import uk.ac.cam.lib.cudl.awslambda.util.DBHelper;
import uk.ac.cam.lib.cudl.awslambda.util.JSONHelper;

import java.util.ArrayList;

public class DatasetFileDBHandler extends AbstractRequestHandler {

    private static final Logger logger = LoggerFactory.getLogger(DatasetFileDBHandler.class);
    private final S3Input s3Input;
    private final DBHelper dbHelper;
    private final JSONHelper JSONHelper;

    public DatasetFileDBHandler() {
        s3Input = new S3Input();
        dbHelper = new DBHelper();
        JSONHelper = new JSONHelper();
    }

    @Override
    public String handlePutEvent(String srcBucket, String srcKey, Context context) throws Exception {

        // Read in the collections file
        logger.info("Put Event");
        String file = getSourceString(srcBucket,srcKey, s3Input);
        Dataset datasetJSON = JSONHelper.getDataset(file);

        // Update the DB with collection data

        int collectionOrder = 1;
        ArrayList<String> collectionUrlSlugs = new ArrayList<>();

        for (Id id: datasetJSON.getCollections()) {

            // Transform Id e.g. 'collections/example.collection.json' to urlSLug 'example'
            String urlSlug = FilenameUtils.getBaseName(id.getId());
            if (urlSlug.endsWith(".collection")) {
                urlSlug = urlSlug.replace(".collection", "");
            }
            collectionUrlSlugs.add(urlSlug);

            // Set correct collection order from order in dataset file
            String collectionFile = getSourceString(srcBucket, id.getId(), s3Input);
            CollectionJSON collectionJSON = JSONHelper.getCollection(collectionFile);

            // Make sure collection exists
            dbHelper.updateCollection(collectionJSON, true);

            // set order
            dbHelper.updateCollectionOrder(urlSlug, collectionOrder);
            collectionOrder++;

        }

        // delete any collections that do not exist in dataset file
        for (CollectionDB collectionDB: dbHelper.getCollections()) {
            if (!collectionUrlSlugs.contains(collectionDB.getCollectionid())) {

                logger.info("Deleting collection: "+collectionDB.getCollectionid()+" as it is not in dataset file");
                dbHelper.deleteCollection(collectionDB.getCollectionid());
            }

        }

        return "Ok";
    }


    @Override
    public String handleDeleteEvent(String srcBucket, String srcKey, Context context) throws Exception {

        // TODO Not sure we want to do anything in this case as it would delete the whole DL (all collections/items).
        throw new Exception("NOT SUPPORTED DELETE ON DATASET FILE");

    }
}
