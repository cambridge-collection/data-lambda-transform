package uk.ac.cam.lib.cudl.awslambda.dao;

public class Item {
    private String itemid;
    private boolean taggingstatus;
    private boolean iiifenabled;

    public String getItemid() {
        return itemid;
    }

    public void setItemid(String itemid) {
        this.itemid = itemid;
    }

    public boolean isTaggingstatus() {
        return taggingstatus;
    }

    public void setTaggingstatus(boolean taggingstatus) {
        this.taggingstatus = taggingstatus;
    }

    public boolean isIiifenabled() {
        return iiifenabled;
    }

    public void setIiifenabled(boolean iiifenabled) {
        this.iiifenabled = iiifenabled;
    }
}
