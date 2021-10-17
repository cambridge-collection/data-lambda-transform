package uk.ac.cam.lib.cudl.awslambda.dao;

public class ItemsInCollection {

    String itemid;
    String collectionid;
    boolean visible;
    int itemorder;

    public String getItemid() {
        return itemid;
    }

    public void setItemid(String itemid) {
        this.itemid = itemid;
    }

    public String getCollectionid() {
        return collectionid;
    }

    public void setCollectionid(String collectionid) {
        this.collectionid = collectionid;
    }

    public boolean isVisible() {
        return visible;
    }

    public void setVisible(boolean visible) {
        this.visible = visible;
    }

    public int getItemorder() {
        return itemorder;
    }

    public void setItemorder(int itemorder) {
        this.itemorder = itemorder;
    }

}
