package uk.ac.cam.lib.cudl.awslambda.util;

import org.apache.commons.dbutils.DbUtils;
import org.apache.commons.dbutils.QueryRunner;
import org.apache.commons.dbutils.ResultSetHandler;
import org.apache.commons.dbutils.handlers.BeanHandler;
import org.apache.commons.dbutils.handlers.BeanListHandler;
import org.apache.commons.io.FilenameUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import uk.ac.cam.lib.cudl.awslambda.dao.CollectionDB;
import uk.ac.cam.lib.cudl.awslambda.dao.Item;
import uk.ac.cam.lib.cudl.awslambda.dao.ItemsInCollection;
import uk.ac.cam.lib.cudl.awslambda.input.S3Input;
import uk.ac.cam.lib.cudl.awslambda.model.CollectionJSON;
import uk.ac.cam.lib.cudl.awslambda.model.Id;

import java.io.IOException;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.*;

public class DBHelper {

    private static final Logger logger = LoggerFactory.getLogger(DBHelper.class);
    public final String DEFAULT_COLLECTION_TYPE = "organisation";
    public final int DEFAULT_COLLECTION_ORDER = 100;
    public final String DEFAULT_PARENT_COLLECTION_ID = null;

    public DBHelper() {
    }

    public CollectionDB getCollection(String urlslug) throws SQLException {
        Connection conn = DBCPDataSource.getConnection();
        QueryRunner queryRunner = new QueryRunner();
        ResultSetHandler<CollectionDB> resultHandler = new BeanHandler<>(CollectionDB.class);

        try {
            return queryRunner.query(conn,
                    "SELECT * FROM collections WHERE collectionid=?", resultHandler, urlslug);

        } finally {
            DbUtils.close(conn);
        }
    }

    public List<CollectionDB> getCollections() throws SQLException {
        Connection conn = DBCPDataSource.getConnection();
        QueryRunner queryRunner = new QueryRunner();
        ResultSetHandler<List<CollectionDB>> resultHandler = new BeanListHandler<>(CollectionDB.class);

        try {
            return queryRunner.query(conn,
                    "SELECT * FROM collections", resultHandler);

        } finally {
            DbUtils.close(conn);
        }
    }

    /**
     * Used by both editing collection file and dataset file.  Only editing a dataset file will add a new
     * collection, otherwise does nothing if collection does not exist.  (This is because to exist in DB
     * collection must be in dataset file).
     * @param collectionJSON
     * @param addIfNotExist
     * @throws SQLException
     */
    public void updateCollection(CollectionJSON collectionJSON, boolean addIfNotExist) throws SQLException {

        logger.info("Updating collections");
        CollectionDB collectionDB = getCollection(collectionJSON.getName().getUrlSlug());
        if (collectionDB == null && addIfNotExist) {
            // Add new Collection
            ResultSetHandler<CollectionDB> resultHandler = new BeanHandler<>(CollectionDB.class);
            QueryRunner queryRunner = new QueryRunner();
            Connection conn = DBCPDataSource.getConnection();

            try {
                logger.info("Adding new collection: "+collectionJSON.getName().getUrlSlug());
                queryRunner.insert(conn,
                        "INSERT INTO collections (collectionid,title,summaryurl,sponsorsurl,type,collectionorder,parentcollectionid,metadescription) " +
                                " VALUES  (?,?,?,?,?,?,?,?)",
                        resultHandler,
                        collectionJSON.getName().getUrlSlug(), collectionJSON.getName().getFull(),
                        collectionJSON.getDescription().getFull().getId(), collectionJSON.getCredit().getProse().getId(),
                        DEFAULT_COLLECTION_TYPE, DEFAULT_COLLECTION_ORDER, DEFAULT_PARENT_COLLECTION_ID,
                        collectionJSON.getDescription().getMedium());

            } finally {
                DbUtils.close(conn);
            }

        } else if (collectionDB != null){

            // Update existing collections
            logger.info("Update existing collection: "+collectionJSON.getName().getUrlSlug());
            QueryRunner queryRunner = new QueryRunner();
            Connection conn = DBCPDataSource.getConnection();

            try {
                queryRunner.update(conn,
                        "UPDATE collections SET collectionid=?, title=? ,summaryurl=?, sponsorsurl=?, " +
                                " metadescription=? " +
                                " WHERE collectionid=?", collectionJSON.getName().getUrlSlug(), collectionJSON.getName().getFull(),
                        collectionJSON.getDescription().getFull().getId(), collectionJSON.getCredit().getProse().getId(),
                        collectionJSON.getDescription().getMedium(), collectionJSON.getName().getUrlSlug());

            } finally {
                DbUtils.close(conn);
            }
        }

    }

    public void updateItemsInCollection(CollectionJSON collectionJSON) throws SQLException {

        logger.info("Updating items in collection: "+collectionJSON.getName().getUrlSlug());
        // Go through collection JSON list of items
        List<Id> ids = collectionJSON.getItemIds();
        List<String> jsonItemIds = new ArrayList<>();

        for (Id id: ids) {
            String stringId =  id.toString();
            String itemId = getItemId(stringId);
            jsonItemIds.add(itemId);

            Item item = getItemFromDB(itemId);
            if (item==null) {
                // Add new Item
                logger.info("Add new item: "+itemId);
                Item newItem = new Item();
                newItem.setItemid(itemId);
                newItem.setIiifenabled(true);
                newItem.setTaggingstatus(false);
                addItemToDB(newItem);
            }
        }

        // Get a list of the current items in the collection
        List<ItemsInCollection> itemsInCollectionDBList = getItemsInCollectionFromDB(collectionJSON.getName().getUrlSlug());

        // convert to Map
        Map<String, ItemsInCollection> itemIdsInCollectionDBMap = new HashMap<>();
        for (ItemsInCollection itemsInCollectionDB: itemsInCollectionDBList) {
            itemIdsInCollectionDBMap.put(itemsInCollectionDB.getItemid(), itemsInCollectionDB);
        }

        // Add/update itemsincollection
        // get order of items from array in json
        for (int i=0; i<jsonItemIds.size(); i++) {
            String itemId = jsonItemIds.get(i);
            if (itemIdsInCollectionDBMap.keySet().contains(itemId)) {
                ItemsInCollection itemDB = itemIdsInCollectionDBMap.get(itemId);
                if (itemDB.getItemorder()!=i+1) {
                    logger.info("Updating item in itemsincollection table: "+itemId);
                    // Update if exists already with different order
                    ItemsInCollection newItem = new ItemsInCollection();
                    newItem.setCollectionid(collectionJSON.getName().getUrlSlug());
                    newItem.setItemid(itemId);
                    newItem.setVisible(true);
                    newItem.setItemorder(i+1);
                    updateItemsInCollectionFromDB(newItem);
                }
            } else {
                // Else add new item
                logger.info("Add new item in itemsincollection table: "+itemId);
                ItemsInCollection newItem = new ItemsInCollection();
                newItem.setCollectionid(collectionJSON.getName().getUrlSlug());
                newItem.setItemid(itemId);
                newItem.setVisible(true);
                newItem.setItemorder(i+1);
                addItemsInCollectionToDB(newItem);
            }
        }

        // If exists in DB but not in JSON, remove from itemsincollection
        for (String dbItemId: itemIdsInCollectionDBMap.keySet()) {
            if (!jsonItemIds.contains(dbItemId)) {
                logger.info("Delete item from itemsincollection table: "+dbItemId);
                removeItemsInCollectionFromDB(dbItemId, collectionJSON.getName().getUrlSlug());
            }
        }

    }

    public Item getItemFromDB(String itemId) throws SQLException {
        Connection conn = DBCPDataSource.getConnection();
        QueryRunner queryRunner = new QueryRunner();
        ResultSetHandler<Item> resultHandler = new BeanHandler<>(Item.class);
        try {
            return queryRunner.query(conn,
                    "SELECT * from items where itemid=?", resultHandler, itemId);

        } finally {
            DbUtils.close(conn);
        }
    }

    public void addItemToDB(Item item) throws SQLException {
        Connection conn = DBCPDataSource.getConnection();
        QueryRunner queryRunner = new QueryRunner();
        ResultSetHandler<Item> resultHandler = new BeanHandler<>(Item.class);
        try {
            queryRunner.insert(conn,
                    "INSERT INTO items (itemid, taggingstatus, iiifenabled) " +
                            "VALUES (?,?,?)", resultHandler, item.getItemid(), item.isTaggingstatus(), item.isIiifenabled());

        } finally {
            DbUtils.close(conn);
        }
    }

    public List<ItemsInCollection> getItemsInCollectionFromDB(String collectionId) throws SQLException {
        Connection conn = DBCPDataSource.getConnection();
        QueryRunner queryRunner = new QueryRunner();
        ResultSetHandler<List<ItemsInCollection>> resultHandler = new BeanListHandler<>(ItemsInCollection.class);
        try {
            return queryRunner.query(conn,
                    "SELECT * FROM itemsincollection WHERE collectionid=? ORDER BY itemorder", resultHandler, collectionId);

        } finally {
            DbUtils.close(conn);
        }
    }

    public void updateItemsInCollectionFromDB(ItemsInCollection itemsInCollection) throws SQLException {
        Connection conn = DBCPDataSource.getConnection();
        QueryRunner queryRunner = new QueryRunner();
        ResultSetHandler<ItemsInCollection> resultHandler = new BeanHandler<>(ItemsInCollection.class);
        try {
                queryRunner.update(conn,
                    "UPDATE itemsincollection SET itemid=?, collectionid=?, visible=?, itemorder=? " +
                            "WHERE collectionid=? AND itemid=?",
                        itemsInCollection.getItemid(), itemsInCollection.getCollectionid(), itemsInCollection.isVisible(),
                        itemsInCollection.getItemorder(), itemsInCollection.getCollectionid(), itemsInCollection.getItemid() );

        } finally {
            DbUtils.close(conn);
        }
    }

    public void addItemsInCollectionToDB(ItemsInCollection itemsInCollection) throws SQLException {
        Connection conn = DBCPDataSource.getConnection();
        QueryRunner queryRunner = new QueryRunner();
        ResultSetHandler<ItemsInCollection> resultHandler = new BeanHandler<>(ItemsInCollection.class);
        try {
            queryRunner.insert(conn,
                    "INSERT INTO itemsincollection (itemid,collectionid,visible,itemorder) " +
                            "VALUES (?,?,?,?) ", resultHandler, itemsInCollection.getItemid(),
                    itemsInCollection.getCollectionid(), itemsInCollection.isVisible(),
                    itemsInCollection.getItemorder());

        } finally {
            DbUtils.close(conn);
        }
    }

    public void removeItemsInCollectionFromDB(String itemId, String collectionId) throws SQLException {
        Connection conn = DBCPDataSource.getConnection();
        QueryRunner queryRunner = new QueryRunner();
        try {
            queryRunner.update(conn,
                    "DELETE FROM itemsincollection WHERE itemid=? AND collectionid=? ", itemId, collectionId);

        } finally {
            DbUtils.close(conn);
        }
    }

    private String getItemId(String itemIdPath) {
        return FilenameUtils.getBaseName(itemIdPath);
    }

    public void deleteCollection(String collectionId) throws SQLException {

        Connection conn = DBCPDataSource.getConnection();
        QueryRunner queryRunner = new QueryRunner();
        try {
            // delete any items from items in collection under the collection url
            queryRunner.update(conn,
                    "DELETE FROM itemsincollection WHERE collectionid=? ", collectionId);

            queryRunner.update(conn,
                    "DELETE FROM collections WHERE collectionid=? ", collectionId);
        } finally {
            DbUtils.close(conn);
        }
    }

    public void updateParentCollectionId(CollectionJSON collectionJSON, S3Input input, String srcBucket) throws SQLException, IOException {
        // If the collection has a list of sub collections, go through sub collections and set parent id
        // Error if sub collection not there (as it may not have been created yet)
        logger.info("Update parent collection for: "+collectionJSON.getName().getUrlSlug());

        Connection conn = DBCPDataSource.getConnection();
        JSONHelper jsonHelper = new JSONHelper();

        try {
            for (Id id: collectionJSON.getSubCollectionIds()) {

                logger.info("Found sub-collection with id: "+id.getId()+" in bucket: "+srcBucket);

                String file = input.getString(srcBucket,id.getId());
                CollectionJSON subCollection = jsonHelper.getCollection(file);

                logger.info("Setting database parentcollectionid "+collectionJSON.getName().getUrlSlug()
                        +" for collectionid: "+subCollection.getName().getUrlSlug());

                QueryRunner queryRunner = new QueryRunner();
                queryRunner.update(conn,
                        "UPDATE collections SET parentcollectionid=? WHERE collectionid=? ",
                        collectionJSON.getName().getUrlSlug(), subCollection.getName().getUrlSlug());

            }
        } finally {
           DbUtils.close(conn);
        }
    }

    public void updateCollectionType(String urlSlug, String layout) throws SQLException, IOException {

        Connection conn = DBCPDataSource.getConnection();

        try {

            logger.info("Updating collection "+urlSlug+" to layout "+layout);

            layout = layout.toLowerCase().trim();
            if (!"virtual".equals(layout) && !"organisation".equals(layout) && !"parent".equals(layout)) {
                throw new IOException("layout is not a known type: "+layout);
            }

            QueryRunner queryRunner = new QueryRunner();
            queryRunner.update(conn,
                    "UPDATE collections SET type=? WHERE collectionid=? ",
                    layout, urlSlug);

        } finally {
            DbUtils.close(conn);
        }
    }

    public void updateCollectionOrder(String urlSlug, int order) throws SQLException, IOException {

        Connection conn = DBCPDataSource.getConnection();

        try {

            logger.info("Updating collection "+urlSlug+" to order "+order);

            QueryRunner queryRunner = new QueryRunner();
            queryRunner.update(conn,
                    "UPDATE collections SET collectionorder=? WHERE collectionid=? ",
                    order, urlSlug);

        } finally {
            DbUtils.close(conn);
        }
    }

}
