package uk.ac.cam.lib.cudl.awslambda.dao;

public class CollectionDB {

    private String collectionid;
    private String title;
    private String summaryurl;
    private String sponsorsurl;
    private String type;
    private int collectionorder;
    private String parentcollectionid;
    private String metadescription;

    public String getCollectionid() {
        return collectionid;
    }

    public void setCollectionid(String collectionid) {
        this.collectionid = collectionid;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public String getSummaryurl() {
        return summaryurl;
    }

    public void setSummaryurl(String summaryurl) {
        this.summaryurl = summaryurl;
    }

    public String getSponsorsurl() {
        return sponsorsurl;
    }

    public void setSponsorsurl(String sponsorsurl) {
        this.sponsorsurl = sponsorsurl;
    }

    public String getType() {
        return type;
    }

    public void setType(String type) {
        this.type = type;
    }

    public int getCollectionorder() {
        return collectionorder;
    }

    public void setCollectionorder(int collectionorder) {
        this.collectionorder = collectionorder;
    }

    public String getParentcollectionid() {
        return parentcollectionid;
    }

    public void setParentcollectionid(String parentcollectionid) {
        this.parentcollectionid = parentcollectionid;
    }

    public String getMetadescription() {
        return metadescription;
    }

    public void setMetadescription(String metadescription) {
        this.metadescription = metadescription;
    }

    @Override
    public String toString() {
        return "collectionid: "+collectionid+ "\n"+
        "title: "+title+ "\n"+
        "summaryurl: "+summaryurl+ "\n"+
        "sponsorsurl: "+sponsorsurl+ "\n"+
        "type: "+type+ "\n"+
        "collectionorder: "+collectionorder+ "\n"+
        "parentcollectionid: "+parentcollectionid+ "\n"+
        "metadescription: "+metadescription;
    }
}
